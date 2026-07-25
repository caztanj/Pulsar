init_vm_reflect :: (vm: *Vm) {
    found, index := get_global_index(vm, "Reflect");
    if found {
        reflect_object := allocate_object(vm);

        add_static_method(vm, reflect_object, "construct", reflect_construct);

        vm.current_realm.globals[index] = .{ type = .OBJECT, object = reflect_object };
    }
}

reflect_construct :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count < 2 {
        throw_exception(vm, "TypeError: Reflect.construct requires at least 2 arguments");
        return .{};
    }

    target := arguments[0];
    args_list := arguments[1];

    new_target := target;
    if arguments.count >= 3 {
        new_target = arguments[2];
    }

    is_target_callable := target.type == .FUNCTION || target.type == .NATIVE_FUNCTION || (target.type == .OBJECT && target.object.kind == .PROXY);
    if !is_target_callable {
        throw_exception(vm, "TypeError: Reflect.construct requires target to be a function");
        return .{};
    }

    is_new_target_callable := new_target.type == .FUNCTION || new_target.type == .NATIVE_FUNCTION || (new_target.type == .OBJECT && new_target.object.kind == .PROXY);
    if !is_new_target_callable {
        throw_exception(vm, "TypeError: Reflect.construct requires newTarget to be a function");
        return .{};
    }

    if new_target.type == .FUNCTION && (new_target.function.function.flags & .ARROW) {
        throw_exception(vm, "TypeError: newTarget is not a constructor");
        return .{};
    }

    if target.type == .FUNCTION && (target.function.function.flags & .ARROW) {
        throw_exception(vm, "TypeError: target is not a constructor");
        return .{};
    }

    extracted_args: [..] Value;
    extracted_args.allocator = temp;

    if args_list.type == .OBJECT || args_list.type == .ARRAY {
        if args_list.object {
            for args_list.object.elements {
                if it.type != .EMPTY array_add(*extracted_args, it);
            }
        }
    }

    result := call_value(vm, .{}, target, extracted_args, true);

    if result.type == .OBJECT && new_target.type == .OBJECT {
        found_proto, proto_val := lookup_property(vm, new_target.object, "prototype");
        if found_proto && (proto_val.type == .OBJECT || proto_val.type == .ARRAY) {
            result.object.prototype = proto_val.object;
            write_barrier_object(vm, result.object, proto_val.object);
        }
    }

    return result;
}
