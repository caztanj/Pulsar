init_vm_set :: (vm: *Vm) {
    found, index := get_global_index(vm, "Set");

    if found {
        set_constructor_value := Value.{
            type            = .NATIVE_FUNCTION,
            native_function = set_constructor,
        };

        vm.current_realm.globals[index] = set_constructor_value;

        set_prototype := allocate_object(vm);
        set_prototype.prototype = vm.object_prototype;

        add_instance_method(vm, set_prototype, "add",     set_add);
        add_instance_method(vm, set_prototype, "has",     set_has);
        add_instance_method(vm, set_prototype, "delete",  set_delete);
        add_instance_method(vm, set_prototype, "clear",   set_clear);
        add_instance_method(vm, set_prototype, "size",    set_size);
        add_instance_method(vm, set_prototype, "forEach", set_for_each);

        set_constructor_object := allocate_object(vm);

        vm.current_realm.globals[index].object = set_constructor_object;

        prototype_value := Value.{
            type   = .OBJECT,
            object = set_prototype,
        };

        add_static_property(vm, set_constructor_object, "prototype", prototype_value);
    }
}

set_constructor :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if !is_new return .{ type = .UNDEFINED };

    object := this.object;
    object.kind = .SET;

    return this;
}

set_add :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.kind == .SET {
        if arguments.count < 1 return this;

        value  := arguments[0];
        object := this.object;

        for object.map_entries {
            if values_strict_equal(it, value) {
                return this;
            }
        }

        array_add(*object.map_entries, value);
    }

    return this;
}

set_has :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.kind == .SET {
        if arguments.count < 1 return .{ type = .BOOLEAN, boolean = false };

        value  := arguments[0];
        object := this.object;

        for object.map_entries {
            if values_strict_equal(it, value) {
                return .{ type = .BOOLEAN, boolean = true };
            }
        }
    }

    return .{ type = .BOOLEAN, boolean = false };
}

set_delete :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.kind == .SET {
        if arguments.count < 1 return .{ type = .BOOLEAN, boolean = false };

        value  := arguments[0];
        object := this.object;

        for object.map_entries {
            if values_strict_equal(it, value) {
                array_ordered_remove_by_index(*object.map_entries, it_index);
                return .{ type = .BOOLEAN, boolean = true };
            }
        }
    }

    return .{ type = .BOOLEAN, boolean = false };
}

set_clear :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.kind == .SET array_reset(*this.object.map_entries);
    return .{ type = .UNDEFINED };
}

set_size :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.kind == .SET return .{ type = .NUMBER, number = cast(float64) this.object.map_entries.count };
    return .{ type = .NUMBER, number = 0.0 };
}

set_for_each :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.kind == .SET {
        if arguments.count == 0 return .{ type = .UNDEFINED };

        callback := arguments[0];

        if callback.type != .FUNCTION && callback.type != .NATIVE_FUNCTION return .{ type = .UNDEFINED };

        this_argument := ifx arguments.count > 1 then arguments[1] else Value.{};

        object := this.object;

        for object.map_entries {
            arguments: [3] Value = .[
                it,
                it,
                this,
            ];

            call_value(vm, this_argument, callback, arguments);

            if vm.has_exception return .{};
        }
    }

    return .{ type = .UNDEFINED };
}
