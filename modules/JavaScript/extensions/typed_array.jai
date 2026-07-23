init_vm_typed_arrays :: (vm: *Vm) {
    init_typed_array(vm, "Uint8Array",        .UINT8_ARRAY,         *vm.uint8_array_prototype,         typed_array_constructor_uint8);
    init_typed_array(vm, "Int8Array",         .INT8_ARRAY,          *vm.int8_array_prototype,          typed_array_constructor_int8);
    init_typed_array(vm, "Uint8ClampedArray", .UINT8_CLAMPED_ARRAY, *vm.uint8_clamped_array_prototype, typed_array_constructor_uint8_clamped);
    init_typed_array(vm, "Uint16Array",       .UINT16_ARRAY,        *vm.uint16_array_prototype,        typed_array_constructor_uint16);
    init_typed_array(vm, "Int16Array",        .INT16_ARRAY,         *vm.int16_array_prototype,         typed_array_constructor_int16);
    init_typed_array(vm, "Uint32Array",       .UINT32_ARRAY,        *vm.uint32_array_prototype,        typed_array_constructor_uint32);
    init_typed_array(vm, "Int32Array",        .INT32_ARRAY,         *vm.int32_array_prototype,         typed_array_constructor_int32);
    init_typed_array(vm, "Float32Array",      .FLOAT32_ARRAY,       *vm.float32_array_prototype,       typed_array_constructor_float32);
    init_typed_array(vm, "Float64Array",      .FLOAT64_ARRAY,       *vm.float64_array_prototype,       typed_array_constructor_float64);
}

init_typed_array :: (vm: *Vm, name: string, kind: Gc_Object_Kind, prototype_ptr: **Gc_Object, constructor: Native_Function) {
    found, index := get_global_index(vm, name);

    if !prototype_ptr.* {
        proto := allocate_object(vm);
        prototype_ptr.* = proto;
        proto.prototype = vm.object_prototype;

        add_instance_method(vm, proto, "set",      typed_array_set);
        add_instance_method(vm, proto, "subarray", typed_array_subarray);
        add_instance_method(vm, proto, "slice",    typed_array_slice);
        add_instance_method(vm, proto, "fill",     typed_array_fill);
        add_instance_method(vm, proto, "join",     typed_array_join);
        add_instance_method(vm, proto, "indexOf",  typed_array_index_of);
        add_instance_method(vm, proto, "includes", typed_array_includes);
        add_instance_method(vm, proto, "reverse",  typed_array_reverse);
        add_instance_method(vm, proto, "map",      typed_array_map);
        add_instance_method(vm, proto, "filter",   typed_array_filter);
        add_instance_method(vm, proto, "reduce",   typed_array_reduce);
        add_instance_method(vm, proto, "forEach",  typed_array_for_each);
    }

    if found {
        vm.current_realm.globals[index].type            = .NATIVE_FUNCTION;
        vm.current_realm.globals[index].native_function = constructor;

        array_object := allocate_object(vm);
        vm.current_realm.globals[index].object = array_object;
        array_object.prototype = prototype_ptr.*;

        prototype_value := Value.{
            type   = .OBJECT,
            object = prototype_ptr.*,
        };

        add_static_property(vm, array_object,    "prototype",   prototype_value);
        add_static_property(vm, prototype_ptr.*, "constructor", vm.current_realm.globals[index]);

        bytes_per_element := 1;
        if kind == {
            case .UINT16_ARRAY; bytes_per_element = 2;
            case .INT16_ARRAY;  bytes_per_element = 2;
            case .UINT32_ARRAY; bytes_per_element = 4;
            case .INT32_ARRAY;  bytes_per_element = 4;
            case .FLOAT32_ARRAY; bytes_per_element = 4;
            case .FLOAT64_ARRAY; bytes_per_element = 8;
        }

        bpe_val := Value.{ type = .NUMBER, number = cast(float64) bytes_per_element };
        add_static_property(vm, array_object, "BYTES_PER_ELEMENT", bpe_val);
        add_static_property(vm, prototype_ptr.*, "BYTES_PER_ELEMENT", bpe_val);
    }
}

