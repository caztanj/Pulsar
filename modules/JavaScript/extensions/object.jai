init_vm_object :: (vm: *Vm) {
    found, index := get_global_index(vm, "Object");

    if !vm.object_prototype {
        vm.object_prototype = allocate_object(vm);
        vm.object_prototype.prototype = null;

        add_instance_method(vm, vm.object_prototype, "toString",             object_to_string);
        add_instance_method(vm, vm.object_prototype, "hasOwnProperty",       object_has_own_property);
        add_instance_method(vm, vm.object_prototype, "propertyIsEnumerable", object_property_is_enumerable);
        add_instance_method(vm, vm.object_prototype, "isPrototypeOf",        object_is_prototype_of);
    }

    if found {
        vm.current_realm.globals[index].type = .NATIVE_FUNCTION;
        vm.current_realm.globals[index].native_function = object_constructor;

        object_obj := allocate_object(vm);
        object_obj.prototype = vm.function_prototype;
        vm.current_realm.globals[index].object = object_obj;

        set_object_property(vm, object_obj, "name",   Value.{ type = .STRING, s = "Object" });
        set_object_property(vm, object_obj, "length", Value.{ type = .NUMBER, number = 1 });

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
        add_static_method(vm, object_obj, "isExtensible",             object_is_extensible);

        add_static_property(vm, object_obj, "prototype", Value.{ type = .OBJECT, object = vm.object_prototype });
    }
}

object_constructor :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count > 0 && arguments[0].type != .UNDEFINED && arguments[0].type != .NULL {
        if arguments[0].type == .OBJECT || arguments[0].type == .ARRAY || arguments[0].type == .FUNCTION || arguments[0].type == .NATIVE_FUNCTION {
            return arguments[0];
        }
    }

    obj := allocate_object(vm);
    obj.prototype = vm.object_prototype;
    return .{ type = .OBJECT, object = obj };
}

object_is_prototype_of :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .BOOLEAN, boolean = false };

    arg := arguments[0];
    arg_obj: *Gc_Object;
    if arg.type == {
        case .OBJECT;          arg_obj = arg.object;
        case .ARRAY;           arg_obj = arg.object;
        case .FUNCTION;        arg_obj = arg.object;
        case .NATIVE_FUNCTION; arg_obj = arg.object;
        case .GENERATOR;       arg_obj = arg.generator_object;
    }
    if !arg_obj return .{ type = .BOOLEAN, boolean = false };

    this_obj: *Gc_Object;
    if this.type == {
        case .OBJECT;          this_obj = this.object;
        case .ARRAY;           this_obj = this.object;
        case .FUNCTION;        this_obj = this.object;
        case .NATIVE_FUNCTION; this_obj = this.object;
        case .GENERATOR;       this_obj = this.generator_object;
    }
    if !this_obj return .{ type = .BOOLEAN, boolean = false };

    current := arg_obj.prototype;
    while current {
        if current == this_obj return .{ type = .BOOLEAN, boolean = true };
        current = current.prototype;
    }

    return .{ type = .BOOLEAN, boolean = false };
}

