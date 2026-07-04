init_vm_router :: (vm: *Vm) {
    found, index := get_global_index(vm, "HttpRouter");

    if found {
        router_prototype := allocate_object(vm);
        router_prototype.prototype = vm.object_prototype;

        add_instance_method(vm, router_prototype, "get",     router_get_js);
        add_instance_method(vm, router_prototype, "post",    router_post_js);
        add_instance_method(vm, router_prototype, "put",     router_put_js);
        add_instance_method(vm, router_prototype, "delete",  router_delete_js);
        add_instance_method(vm, router_prototype, "patch",   router_patch_js);
        add_instance_method(vm, router_prototype, "head",    router_head_js);
        add_instance_method(vm, router_prototype, "options", router_options_js);
        add_instance_method(vm, router_prototype, "connect", router_connect_js);
        add_instance_method(vm, router_prototype, "trace",   router_trace_js);
        add_instance_method(vm, router_prototype, "handle",  router_handle_js);

        router_constructor_value := Value.{
            type            = .NATIVE_FUNCTION,
            native_function = router_constructor_js,
            object          = allocate_object(vm),
        };

        router_constructor_value.object.prototype = null;

        set_object_property(vm, router_constructor_value.object, "prototype",   .{ type = .OBJECT, object = router_prototype });
        set_object_property(vm, router_prototype,                "constructor", router_constructor_value);

        vm.current_realm.globals[index] = router_constructor_value;
    }
}

router_constructor_js :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if !is_new return .{};

    routes_array := allocate_object(vm);
    routes_array.kind      = .ARRAY;
    routes_array.prototype = vm.array_prototype;

    set_object_property(vm, this.object, "_routes", .{ type = .OBJECT, object = routes_array });

    return this;
}

router_add_route :: (vm: *Vm, this: Value, method: string, path: string, handler: Value) {
    found, routes_value := lookup_property(vm, this.object, "_routes");
    if !found || routes_value.type != .OBJECT || routes_value.object.kind != .ARRAY return;

    route_object := allocate_object(vm);

    method_str := copy_string(method);
    path_str := copy_string(path);

    table_set(*vm.allocated_strings, method_str.data, .{ s = method_str, marked = false });
    table_set(*vm.allocated_strings, path_str.data, .{ s = path_str, marked = false });

    set_object_property(vm, route_object, "method",  .{ type = .STRING, s = method_str });
    set_object_property(vm, route_object, "path",    .{ type = .STRING, s = path_str });
    set_object_property(vm, route_object, "handler", handler);

    array_add(*routes_value.object.elements, .{ type = .OBJECT, object = route_object });
}

router_get_js :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count < 2 return .{};

    router_add_route(vm, this, "GET", arguments[0].s, arguments[1]);

    return .{};
}

router_post_js :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count < 2 return .{};

    router_add_route(vm, this, "POST", arguments[0].s, arguments[1]);

    return .{};
}

router_put_js :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count < 2 return .{};

    router_add_route(vm, this, "PUT", arguments[0].s, arguments[1]);

    return .{};
}

router_delete_js :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count < 2 return .{};

    router_add_route(vm, this, "DELETE", arguments[0].s, arguments[1]);

    return .{};
}

router_patch_js :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count < 2 return .{};

    router_add_route(vm, this, "PATCH", arguments[0].s, arguments[1]);

    return .{};
}

router_head_js :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count < 2 return .{};

    router_add_route(vm, this, "HEAD", arguments[0].s, arguments[1]);

    return .{};
}

router_options_js :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count < 2 return .{};

    router_add_route(vm, this, "OPTIONS", arguments[0].s, arguments[1]);

    return .{};
}

router_connect_js :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count < 2 return .{};

    router_add_route(vm, this, "CONNECT", arguments[0].s, arguments[1]);

    return .{};
}

router_trace_js :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count < 2 return .{};

    router_add_route(vm, this, "TRACE", arguments[0].s, arguments[1]);

    return .{};
}

router_handle_js :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count < 1 return .{};

    js_request := arguments[0];

    if js_request.type != .OBJECT return .{};

    found_uri, uri_value     := lookup_property(vm, js_request.object, "uri");
    found_method, method_val := lookup_property(vm, js_request.object, "method");
    if !found_uri || !found_method return .{};

    uri    := uri_value.s;
    method := method_val.s;

    found_routes, routes_value := lookup_property(vm, this.object, "_routes");
    if !found_routes || routes_value.type != .OBJECT || routes_value.object.kind != .ARRAY return .{};

    routes := routes_value.object;

    best_glob_match_count := -1;
    best_handler: Value;

    for routes.elements {
        if it.type != .OBJECT continue;
        route := it.object;

        _, request_method_value := lookup_property(vm, route, "method");
        if request_method_value.s != method continue;

        _, request_path_value := lookup_property(vm, route, "path");
        request_path := request_path_value.s;

        if request_path == "*" && best_glob_match_count < 0 {
            _, handler_value := lookup_property(vm, route, "handler");

            best_handler          = handler_value;
            best_glob_match_count = 0;
        }

        if ends_with(request_path, "*") {
            prefix := slice(request_path, 0, request_path.count - 1);

            if starts_with(uri, prefix) && prefix.count > best_glob_match_count {
                _, handler_value := lookup_property(vm, route, "handler");

                best_handler          = handler_value;
                best_glob_match_count = prefix.count;
            }
        }

        if request_path == uri {
            _, handler_value := lookup_property(vm, route, "handler");

            arguments: [1] Value = .[js_request];

            return call_value(vm, .{}, handler_value, arguments);
        }
    }

    if best_glob_match_count >= 0 {
        arguments: [1] Value = .[js_request];

        return call_value(vm, .{}, best_handler, arguments);
    }

    return .{ type = .NULL };
}