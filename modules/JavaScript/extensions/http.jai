init_vm_http :: (vm: *Vm) {
    found, http_index := get_global_index(vm, "HttpServer");

    if found {
        http_server_prototype           := allocate_object(vm);
        http_server_prototype.prototype  = vm.object_prototype;

        add_instance_method(vm, http_server_prototype, "on",           http_server_on_js);
        add_instance_method(vm, http_server_prototype, "sendResponse", http_server_send_response_js);
        add_instance_method(vm, http_server_prototype, "shutdown",     http_server_shutdown_js);

        http_server_constructor_value := Value.{
            type             = .NATIVE_FUNCTION,
            native_function  = http_server_constructor_js,
            object           = allocate_object(vm),
        };

        http_server_constructor_value.object.prototype = null;

        set_object_property(vm, http_server_constructor_value.object, "prototype",   .{ type = .OBJECT, object = http_server_prototype });
        set_object_property(vm, http_server_prototype,                "constructor", http_server_constructor_value);

        vm.current_realm.globals[http_index] = http_server_constructor_value;
    }
}

http_server_constructor_js :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if !(vm.permissions & .NETWORK) {
        throw_exception(vm, "Permission denied: network");
        return .{};
    }

    if !is_new return .{};

    port: u16 = 8080;

    if arguments.count > 0 && arguments[0].type == .NUMBER {
        port = cast(u16) arguments[0].number;
    }

    wrapper := New(Http_Server_Wrapper);
    error   := init(*wrapper.server, port);

    if error {
        throw_exception(vm, "Could not initialize HTTP server");
        return .{};
    }

    wrapper.initialized = true;
    wrapper.vm          = vm;

    init(*wrapper.response_mutex);

    vm.active_background_tasks += 1;

    thread_init(*wrapper.thread, http_server_thread_proc);
    wrapper.thread.data = wrapper;
    thread_start(*wrapper.thread);

    this.object.primitive_value.type   = .OBJECT;
    this.object.primitive_value.object = cast(*Gc_Object) wrapper;

    return this;
}

http_server_on_js :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .OBJECT || this.object.primitive_value.type != .OBJECT return .{};

    wrapper := cast(*Http_Server_Wrapper) this.object.primitive_value.object;

    if !wrapper || !wrapper.initialized return .{};

    if arguments.count < 2 return .{};

    event_name := arguments[0];
    callback   := arguments[1];

    if event_name.type == .STRING && event_name.s == "request" {
        wrapper.request_callback = callback;
    }

    return this;
}

http_server_send_response_js :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .OBJECT || this.object.primitive_value.type != .OBJECT return .{};
    wrapper := cast(*Http_Server_Wrapper) this.object.primitive_value.object;
    if !wrapper || !wrapper.initialized return .{};

    if arguments.count < 2 return .{};

    js_request  := arguments[0];
    js_response := arguments[1];

    success, safe_resp := js_to_response(vm, js_request, js_response);
    if !success return .{};

    lock(*wrapper.response_mutex);
    array_add(*wrapper.response_queue, safe_resp);
    unlock(*wrapper.response_mutex);

    wakeup_event_loop(*wrapper.server);

    return .{ type = .BOOLEAN, boolean = true };
}

http_server_shutdown_js :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .OBJECT || this.object.primitive_value.type != .OBJECT return .{};
    wrapper := cast(*Http_Server_Wrapper) this.object.primitive_value.object;
    if !wrapper || !wrapper.initialized return .{};

    wrapper.shutdown_requested = true;
    wakeup_event_loop(*wrapper.server);

    shutdown(*wrapper.server);

    destroy(*wrapper.response_mutex);

    wrapper.initialized = false;
    wrapper.vm.active_background_tasks -= 1;

    this.object.primitive_value.object = null;

    return .{ type = .BOOLEAN, boolean = true };
}

http_server_thread_proc :: (thread: *Thread) -> s64 {
    wrapper := cast(*Http_Server_Wrapper) thread.data;
    vm      := wrapper.vm;

    while !wrapper.shutdown_requested {
        has_responses := false;
        lock(*wrapper.response_mutex);
        has_responses = wrapper.response_queue.count > 0;
        unlock(*wrapper.response_mutex);

        error, events := http_server_poll(*wrapper.server, false);
        if error break;
        if wrapper.shutdown_requested break;

        if events.count > 0 {
            for event: events {
                safe_event := New(Safe_Http_Event);

                safe_event.server_wrapper = cast(*void) wrapper;
                safe_event.client_id      = event.client_closed;

                if event.type == {
                    case .Http_Request;
                        safe_event.type           = "request";
                        safe_event.client_id      = event.http_request.client_id;
                        safe_event.request_method = copy_string(tprint("%", event.http_request.method));
                        safe_event.request_uri    = copy_string(event.http_request.uri);
                        safe_event.request_body   = copy_string(event.http_request.body);

                        for header: event.http_request.headers {
                            safe_header: Safe_Http_Header;
                            safe_header.key = copy_string(header.key);
                            safe_header.value = copy_string(header.value);

                            array_add(*safe_event.request_headers, safe_header);
                        }

                    case .Web_Socket_Message;
                        safe_event.type = "websocket";

                    case .Client_Closed;
                        safe_event.type = "closed";
                }

                external_event: External_Event;
                external_event.data = safe_event;
                external_event.handler = run_http_event_handler;

                lock(*vm.external_events_mutex);
                array_add(*vm.external_events, external_event);
                unlock(*vm.external_events_mutex);

                signal(*vm.event_loop_semaphore);
            }
        }

        lock(*wrapper.response_mutex);

        queued_responses: [..] Safe_Response;
        queued_responses.allocator = temp;

        for wrapper.response_queue array_add(*queued_responses, it);

        wrapper.response_queue.count = 0;

        unlock(*wrapper.response_mutex);

        for queued_responses {
            response: Http_Response;

            response.client_id = it.client_id;
            response.status    = cast(type_of(response.status)) it.status;
            response.body      = it.body;

            for it.headers set_header(*response.headers, it.key, it.value);

            send_response(*wrapper.server, response);

            free(it.body);

            for it.headers {
                free(it.key);
                free(it.value);
            }

            array_free(it.headers);
        }

        reset_temporary_storage();
    }

    return 0;
}