object_set_prototype :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count < 2 {
        throw_exception(vm, "TypeError: Object.setPrototypeOf requires at least 2 arguments");
        return .{ type = .UNDEFINED };
    }

    target    := arguments[0];
    prototype := arguments[1];

    if target.type == .UNDEFINED || target.type == .NULL {
        throw_exception(vm, "TypeError: Object.setPrototypeOf called on null or undefined");
        return .{ type = .UNDEFINED };
    }

    if prototype.type != .OBJECT && prototype.type != .ARRAY && prototype.type != .NULL {
        throw_exception(vm, "TypeError: Object prototype may only be an Object or null");
        return .{ type = .UNDEFINED };
    }

    if (target.type == .OBJECT || target.type == .ARRAY) && target.object {
        if target.object == vm.object_prototype {
            if prototype.type != .NULL {
                throw_exception(vm, "TypeError: Immutable prototype object '#<Object>' cannot have their prototype set");
                return .{ type = .UNDEFINED };
            }
        }

        if prototype.type == .OBJECT || prototype.type == .ARRAY {
            current := prototype.object;
            while current {
                if current == target.object {
                    throw_exception(vm, "TypeError: Cyclic __proto__ value");
                    return .{ type = .UNDEFINED };
                }
                current = current.prototype;
            }

            target.object.prototype = prototype.object;
        } else if prototype.type == .NULL {
            target.object.prototype = null;
        }
    }

    return target;
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

    target_obj: *Gc_Object;
    if target_value.type == {
        case .OBJECT;          target_obj = target_value.object;
        case .ARRAY;           target_obj = target_value.object;
        case .FUNCTION;        target_obj = target_value.object;
        case .NATIVE_FUNCTION; target_obj = target_value.object;
        case .GENERATOR;       target_obj = target_value.generator_object;
    }
    if !target_obj return .{ type = .UNDEFINED };

    prototype := target_obj.prototype;

    if !prototype return .{ type = .NULL };

    if prototype.realm {
        for g: prototype.realm.globals {
            if (g.type == .NATIVE_FUNCTION || g.type == .FUNCTION) && g.object == prototype {
                return g;
            }
        }
    }

    return .{ type = .OBJECT, object = prototype };
}

object_define_property :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count < 3 return .{ type = .UNDEFINED };

    target_value := arguments[0];

    if (target_value.type != .OBJECT && target_value.type != .ARRAY && target_value.type != .FUNCTION && target_value.type != .NATIVE_FUNCTION) || !target_value.object return target_value;

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

    if (target_value.type != .OBJECT && target_value.type != .ARRAY && target_value.type != .FUNCTION && target_value.type != .NATIVE_FUNCTION) || !target_value.object return .{ type = .UNDEFINED };

    name: string;
    if arguments[1].type == .SYMBOL {
        name = get_symbol_string_key(*arguments[1]);
    } else {
        name = value_to_string(vm, arguments[1]);
    }
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
        } else if object.kind == .ARRAY && name == "length" {
            has_property = true;
            property_value = .{ type = .NUMBER, number = cast(float64) object.elements.count };
        } else if is_typed_array(object.kind) && name == "length" {
            has_property = true;
            property_value = .{ type = .NUMBER, number = cast(float64) get_typed_array_length(object) };
        } else if object.kind == .GLOBAL_PROXY {
            found_global, global_idx := get_global_index(vm, name);
            target_realm := ifx object.realm then object.realm else vm.current_realm;
            if found_global && target_realm.globals[global_idx].type != .EMPTY {
                has_property = true;
                property_value = target_realm.globals[global_idx];
            }
        }
    }

    if has_property {
        descriptor := allocate_object(vm);

        enumerable := true;
        configurable := true;
        if name == "cause" || name == "message" || name == "name" || name == "length" || name == "prototype" || name == "constructor" || starts_with(name, "@@") {
            enumerable = false;
        }
        if object.kind == .GLOBAL_PROXY {
            enumerable = false; // Built-ins are non-enumerable on global object
        }

        if ((object.kind == .ARRAY || is_typed_array(object.kind)) && name == "length") || ((target_value.type == .FUNCTION || target_value.type == .NATIVE_FUNCTION) && name == "prototype") {
            configurable = false;
        }

        writable := true;
        if (target_value.type == .FUNCTION || target_value.type == .NATIVE_FUNCTION) && (name == "length" || name == "name") {
            writable = false;
        }
        if (target_value.type == .NATIVE_FUNCTION && name == "prototype") || name == "@@Symbol.toStringTag" || ((object == vm.async_generator_prototype || object == vm.generator_prototype) && name == "constructor") {
            writable = false;
        }

        set_object_property(vm, descriptor, "value",        property_value);
        set_object_property(vm, descriptor, "writable",     .{ type = .BOOLEAN, boolean = writable });
        set_object_property(vm, descriptor, "enumerable",   .{ type = .BOOLEAN, boolean = enumerable });
        set_object_property(vm, descriptor, "configurable", .{ type = .BOOLEAN, boolean = configurable });

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

object_is_extensible :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .BOOLEAN, boolean = false };
    arg := arguments[0];
    if arg.type == .OBJECT || arg.type == .ARRAY || arg.type == .FUNCTION || arg.type == .NATIVE_FUNCTION {
        return .{ type = .BOOLEAN, boolean = true };
    }
    return .{ type = .BOOLEAN, boolean = false };
}

