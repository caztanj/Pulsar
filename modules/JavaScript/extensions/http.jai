init_vm_http :: (vm: *Vm) {
    found, http_index := get_global_index(vm, "HttpServer");

    if found {
        http_server_prototype           := allocate_object(vm);
        http_server_prototype.prototype  = vm.object_prototype;

        add_instance_method(vm, http_server_prototype, "poll",         http_server_poll_js);
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
        throw_exception(vm, "Permission denied: net");

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

    this.object.primitive_value.type   = .OBJECT;
    this.object.primitive_value.object = cast(*Gc_Object) wrapper;

    return this;
}

http_server_poll_js :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .OBJECT || this.object.primitive_value.type != .OBJECT return .{};

    wrapper := cast(*Http_Server_Wrapper) this.object.primitive_value.object;

    if !wrapper || !wrapper.initialized return .{};

    peek := false;

    if arguments.count > 0 && arguments[0].type == .BOOLEAN {
        peek = arguments[0].boolean;
    }

    error, events := http_server_poll(*wrapper.server, peek);

    if error {
        throw_exception(vm, "Error polling HTTP server");
        return .{};
    }

    js_events           := allocate_object(vm);
    js_events.kind       = .ARRAY;
    js_events.prototype  = vm.array_prototype;

    for events {
        js_event := allocate_object(vm);

        type: string;
        if it.type == {
            case .Http_Request;       type = "Http_Request";
            case .Web_Socket_Message; type = "Web_Socket_Message";
            case .Client_Closed;      type = "Client_Closed";
        }

        set_object_property(vm, js_event, "type", .{ type = .STRING, s = type });

        if it.type == .Http_Request {
            js_request := request_to_js(vm, it.http_request);
            set_object_property(vm, js_event, "request", js_request);
        } else if it.type == .Client_Closed {
            set_object_property(vm, js_event, "client_id", .{ type = .NUMBER, number = cast(float64) it.client_closed });
        }

        array_add(*js_events.elements, .{ type = .OBJECT, object = js_event });
    }

    return .{ type = .ARRAY, object = js_events };
}

http_server_send_response_js :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .OBJECT || this.object.primitive_value.type != .OBJECT return .{};

    wrapper := cast(*Http_Server_Wrapper) this.object.primitive_value.object;

    if !wrapper || !wrapper.initialized return .{};

    if arguments.count < 2 return .{};

    js_request  := arguments[0];
    js_response := arguments[1];

    success, response := js_to_response(vm, js_request, js_response);
    if !success return .{};

    send_response(*wrapper.server, response);

    return .{ type = .BOOLEAN, boolean = true };
}

http_server_shutdown_js :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .OBJECT || this.object.primitive_value.type != .OBJECT return .{};

    wrapper := cast(*Http_Server_Wrapper) this.object.primitive_value.object;

    if !wrapper || !wrapper.initialized return .{};

    shutdown(*wrapper.server);

    wrapper.initialized = false;

    free(wrapper);

    this.object.primitive_value.object = null;

    return .{ type = .BOOLEAN, boolean = true };
}

request_to_js :: (vm: *Vm, request: Http_Request) -> Value {
    js_request := allocate_object(vm);

    set_object_property(vm, js_request, "uri",    .{ type = .STRING, s = copy_temporary_string(request.uri) });
    set_object_property(vm, js_request, "method", .{ type = .STRING, s = tprint("%", request.method) });
    set_object_property(vm, js_request, "body",   .{ type = .STRING, s = copy_temporary_string(request.body) });

    set_object_property(vm, js_request, "_client_id", .{ type = .NUMBER, number = cast(float64) request.client_id });

    js_headers := allocate_object(vm);

    for header: request.headers set_object_property(vm, js_headers, header.key, .{ type = .STRING, s = copy_temporary_string(header.value) });

    set_object_property(vm, js_request, "headers", .{ type = .OBJECT, object = js_headers });

    return .{ type = .OBJECT, object = js_request };
}

js_to_response :: (vm: *Vm, js_request: Value, js_response: Value) -> (bool, Http_Response) {
    if js_request.type != .OBJECT || js_response.type != .OBJECT return false, .{};

    found, client_id_value := lookup_property(vm, js_request.object, "_client_id");
    if !found || client_id_value.type != .NUMBER return false, .{};

    response := Http_Response.{
        client_id = cast(Socket) client_id_value.number,
    };

    status_found, status_value := lookup_property(vm, js_response.object, "status");
    if status_found && status_value.type == .NUMBER response.status = cast(type_of(response.status)) status_value.number;
    else                                          response.status = .OK;

    body_found, body_value := lookup_property(vm, js_response.object, "body");
    if body_found && body_value.type == .STRING response.body = body_value.s;

    headers_found, headers_value := lookup_property(vm, js_response.object, "headers");
    if headers_found && headers_value.type == .OBJECT {
        headers_object := headers_value.object;
        if headers_object.shape {
            for headers_object.shape.property_names {
                offset_pointer := table_find_pointer(*headers_object.shape.property_offsets, it);
                if offset_pointer && offset_pointer.* < headers_object.fields.count {
                    value := headers_object.fields[offset_pointer.*];
                    if value.type == .STRING {
                        set_header(*response.headers, it, value.s);
                    }
                }
            }
        }
    }

    return true, response;
}

Http_Server_Wrapper :: struct {
    server:      Http_Server;
    initialized: bool;
}