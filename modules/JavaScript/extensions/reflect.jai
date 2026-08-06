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

    if !is_constructor(vm, target) {
        throw_exception(vm, "TypeError: Reflect.construct target is not a constructor");
        return .{};
    }

    if !is_constructor(vm, new_target) {
        throw_exception(vm, "TypeError: Reflect.construct newTarget is not a constructor");
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

    result := call_value(vm, new_target, target, extracted_args, true);

    return result;
}
