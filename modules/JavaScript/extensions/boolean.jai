init_vm_boolean :: (vm: *Vm) {
    found, boolean_index := get_global_index(vm, "Boolean");

    if !vm.boolean_prototype {
        vm.boolean_prototype           = allocate_object(vm);
        vm.boolean_prototype.prototype = vm.object_prototype;

        add_instance_method(vm, vm.boolean_prototype, "toString", boolean_to_string);
        add_instance_method(vm, vm.boolean_prototype, "valueOf",  boolean_value_of);
    }

    if found {
        vm.current_realm.globals[boolean_index].type            = .NATIVE_FUNCTION;
        vm.current_realm.globals[boolean_index].native_function = boolean_constructor;

        boolean_object := allocate_object(vm);

        vm.current_realm.globals[boolean_index].object = boolean_object;

        boolean_object.prototype = vm.boolean_prototype;

        prototype_value := Value.{
            type   = .OBJECT,
            object = vm.boolean_prototype,
        };

        add_static_property(vm, boolean_object,       "prototype",   prototype_value);
        add_static_property(vm, vm.boolean_prototype, "constructor", vm.current_realm.globals[boolean_index]);
    }
}

boolean_constructor :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    result_bool := false;

    if arguments.count > 0 result_bool = is_truthy(arguments[0]);

    if is_new {
        object                 := allocate_object(vm);
        object.kind             = .BOOLEAN_WRAPPER;
        object.primitive_value  = .{ type = .BOOLEAN, boolean = result_bool };
        object.prototype        = vm.boolean_prototype;

        return .{ type = .OBJECT, object = object };
    }

    return .{ type = .BOOLEAN, boolean = result_bool };
}

boolean_to_string :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    value := false;

    if this.type == .OBJECT && this.object.kind == .BOOLEAN_WRAPPER value = this.object.primitive_value.boolean;
    else if this.type == .BOOLEAN                                   value = this.boolean;

    return .{ type = .STRING, s = ifx value "true" else "false" };
}

boolean_value_of :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.kind == .BOOLEAN_WRAPPER return this.object.primitive_value;

    return this;
}
