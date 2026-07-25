init_vm_proxy :: (vm: *Vm) {
    found, index := get_global_index(vm, "Proxy");

    if found {
        vm.current_realm.globals[index].type            = .NATIVE_FUNCTION;
        vm.current_realm.globals[index].native_function = proxy_constructor;

        proxy_object := allocate_object(vm);
        vm.current_realm.globals[index].object = proxy_object;
        proxy_object.prototype = vm.function_prototype;
    }
}

proxy_constructor :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if !is_new {
        throw_exception(vm, "TypeError: Constructor Proxy requires 'new'");
        return .{};
    }

    if arguments.count < 2 {
        throw_exception(vm, "TypeError: Cannot create proxy with a non-object as target or handler");
        return .{};
    }

    target := arguments[0];
    handler := arguments[1];

    if target.type != .OBJECT && target.type != .FUNCTION && target.type != .ARRAY {
        throw_exception(vm, "TypeError: Cannot create proxy with a non-object as target");
        return .{};
    }

    if handler.type != .OBJECT && handler.type != .FUNCTION && handler.type != .ARRAY {
        throw_exception(vm, "TypeError: Cannot create proxy with a non-object as handler");
        return .{};
    }

    object := allocate_object(vm);
    object.kind = .PROXY;

    set_object_property(vm, object, "target", target);
    set_object_property(vm, object, "handler", handler);

    return .{ type = .OBJECT, object = object };
}
