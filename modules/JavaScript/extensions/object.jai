init_vm_object :: (vm: *Vm) {
    found, index := get_global_index(vm, "Object");

    if !vm.object_prototype {
        vm.object_prototype = allocate_object(vm);
        vm.object_prototype.prototype = null;

        add_instance_method(vm, vm.object_prototype, "toString",       object_to_string);
        add_instance_method(vm, vm.object_prototype, "hasOwnProperty", object_has_own_property);
        add_instance_method(vm, vm.object_prototype, "propertyIsEnumerable", object_property_is_enumerable);
    }

    if found {
        object_obj := allocate_object(vm);
        object_obj.prototype = null;
        vm.current_realm.globals[index].type = .OBJECT;
        vm.current_realm.globals[index].object = object_obj;

        add_static_method(vm, object_obj, "setPrototypeOf",           object_set_prototype);
        add_static_method(vm, object_obj, "getPrototypeOf",           object_get_prototype_of);
        add_static_method(vm, object_obj, "defineProperty",           object_define_property);
        add_static_method(vm, object_obj, "getOwnPropertyDescriptor", object_get_own_property_descriptor);
        add_static_method(vm, object_obj, "create",                   object_create);
        add_static_method(vm, object_obj, "freeze",                   object_freeze);
        add_static_method(vm, object_obj, "seal",                     object_seal);
        add_static_method(vm, object_obj, "keys",                     object_keys);
        add_static_method(vm, object_obj, "values",                   object_values);
        add_static_method(vm, object_obj, "entries",                  object_entries);
        add_static_method(vm, object_obj, "assign",                   object_assign);
        add_static_method(vm, object_obj, "getOwnPropertyNames",      object_get_own_property_names);

        prototype_value := Value.{
            type   = .OBJECT,
            object = vm.object_prototype,
        };

        add_static_property(vm, object_obj, "prototype", prototype_value);
    }
}


object_set_prototype :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count >= 2 {
        target    := arguments[0];
        prototype := arguments[1];

        if (target.type == .OBJECT || target.type == .ARRAY) && target.object {
            if (prototype.type == .OBJECT || prototype.type == .ARRAY) && prototype.object {
                target.object.prototype = prototype.object;
            } else if prototype.type == .NULL {
                target.object.prototype = null;
            }
        }

        return target;
    }

    return .{ type = .UNDEFINED };
}

object_keys :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .ARRAY, object = allocate_object(vm) };

    argument := arguments[0];

    if argument.type != .OBJECT && argument.type != .ARRAY return .{ type = .ARRAY, object = allocate_object(vm) };

    object := argument.object;

    result := allocate_object(vm);
    result.kind      = .ARRAY;
    result.prototype = vm.array_prototype;

    for object.elements {
        if it.type == .UNDEFINED continue;
        value := Value.{
            type = .STRING,
            s    = tprint("%", it_index),
        };

        array_add(*result.elements, value);
    }

    if object.shape {
        for object.shape.property_names {
            offset_pointer := table_find_pointer(*object.shape.property_offsets, it);

            if !offset_pointer || offset_pointer.* >= object.fields.count continue;
            if object.fields[offset_pointer.*].type == .UNDEFINED         continue;

            value := Value.{
                type = .STRING,
                s    = it,
            };

            array_add(*result.elements, value);
        }
    }

    return .{ type = .ARRAY, object = result };
}

object_values :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .ARRAY, object = allocate_object(vm) };

    argument := arguments[0];

    if argument.type != .OBJECT && argument.type != .ARRAY return .{ type = .ARRAY, object = allocate_object(vm) };

    object := argument.object;

    result := allocate_object(vm);
    result.kind      = .ARRAY;
    result.prototype = vm.array_prototype;

    for object.elements {
        if it.type == .EMPTY continue;
        array_add(*result.elements, it);
    }

    if object.shape {
        for object.shape.property_names {
            offset_pointer := table_find_pointer(*object.shape.property_offsets, it);

            if !offset_pointer || offset_pointer.* >= object.fields.count continue;
            if object.fields[offset_pointer.*].type == .EMPTY         continue;

            array_add(*result.elements, object.fields[offset_pointer.*]);
        }
    }

    return .{ type = .ARRAY, object = result };
}