object_has_own_property :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if (this.type != .OBJECT && this.type != .ARRAY && this.type != .FUNCTION && this.type != .NATIVE_FUNCTION) || !this.object return .{ type = .BOOLEAN, boolean = false };
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
    if object.kind == .ARRAY && name == "length" return .{ type = .BOOLEAN, boolean = true };
    if is_typed_array(object.kind) && name == "length" return .{ type = .BOOLEAN, boolean = true };

    if object.kind == .GLOBAL_PROXY {
        found_global, global_idx := get_global_index(vm, name);
        target_realm := ifx object.realm then object.realm else vm.current_realm;
        if found_global && target_realm.globals[global_idx].type != .EMPTY {
            return .{ type = .BOOLEAN, boolean = true };
        }
    }

    return .{ type = .BOOLEAN, boolean = false };
}

object_to_string :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .UNDEFINED return .{ type = .STRING, s = "[object Undefined]" };
    if this.type == .NULL      return .{ type = .STRING, s = "[object Null]" };

    if this.type == .NUMBER          return .{ type = .STRING, s = "[object Number]" };
    if this.type == .STRING          return .{ type = .STRING, s = "[object String]" };
    if this.type == .BOOLEAN         return .{ type = .STRING, s = "[object Boolean]" };
    if this.type == .ARRAY           return .{ type = .STRING, s = "[object Array]" };
    if this.type == .FUNCTION        return .{ type = .STRING, s = "[object Function]" };
    if this.type == .NATIVE_FUNCTION return .{ type = .STRING, s = "[object Function]" };
    if this.type == .GENERATOR       return .{ type = .STRING, s = "[object Generator]" };
    if this.type == .SYMBOL          return .{ type = .STRING, s = "[object Symbol]" };

    if this.type == .OBJECT && this.object {
        kind := this.object.kind;
        if kind == .ARRAY           return .{ type = .STRING, s = "[object Array]" };
        if kind == .DATE            return .{ type = .STRING, s = "[object Date]" };
        if kind == .REGEXP          return .{ type = .STRING, s = "[object RegExp]" };
        if kind == .BOOLEAN_WRAPPER return .{ type = .STRING, s = "[object Boolean]" };
        if kind == .NUMBER_WRAPPER  return .{ type = .STRING, s = "[object Number]" };
        if kind == .STRING_WRAPPER  return .{ type = .STRING, s = "[object String]" };
        if kind == .PROMISE         return .{ type = .STRING, s = "[object Promise]" };
        if kind == .MAP             return .{ type = .STRING, s = "[object Map]" };
        if kind == .SET             return .{ type = .STRING, s = "[object Set]" };
    }

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

    if obj.kind == .GLOBAL_PROXY {
        found_global, global_idx := get_global_index(vm, name);
        if found_global && vm.current_realm.globals[global_idx].type != .EMPTY {
            found = true;
        }
    }

    if !found return .{ type = .BOOLEAN, boolean = false };

    enumerable := true;
    if name == "cause" || name == "message" || name == "name" || name == "length" || name == "prototype" || name == "constructor" || starts_with(name, "@@") || obj.kind == .GLOBAL_PROXY {
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