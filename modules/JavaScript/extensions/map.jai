init_vm_map :: (vm: *Vm) {
    found, index := get_global_index(vm, "Map");

    if found {
        map_constructor_value := Value.{
            type            = .NATIVE_FUNCTION,
            native_function = map_constructor,
        };

        vm.current_realm.globals[index] = map_constructor_value;

        map_prototype := allocate_object(vm);
        map_prototype.prototype = vm.object_prototype;

        add_instance_method(vm, map_prototype, "set",     map_set);
        add_instance_method(vm, map_prototype, "get",     map_get);
        add_instance_method(vm, map_prototype, "has",     map_has);
        add_instance_method(vm, map_prototype, "delete",  map_delete);
        add_instance_method(vm, map_prototype, "clear",   map_clear);
        add_instance_method(vm, map_prototype, "size",    map_size);
        add_instance_method(vm, map_prototype, "forEach", map_for_each);

        map_constructor_object := allocate_object(vm);

        vm.current_realm.globals[index].object = map_constructor_object;

        prototype_value := Value.{
            type   = .OBJECT,
            object = map_prototype,
        };

        add_static_property(vm, map_constructor_object, "prototype", prototype_value);
    }
}

map_constructor :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if !is_new return .{ type = .UNDEFINED };

    object := this.object;
    object.kind = .MAP;

    return this;
}

map_set :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.kind == .MAP {
        if arguments.count < 1 return this;

        key   := arguments[0];
        value := ifx arguments.count > 1 then arguments[1] else Value.{};

        object := this.object;

        for 0..object.map_entries.count / 2 - 1 {
            if values_strict_equal(object.map_entries[it * 2], key) {
                object.map_entries[it * 2 + 1] = value;
                return this;
            }
        }

        array_add(*object.map_entries, key);
        array_add(*object.map_entries, value);
    }

    return this;
}

map_get :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.kind == .MAP {
        if arguments.count < 1 return .{ type = .UNDEFINED };

        key := arguments[0];

        object := this.object;

        for 0..object.map_entries.count / 2 - 1 {
            if values_strict_equal(object.map_entries[it * 2], key) {
                return object.map_entries[it * 2 + 1];
            }
        }
    }

    return .{ type = .UNDEFINED };
}

map_has :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.kind == .MAP {
        if arguments.count < 1 return .{ type = .BOOLEAN, boolean = false };

        key := arguments[0];

        object := this.object;

        for 0..object.map_entries.count / 2 - 1 {
            if values_strict_equal(object.map_entries[it * 2], key) {
                return .{ type = .BOOLEAN, boolean = true };
            }
        }
    }

    return .{ type = .BOOLEAN, boolean = false };
}

map_delete :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.kind == .MAP {
        if arguments.count < 1 return .{ type = .BOOLEAN, boolean = false };

        key := arguments[0];

        object := this.object;

        for 0..object.map_entries.count / 2 - 1 {
            if values_strict_equal(object.map_entries[it * 2], key) {
                array_ordered_remove_by_index(*object.map_entries, it * 2 + 1);
                array_ordered_remove_by_index(*object.map_entries, it * 2);

                return .{ type = .BOOLEAN, boolean = true };
            }
        }
    }

    return .{ type = .BOOLEAN, boolean = false };
}

map_clear :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.kind == .MAP {
        array_reset(*this.object.map_entries);
    }

    return .{ type = .UNDEFINED };
}

map_size :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.kind == .MAP {
        return .{ type = .NUMBER, number = cast(float64) (this.object.map_entries.count / 2) };
    }

    return .{ type = .NUMBER, number = 0.0 };
}

map_for_each :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.kind == .MAP {
        if arguments.count == 0 return .{ type = .UNDEFINED };

        callback := arguments[0];

        if callback.type != .FUNCTION && callback.type != .NATIVE_FUNCTION return .{ type = .UNDEFINED };

        this_argument := ifx arguments.count > 1 then arguments[1] else Value.{};

        object := this.object;

        i := 0;
        while i < object.map_entries.count / 2 {
            arguments: [3] Value = .[
                object.map_entries[i * 2 + 1],
                object.map_entries[i * 2],
                this,
            ];

            call_value(vm, this_argument, callback, arguments);

            if vm.has_exception return .{};

            i += 1;
        }
    }

    return .{ type = .UNDEFINED };
}