object_entries :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .ARRAY, object = allocate_object(vm) };

    argument := arguments[0];

    if argument.type != .OBJECT && argument.type != .ARRAY return .{ type = .ARRAY, object = allocate_object(vm) };

    object := argument.object;

    result := allocate_object(vm);
    result.kind      = .ARRAY;
    result.prototype = vm.array_prototype;

    for object.elements {
        if it.type == .UNDEFINED continue;

        entry := allocate_object(vm);
        entry.kind      = .ARRAY;
        entry.prototype = vm.array_prototype;

        key_value := Value.{
            type = .STRING,
            s    = tprint("%", it_index),
        };

        array_add(*entry.elements, key_value);
        array_add(*entry.elements, it);

        array_add(*result.elements, .{ type = .ARRAY, object = entry });
    }

    if object.shape {
        for object.shape.property_names {
            offset_pointer := table_find_pointer(*object.shape.property_offsets, it);

            if !offset_pointer || offset_pointer.* >= object.fields.count continue;
            if object.fields[offset_pointer.*].type == .EMPTY         continue;

            entry := allocate_object(vm);
            entry.kind      = .ARRAY;
            entry.prototype = vm.array_prototype;

            key_value := Value.{
                type = .STRING,
                s    = it,
            };

            array_add(*entry.elements, key_value);
            array_add(*entry.elements, object.fields[offset_pointer.*]);

            array_add(*result.elements, .{ type = .ARRAY, object = entry });
        }
    }

    return .{ type = .ARRAY, object = result };
}

object_assign :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .UNDEFINED };

    target_value := arguments[0];

    if target_value.type != .OBJECT && target_value.type != .ARRAY return target_value;

    target_object := target_value.object;

    for 1..arguments.count - 1 {
        source_value := arguments[it];

        if source_value.type != .OBJECT && source_value.type != .ARRAY continue;

        source_object := source_value.object;

        if source_object.shape {
            for source_object.shape.property_names {
                offset_pointer := table_find_pointer(*source_object.shape.property_offsets, it);

                if offset_pointer && offset_pointer.* < source_object.fields.count {
                    if source_object.fields[offset_pointer.*].type != .UNDEFINED {
                        set_object_property(vm, target_object, it, source_object.fields[offset_pointer.*]);
                    }
                }
            }
        }

        for source_object.elements {
            if it.type != .UNDEFINED {
                key_string := tprint("%", it_index);
                set_object_property(vm, target_object, key_string, it);
            }
        }
    }

    return target_value;
}

object_get_prototype_of :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .UNDEFINED };

    target_value := arguments[0];

    if (target_value.type != .OBJECT && target_value.type != .ARRAY) || !target_value.object return .{ type = .UNDEFINED };

    prototype := target_value.object.prototype;

    if !prototype return .{ type = .NULL };

    return .{ type = .OBJECT, object = prototype };
}

object_define_property :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count < 3 return .{ type = .UNDEFINED };

    target_value := arguments[0];

    if (target_value.type != .OBJECT && target_value.type != .ARRAY) || !target_value.object return target_value;

    name             := value_to_string(vm, arguments[1]);
    descriptor_value := arguments[2];

    if (descriptor_value.type == .OBJECT || descriptor_value.type == .ARRAY) && descriptor_value.object {
        found, value := lookup_property(vm, descriptor_value.object, "value");

        if found set_object_property(vm, target_value.object, name, value);

        found_get, get_value := lookup_property(vm, descriptor_value.object, "get");
        if found_get set_object_property(vm, target_value.object, tprint("%__getter__", name), get_value);
    }

    return target_value;
}

object_get_own_property_descriptor :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count < 2 return .{ type = .UNDEFINED };

    target_value := arguments[0];

    if (target_value.type != .OBJECT && target_value.type != .ARRAY) || !target_value.object return .{ type = .UNDEFINED };

    name   := value_to_string(vm, arguments[1]);
    object := target_value.object;

    has_property := false;
    property_value: Value;

    if object.shape {
        offset_pointer := table_find_pointer(*object.shape.property_offsets, name);

        if offset_pointer && offset_pointer.* < object.fields.count && object.fields[offset_pointer.*].type != .EMPTY {
            has_property   = true;
            property_value = object.fields[offset_pointer.*];
        }
    }

    if !has_property {
        parsed_index, success := string_to_int(name);

        if success && parsed_index >= 0 && parsed_index < object.elements.count && object.elements[parsed_index].type != .EMPTY {
            has_property   = true;
            property_value = object.elements[parsed_index];
        }
    }

    if has_property {
        descriptor := allocate_object(vm);

        enumerable := true;
        if name == "cause" || name == "message" || name == "name" || name == "length" || name == "prototype" {
            enumerable = false;
        }

        set_object_property(vm, descriptor, "value",        property_value);
        set_object_property(vm, descriptor, "writable",     .{ type = .BOOLEAN, boolean = true });
        set_object_property(vm, descriptor, "enumerable",   .{ type = .BOOLEAN, boolean = enumerable });
        set_object_property(vm, descriptor, "configurable", .{ type = .BOOLEAN, boolean = true });

        return .{ type = .OBJECT, object = descriptor };
    }

    return .{ type = .UNDEFINED };
}

