init_vm_fetch :: (vm: *Vm) {
    found, index := get_global_index(vm, "fetch");

    if found {
        vm.current_realm.globals[index].type            = .NATIVE_FUNCTION;
        vm.current_realm.globals[index].native_function = fetch;
    }
}

fetch :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if !(vm.permissions & .NETWORK) {
        throw_exception(vm, "Permission denied: Requires NETWORK permission.");
        return .{};
    }

    if arguments.count < 1 || arguments[0].type != .STRING {
        throw_exception(vm, "fetch requires a string argument for URL");
        return .{};
    }

    url    := arguments[0].s;
    method := "GET";
    body   := "";

    headers: [..] string;
    headers.allocator = temp;

    if arguments.count > 1 && arguments[1].type == .OBJECT {
        options := arguments[1].object;

        found_method, method_value := lookup_property(vm, options, "method");
        if found_method && method_value.type == .STRING method = method_value.s;

        found_body, body_value := lookup_property(vm, options, "body");
        if found_body && body_value.type == .STRING body = body_value.s;

        found_headers, headers_value := lookup_property(vm, options, "headers");
        if found_headers && headers_value.type == .OBJECT {
            headers_object := headers_value.object;
            if headers_object.shape {
                for headers_object.shape.property_names {
                    offset_pointer := table_find_pointer(*headers_object.shape.property_offsets, it);
                    if offset_pointer && offset_pointer.* < headers_object.fields.count {
                        value := headers_object.fields[offset_pointer.*];
                        if value.type == .STRING {
                            array_add(*headers, tprint("%: %", it, value.s));
                        }
                    }
                }
            }
        }
    }

    error, response := request(url, method = method, data = body,, temp);

    promise_object := allocate_object(vm);
    promise_object.kind = .PROMISE;

    add_instance_method(vm, promise_object, "then", promise_then);

    if error {
        promise_object.promise_status = .REJECTED;
        promise_object.promise_result = .{ type = .STRING, s = allocate_string(vm, "Network Error") };
    } else {
        response_object := allocate_object(vm);

        set_object_property(vm, response_object, "status", .{ type = .NUMBER,  number  = cast(float64) response.code });
        set_object_property(vm, response_object, "ok",     .{ type = .BOOLEAN, boolean = (response.code >= 200 && response.code < 300) });
        set_object_property(vm, response_object, "url",    .{ type = .STRING,  s       = allocate_string(vm, url) });

        body_str := ifx response.body else "";
        set_object_property(vm, response_object, "__body", .{ type = .STRING, s = allocate_string(vm, body_str) });

        add_instance_method(vm, response_object, "text", response_text);
        add_instance_method(vm, response_object, "json", response_json);

        promise_object.promise_status = .FULFILLED;
        promise_object.promise_result = .{ type = .OBJECT, object = response_object };
    }

    return .{ type = .OBJECT, object = promise_object };
}

response_text :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .OBJECT return .{};

    found, body_value := lookup_property(vm, this.object, "__body");
    if !found || body_value.type != .STRING return .{};

    promise_object := allocate_object(vm);

    promise_object.kind           = .PROMISE;
    promise_object.promise_status = .FULFILLED;
    promise_object.promise_result = body_value;

    add_instance_method(vm, promise_object, "then", promise_then);

    return .{ type = .OBJECT, object = promise_object };
}

response_json :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .OBJECT return .{};

    found, body_value := lookup_property(vm, this.object, "__body");
    if !found || body_value.type != .STRING return .{};

    json_value := json_parse(vm, .{}, .[body_value], false);

    promise_object := allocate_object(vm);

    promise_object.kind           = .PROMISE;
    promise_object.promise_status = .FULFILLED;
    promise_object.promise_result = json_value;

    add_instance_method(vm, promise_object, "then", promise_then);

    return .{ type = .OBJECT, object = promise_object };
}