typed_array_constructor_uint8         :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value { return typed_array_constructor_impl(vm, this, arguments, is_new, .UINT8_ARRAY, 1); }
typed_array_constructor_int8          :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value { return typed_array_constructor_impl(vm, this, arguments, is_new, .INT8_ARRAY, 1); }
typed_array_constructor_uint8_clamped :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value { return typed_array_constructor_impl(vm, this, arguments, is_new, .UINT8_CLAMPED_ARRAY, 1); }
typed_array_constructor_uint16        :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value { return typed_array_constructor_impl(vm, this, arguments, is_new, .UINT16_ARRAY, 2); }
typed_array_constructor_int16         :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value { return typed_array_constructor_impl(vm, this, arguments, is_new, .INT16_ARRAY, 2); }
typed_array_constructor_uint32        :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value { return typed_array_constructor_impl(vm, this, arguments, is_new, .UINT32_ARRAY, 4); }
typed_array_constructor_int32         :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value { return typed_array_constructor_impl(vm, this, arguments, is_new, .INT32_ARRAY, 4); }
typed_array_constructor_float32       :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value { return typed_array_constructor_impl(vm, this, arguments, is_new, .FLOAT32_ARRAY, 4); }
typed_array_constructor_float64       :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value { return typed_array_constructor_impl(vm, this, arguments, is_new, .FLOAT64_ARRAY, 8); }

typed_array_constructor_impl :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool, kind: Gc_Object_Kind, element_size: int) -> Value {
    if !is_new return .{};

    object := allocate_object(vm);
    object.kind = kind;
    
    if kind == {
        case .UINT8_ARRAY;         object.prototype = vm.uint8_array_prototype;
        case .INT8_ARRAY;          object.prototype = vm.int8_array_prototype;
        case .UINT8_CLAMPED_ARRAY; object.prototype = vm.uint8_clamped_array_prototype;
        case .UINT16_ARRAY;        object.prototype = vm.uint16_array_prototype;
        case .INT16_ARRAY;         object.prototype = vm.int16_array_prototype;
        case .UINT32_ARRAY;        object.prototype = vm.uint32_array_prototype;
        case .INT32_ARRAY;         object.prototype = vm.int32_array_prototype;
        case .FLOAT32_ARRAY;       object.prototype = vm.float32_array_prototype;
        case .FLOAT64_ARRAY;       object.prototype = vm.float64_array_prototype;
    }

    length := 0;

    if arguments.count > 0 {
        arg := arguments[0];
        if arg.type == .NUMBER {
            length_f := arg.number;
            if isnan(length_f) {
                length = 0;
            } else if length_f < 0 || length_f > 104857600 {
                throw_exception(vm, "RangeError: Invalid typed array length");
                return .{};
            } else {
                length = cast(int) length_f;
            }
            buffer := cast(*u8) alloc(length * element_size);
            memset(buffer, 0, length * element_size);
            object.primitive_value = .{ type = .STRING, s = string.{ length * element_size, buffer } };
        } else if arg.type == .ARRAY || (arg.type == .OBJECT && (arg.object.kind == .ARRAY || is_typed_array(arg.object.kind))) {
            if is_typed_array(arg.object.kind) {
                length = get_typed_array_length(arg.object);
                buffer := cast(*u8) alloc(length * element_size);
                object.primitive_value = .{ type = .STRING, s = string.{ length * element_size, buffer } };
                for i: 0..length-1 {
                    set_typed_array_element(object, i, get_typed_array_element(arg.object, i));
                }
            } else {
                length = arg.object.elements.count;
                buffer := cast(*u8) alloc(length * element_size);
                object.primitive_value = .{ type = .STRING, s = string.{ length * element_size, buffer } };
                for i: 0..length-1 {
                    set_typed_array_element(object, i, value_to_number(arg.object.elements[i]));
                }
            }
        } else {
            object.primitive_value = .{ type = .STRING, s = string.{ 0, null } };
        }
    } else {
        object.primitive_value = .{ type = .STRING, s = string.{ 0, null } };
    }

    return .{ type = .OBJECT, object = object };
}

typed_array_set :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && is_typed_array(this.object.kind) && this.object && arguments.count > 0 {
        source := arguments[0];
        offset := 0;

        if arguments.count > 1 && arguments[1].type == .NUMBER {
            offset_f := arguments[1].number;
            if isnan(offset_f) {
                offset = 0;
            } else if offset_f < 0 || offset_f > 104857600 {
                throw_exception(vm, "RangeError: Invalid typed array offset");
                return .{};
            } else {
                offset = cast(int) offset_f;
            }
        }

        if offset < 0 return .{};

        dst_len := get_typed_array_length(this.object);

        if source.type == .ARRAY || (source.type == .OBJECT && (source.object.kind == .ARRAY || is_typed_array(source.object.kind))) {
            if is_typed_array(source.object.kind) {
                copy_len := get_typed_array_length(source.object);
                if offset + copy_len > dst_len copy_len = dst_len - offset;
                for i: 0..copy_len-1 {
                    set_typed_array_element(this.object, offset + i, get_typed_array_element(source.object, i));
                }
            } else {
                copy_len := source.object.elements.count;
                if offset + copy_len > dst_len copy_len = dst_len - offset;
                for i: 0..copy_len-1 {
                    set_typed_array_element(this.object, offset + i, value_to_number(source.object.elements[i]));
                }
            }
        }
    }
    return .{ type = .UNDEFINED };
}