run_http_event_handler :: (vm: *Vm, data: *void) {
    safe_event := cast(*Safe_Http_Event) data;
    wrapper    := cast(*Http_Server_Wrapper) safe_event.server_wrapper;

    if safe_event.type == "request" && wrapper && wrapper.request_callback.type != .UNDEFINED {
        js_request := allocate_object(vm);

        set_object_property(vm, js_request, "uri",    .{ type = .STRING, s = copy_temporary_string(safe_event.request_uri) });
        set_object_property(vm, js_request, "method", .{ type = .STRING, s = copy_temporary_string(safe_event.request_method) });
        set_object_property(vm, js_request, "body",   .{ type = .STRING, s = copy_temporary_string(safe_event.request_body) });
        set_object_property(vm, js_request, "_client_id", .{ type = .NUMBER, number = cast(float64) safe_event.client_id });

        js_headers := allocate_object(vm);

        for header: safe_event.request_headers {
            set_object_property(vm, js_headers, header.key, .{ type = .STRING, s = copy_temporary_string(header.value) });
            free(header.value);
        }

        set_object_property(vm, js_request, "headers", .{ type = .OBJECT, object = js_headers });

        js_response := allocate_object(vm);

        set_object_property(vm, js_response, "status", .{ type = .NUMBER, number = 200 });
        set_object_property(vm, js_response, "body", .{ type = .STRING, s = copy_temporary_string("") });

        js_result_headers := allocate_object(vm);

        set_object_property(vm, js_response, "headers", .{ type = .OBJECT, object = js_result_headers });

        arguments: [2] Value = .[ .{ type = .OBJECT, object = js_request }, .{ type = .OBJECT, object = js_response } ];
        call_value(vm, .{}, wrapper.request_callback, arguments);
    }

    if safe_event.type == "request" {
        free(safe_event.request_uri);
        free(safe_event.request_method);
        free(safe_event.request_body);

        array_free(safe_event.request_headers);
    }

    free(safe_event);
}

js_to_response :: (vm: *Vm, js_request: Value, js_response: Value) -> (bool, Safe_Response) {
    if js_request.type != .OBJECT || js_response.type != .OBJECT return false, .{};

    found, client_id_value := lookup_property(vm, js_request.object, "_client_id");
    if !found || client_id_value.type != .NUMBER return false, .{};

    response: Safe_Response;
    response.client_id = cast(Socket) client_id_value.number;

    status_found, status_value := lookup_property(vm, js_response.object, "status");
    if status_found && status_value.type == .NUMBER response.status = cast(u16) status_value.number;
    else                                          response.status = 200;

    body_found, body_value := lookup_property(vm, js_response.object, "body");
    if body_found && body_value.type == .STRING response.body = copy_string(body_value.s);

    headers_found, headers_value := lookup_property(vm, js_response.object, "headers");
    if headers_found && headers_value.type == .OBJECT {
        headers_object := headers_value.object;
        if headers_object.shape {
            for headers_object.shape.property_names {
                offset_pointer := table_find_pointer(*headers_object.shape.property_offsets, it);
                if offset_pointer && offset_pointer.* < headers_object.fields.count {
                    value := headers_object.fields[offset_pointer.*];
                    if value.type == .STRING {
                        header: Safe_Http_Header;
                        header.key = copy_string(it);
                        header.value = copy_string(value.s);
                        array_add(*response.headers, header);
                    }
                }
            }
        }
    }

    has_content_length := false;
    for response.headers {
        if it.key == "Content-Length" || it.key == "content-length" {
            has_content_length = true;
            break;
        }
    }

    if !has_content_length {
        header: Safe_Http_Header;
        header.key = copy_string("Content-Length");
        header.value = copy_string(tprint("%", response.body.count));
        array_add(*response.headers, header);
    }

    return true, response;
}

Http_Server_Wrapper :: struct {
    server:      Http_Server;
    initialized: bool;

    thread:             Thread;
    shutdown_requested: bool;
    vm:                 *Vm;

    request_callback: Value;

    response_mutex: Mutex;
    response_queue: [..] Safe_Response;
}

Safe_Response :: struct {
    client_id: Socket;
    status: u16;
    body: string;
    headers: [..] Safe_Http_Header;
}

Safe_Http_Header :: struct {
    key:   string;
    value: string;
}

Safe_Http_Event :: struct {
    type:            string;
    server_wrapper:  *void;
    client_id:       Socket;
    request_method:  string;
    request_uri:     string;
    request_body:    string;
    request_headers: [..] Safe_Http_Header;
}