object_create :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .UNDEFINED };

    prototype_value := arguments[0];

    object := allocate_object(vm);

    if prototype_value.type == .OBJECT || prototype_value.type == .ARRAY {
        object.prototype = prototype_value.object;
    } else if prototype_value.type == .NULL {
        object.prototype = null;
    } else {
        return .{ type = .UNDEFINED };
    }

    return .{ type = .OBJECT, object = object };
}

object_freeze :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count > 0 return arguments[0];
    return .{ type = .UNDEFINED };
}

object_seal :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count > 0 return arguments[0];
    return .{ type = .UNDEFINED };
}

object_has_own_property :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if (this.type != .OBJECT && this.type != .ARRAY) || !this.object return .{ type = .BOOLEAN, boolean = false };
    if arguments.count == 0 return .{ type = .BOOLEAN, boolean = false };

    name   := value_to_string(vm, arguments[0]);
    object := this.object;

    if object.shape {
        offset_pointer := table_find_pointer(*object.shape.property_offsets, name);

        if offset_pointer && offset_pointer.* < object.fields.count && object.fields[offset_pointer.*].type != .EMPTY {
            return .{ type = .BOOLEAN, boolean = true };
        }
    }

    parsed_index, success := string_to_int(name);
    if success && parsed_index >= 0 && parsed_index < object.elements.count && object.elements[parsed_index].type != .EMPTY {
        return .{ type = .BOOLEAN, boolean = true };
    }

    return .{ type = .BOOLEAN, boolean = false };
}

object_to_string :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    return .{ type = .STRING, s = "[object Object]" };
}

object_property_is_enumerable :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .OBJECT && this.type != .ARRAY && this.type != .FUNCTION && this.type != .NATIVE_FUNCTION {
        return .{ type = .BOOLEAN, boolean = false };
    }

    if arguments.count == 0 return .{ type = .BOOLEAN, boolean = false };
    name := value_to_string(vm, arguments[0]);
    if vm.has_exception return .{};

    obj := this.object;
    if !obj return .{ type = .BOOLEAN, boolean = false };

    found := false;
    for obj.shape.property_names {
        if it == name {
            found = true;
            break;
        }
    }

    if !found return .{ type = .BOOLEAN, boolean = false };

    enumerable := true;
    if name == "cause" || name == "message" || name == "name" || name == "length" || name == "prototype" {
        enumerable = false;
    }

    return .{ type = .BOOLEAN, boolean = enumerable };
}

object_get_own_property_names :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    arr_obj := allocate_object(vm);
    arr_obj.kind = .ARRAY;
    arr_obj.prototype = vm.array_prototype;

    if arguments.count == 0 return .{ type = .OBJECT, object = arr_obj };

    arg := arguments[0];
    if arg.type != .OBJECT && arg.type != .ARRAY && arg.type != .FUNCTION && arg.type != .NATIVE_FUNCTION {
        return .{ type = .OBJECT, object = arr_obj };
    }

    obj := arg.object;
    if !obj return .{ type = .OBJECT, object = arr_obj };

    for obj.shape.property_names {
        offset_pointer := table_find_pointer(*obj.shape.property_offsets, it);
        if offset_pointer && offset_pointer.* < obj.fields.count && obj.fields[offset_pointer.*].type != .EMPTY {
            array_add(*arr_obj.elements, Value.{ type = .STRING, s = copy_string(it) });
        }
    }

    set_object_property(vm, arr_obj, "length", .{ type = .NUMBER, number = cast(float64) arr_obj.elements.count });
    return .{ type = .OBJECT, object = arr_obj };
}