typed_array_subarray :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && is_typed_array(this.object.kind) && this.object {
        start := 0;
        end := get_typed_array_length(this.object);

        if arguments.count > 0 && arguments[0].type == .NUMBER {
            start = cast(int) arguments[0].number;
            if start < 0 start = max(0, end + start);
            if start > end start = end;
        }

        if arguments.count > 1 && arguments[1].type == .NUMBER {
            end = cast(int) arguments[1].number;
            if end < 0 end = max(0, get_typed_array_length(this.object) + end);
            if end > get_typed_array_length(this.object) end = get_typed_array_length(this.object);
        }

        if start > end start = end;
        length := end - start;

        element_size := this.object.primitive_value.s.count / get_typed_array_length(this.object);

        object := allocate_object(vm);
        object.kind = this.object.kind;
        object.prototype = this.object.prototype;

        buffer := cast(*u8) alloc(length * element_size);
        if length > 0 memcpy(buffer, this.object.primitive_value.s.data + start * element_size, length * element_size);

        object.primitive_value = .{ type = .STRING, s = string.{ length * element_size, buffer } };

        return .{ type = .OBJECT, object = object };
    }
    return .{ type = .UNDEFINED };
}

typed_array_slice :: typed_array_subarray;

typed_array_fill :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && is_typed_array(this.object.kind) && this.object && arguments.count > 0 {
        value := value_to_number(arguments[0]);

        start := 0;
        end := get_typed_array_length(this.object);

        if arguments.count > 1 && arguments[1].type == .NUMBER {
            start = cast(int) arguments[1].number;
            if start < 0 start = max(0, end + start);
            if start > end start = end;
        }

        if arguments.count > 2 && arguments[2].type == .NUMBER {
            end = cast(int) arguments[2].number;
            if end < 0 end = max(0, get_typed_array_length(this.object) + end);
            if end > get_typed_array_length(this.object) end = get_typed_array_length(this.object);
        }

        if start > end start = end;
        length := end - start;

        for i: start..end-1 {
            set_typed_array_element(this.object, i, value);
        }

        return this;
    }
    return .{ type = .UNDEFINED };
}

typed_array_join :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && is_typed_array(this.object.kind) && this.object {
        separator := ",";
        if arguments.count > 0 && arguments[0].type == .STRING separator = arguments[0].s;

        builder: String_Builder;
        builder.allocator = temp;

        len := get_typed_array_length(this.object);
        for i: 0..len-1 {
            if i > 0 append(*builder, separator);
            append(*builder, tprint("%", get_typed_array_element(this.object, i)));
        }

        return .{ type = .STRING, s = builder_to_string(*builder,, allocator = temp) };
    }
    return .{ type = .UNDEFINED };
}

typed_array_index_of :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && is_typed_array(this.object.kind) && this.object && arguments.count > 0 {
        search_element := value_to_number(arguments[0]);
        len := get_typed_array_length(this.object);

        start := 0;
        if arguments.count > 1 && arguments[1].type == .NUMBER {
            start = cast(int) arguments[1].number;
            if start < 0 start = max(0, len + start);
            if start > len start = len;
        }

        for i: start..len-1 {
            if get_typed_array_element(this.object, i) == search_element return .{ type = .NUMBER, number = cast(float64) i };
        }
    }
    return .{ type = .NUMBER, number = -1.0 };
}

typed_array_includes :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    index_val := typed_array_index_of(vm, this, arguments, is_new);
    if index_val.number >= 0 return .{ type = .BOOLEAN, boolean = true };
    return .{ type = .BOOLEAN, boolean = false };
}

typed_array_reverse :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && is_typed_array(this.object.kind) && this.object {
        len := get_typed_array_length(this.object);
        for i: 0..(len / 2)-1 {
            temp := get_typed_array_element(this.object, i);
            set_typed_array_element(this.object, i, get_typed_array_element(this.object, len - 1 - i));
            set_typed_array_element(this.object, len - 1 - i, temp);
        }
        return this;
    }
    return .{ type = .UNDEFINED };
}

typed_array_map :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && is_typed_array(this.object.kind) && this.object && arguments.count > 0 && arguments[0].type == .FUNCTION {
        length := get_typed_array_length(this.object);
        element_size := this.object.primitive_value.s.count / max(1, length);

        object := allocate_object(vm);
        object.kind = this.object.kind;
        object.prototype = this.object.prototype;
        buffer := cast(*u8) alloc(length * element_size);
        object.primitive_value = .{ type = .STRING, s = string.{ length * element_size, buffer } };

        func := arguments[0];
        args: [3] Value;
        args[2] = this;

        this_argument := ifx arguments.count > 1 then arguments[1] else Value.{};

        for i: 0..length-1 {
            args[0] = .{ type = .NUMBER, number = get_typed_array_element(this.object, i) };
            args[1] = .{ type = .NUMBER, number = cast(float64) i };
            result := call_value(vm, this_argument, func, args);
            set_typed_array_element(object, i, value_to_number(result));
        }

        return .{ type = .OBJECT, object = object };
    }
    return .{ type = .UNDEFINED };
}

typed_array_filter :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && is_typed_array(this.object.kind) && this.object && arguments.count > 0 && arguments[0].type == .FUNCTION {
        length := get_typed_array_length(this.object);
        element_size := this.object.primitive_value.s.count / max(1, length);

        func := arguments[0];
        args: [3] Value;
        args[2] = this;

        this_argument := ifx arguments.count > 1 then arguments[1] else Value.{};

        temp_buffer := cast(*u8) alloc(length * element_size);
        defer free(temp_buffer);
        
        // We will construct a temporary typed array wrapping temp_buffer to easily set elements
        temp_obj: Gc_Object;
        temp_obj.kind = this.object.kind;
        temp_obj.primitive_value = .{ type = .STRING, s = string.{ length * element_size, temp_buffer } };

        filtered_length := 0;

        for i: 0..length-1 {
            args[0] = .{ type = .NUMBER, number = get_typed_array_element(this.object, i) };
            args[1] = .{ type = .NUMBER, number = cast(float64) i };

            result := call_value(vm, this_argument, func, args);
            if is_truthy(result) {
                set_typed_array_element(*temp_obj, filtered_length, get_typed_array_element(this.object, i));
                filtered_length += 1;
            }
        }

        object := allocate_object(vm);
        object.kind = this.object.kind;
        object.prototype = this.object.prototype;
        buffer := cast(*u8) alloc(filtered_length * element_size);
        if filtered_length > 0 memcpy(buffer, temp_buffer, filtered_length * element_size);
        object.primitive_value = .{ type = .STRING, s = string.{ filtered_length * element_size, buffer } };

        return .{ type = .OBJECT, object = object };
    }
    return .{ type = .UNDEFINED };
}

typed_array_reduce :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && is_typed_array(this.object.kind) && this.object && arguments.count > 0 && arguments[0].type == .FUNCTION {
        length := get_typed_array_length(this.object);
        if length == 0 && arguments.count == 1 {
            throw_exception(vm, "Reduce of empty array with no initial value");
            return .{};
        }

        func := arguments[0];
        args: [4] Value;

        start_index := 0;
        accumulator: Value;

        if arguments.count > 1 {
            accumulator = arguments[1];
        } else {
            accumulator = .{ type = .NUMBER, number = get_typed_array_element(this.object, 0) };
            start_index = 1;
        }

        for i: start_index..length-1 {
            args[0] = accumulator;
            args[1] = .{ type = .NUMBER, number = get_typed_array_element(this.object, i) };
            args[2] = .{ type = .NUMBER, number = cast(float64) i };
            args[3] = this;
            accumulator = call_value(vm, .{ type = .UNDEFINED }, func, args);
        }

        return accumulator;
    }
    return .{ type = .UNDEFINED };
}

typed_array_for_each :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && is_typed_array(this.object.kind) && this.object && arguments.count > 0 && arguments[0].type == .FUNCTION {
        length := get_typed_array_length(this.object);

        func := arguments[0];
        args: [3] Value;
        args[2] = this;

        this_argument := ifx arguments.count > 1 then arguments[1] else Value.{};

        for i: 0..length-1 {
            args[0] = .{ type = .NUMBER, number = get_typed_array_element(this.object, i) };
            args[1] = .{ type = .NUMBER, number = cast(float64) i };
            call_value(vm, this_argument, func, args);
        }
    }
    return .{ type = .UNDEFINED };
}
