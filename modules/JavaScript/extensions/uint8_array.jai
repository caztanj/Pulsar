init_vm_uint8_array :: (vm: *Vm) {
    found, index := get_global_index(vm, "Uint8Array");

    if !vm.uint8_array_prototype {
        vm.uint8_array_prototype = allocate_object(vm);
        vm.uint8_array_prototype.prototype = vm.object_prototype;

        add_instance_method(vm, vm.uint8_array_prototype, "set",      uint8_array_set);
        add_instance_method(vm, vm.uint8_array_prototype, "subarray", uint8_array_subarray);
        add_instance_method(vm, vm.uint8_array_prototype, "slice",    uint8_array_slice);
        add_instance_method(vm, vm.uint8_array_prototype, "fill",     uint8_array_fill);
        add_instance_method(vm, vm.uint8_array_prototype, "join",     uint8_array_join);
        add_instance_method(vm, vm.uint8_array_prototype, "indexOf",  uint8_array_index_of);
        add_instance_method(vm, vm.uint8_array_prototype, "includes", uint8_array_includes);
        add_instance_method(vm, vm.uint8_array_prototype, "reverse",  uint8_array_reverse);
        add_instance_method(vm, vm.uint8_array_prototype, "map",      uint8_array_map);
        add_instance_method(vm, vm.uint8_array_prototype, "filter",   uint8_array_filter);
        add_instance_method(vm, vm.uint8_array_prototype, "reduce",   uint8_array_reduce);
        add_instance_method(vm, vm.uint8_array_prototype, "forEach",  uint8_array_for_each);
    }

    if found {
        vm.current_realm.globals[index].type            = .NATIVE_FUNCTION;
        vm.current_realm.globals[index].native_function = uint8_array_constructor;

        uint8_array_object := allocate_object(vm);

        vm.current_realm.globals[index].object = uint8_array_object;

        uint8_array_object.prototype = vm.uint8_array_prototype;

        prototype_value := Value.{
            type   = .OBJECT,
            object = vm.uint8_array_prototype,
        };

        add_static_property(vm, uint8_array_object,       "prototype",   prototype_value);
        add_static_property(vm, vm.uint8_array_prototype, "constructor", vm.current_realm.globals[index]);
    }
}

uint8_array_constructor :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if !is_new return .{};

    object := allocate_object(vm);
    object.kind = .UINT8_ARRAY;
    object.prototype = vm.uint8_array_prototype;

    length := 0;

    if arguments.count > 0 {
        arg := arguments[0];
        if arg.type == .NUMBER {
            length = cast(int) arg.number;
            buffer := cast(*u8) alloc(length);
            memset(buffer, 0, length);
            object.primitive_value = .{ type = .STRING, s = string.{ length, buffer } };
        } else if arg.type == .ARRAY || (arg.type == .OBJECT && (arg.object.kind == .ARRAY || arg.object.kind == .UINT8_ARRAY)) {
            if arg.object.kind == .UINT8_ARRAY {
                length = arg.object.primitive_value.s.count;
                buffer := cast(*u8) alloc(length);
                memcpy(buffer, arg.object.primitive_value.s.data, length);
                object.primitive_value = .{ type = .STRING, s = string.{ length, buffer } };
            } else {
                length = arg.object.elements.count;
                buffer := cast(*u8) alloc(length);
                for i: 0..length-1 {
                    buffer[i] = cast(u8) value_to_number(arg.object.elements[i]);
                }
                object.primitive_value = .{ type = .STRING, s = string.{ length, buffer } };
            }
        } else {
            object.primitive_value = .{ type = .STRING, s = string.{ 0, null } };
        }
    } else {
        object.primitive_value = .{ type = .STRING, s = string.{ 0, null } };
    }

    return .{ type = .OBJECT, object = object };
}

uint8_array_set :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.kind == .UINT8_ARRAY && this.object && arguments.count > 0 {
        source := arguments[0];
        offset := 0;

        if arguments.count > 1 && arguments[1].type == .NUMBER {
            offset = cast(int) arguments[1].number;
        }

        if offset < 0 return .{};

        dst_str := this.object.primitive_value.s;

        if source.type == .ARRAY || (source.type == .OBJECT && (source.object.kind == .ARRAY || source.object.kind == .UINT8_ARRAY)) {
            if source.object.kind == .UINT8_ARRAY {
                src_str := source.object.primitive_value.s;
                copy_len := src_str.count;
                if offset + copy_len > dst_str.count copy_len = dst_str.count - offset;
                if copy_len > 0 memcpy(dst_str.data + offset, src_str.data, copy_len);
            } else {
                copy_len := source.object.elements.count;
                if offset + copy_len > dst_str.count copy_len = dst_str.count - offset;
                for i: 0..copy_len-1 {
                    dst_str.data[offset + i] = cast(u8) value_to_number(source.object.elements[i]);
                }
            }
        }
    }
    return .{ type = .UNDEFINED };
}

uint8_array_subarray :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.kind == .UINT8_ARRAY && this.object {
        start := 0;
        end := this.object.primitive_value.s.count;

        if arguments.count > 0 && arguments[0].type == .NUMBER {
            start = cast(int) arguments[0].number;
            if start < 0 start = max(0, end + start);
            if start > end start = end;
        }

        if arguments.count > 1 && arguments[1].type == .NUMBER {
            end = cast(int) arguments[1].number;
            if end < 0 end = max(0, this.object.primitive_value.s.count + end);
            if end > this.object.primitive_value.s.count end = this.object.primitive_value.s.count;
        }

        if start > end start = end;
        length := end - start;

        object := allocate_object(vm);
        object.kind = .UINT8_ARRAY;
        object.prototype = vm.uint8_array_prototype;

        buffer := cast(*u8) alloc(length);
        if length > 0 memcpy(buffer, this.object.primitive_value.s.data + start, length);

        object.primitive_value = .{ type = .STRING, s = string.{ length, buffer } };

        return .{ type = .OBJECT, object = object };
    }
    return .{ type = .UNDEFINED };
}

uint8_array_slice :: uint8_array_subarray;

uint8_array_fill :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.kind == .UINT8_ARRAY && this.object && arguments.count > 0 {
        value := cast(u8) value_to_number(arguments[0]);

        start := 0;
        end := this.object.primitive_value.s.count;

        if arguments.count > 1 && arguments[1].type == .NUMBER {
            start = cast(int) arguments[1].number;
            if start < 0 start = max(0, end + start);
            if start > end start = end;
        }

        if arguments.count > 2 && arguments[2].type == .NUMBER {
            end = cast(int) arguments[2].number;
            if end < 0 end = max(0, this.object.primitive_value.s.count + end);
            if end > this.object.primitive_value.s.count end = this.object.primitive_value.s.count;
        }

        if start > end start = end;
        length := end - start;

        if length > 0 memset(this.object.primitive_value.s.data + start, value, length);

        return this;
    }
    return .{ type = .UNDEFINED };
}

uint8_array_join :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.kind == .UINT8_ARRAY && this.object {
        separator := ",";
        if arguments.count > 0 && arguments[0].type == .STRING separator = arguments[0].s;

        builder: String_Builder;
        builder.allocator = temp;

        str := this.object.primitive_value.s;
        for i: 0..str.count-1 {
            if i > 0 append(*builder, separator);
            append(*builder, tprint("%", str.data[i]));
        }

        return .{ type = .STRING, s = builder_to_string(*builder,, allocator = temp) };
    }
    return .{ type = .UNDEFINED };
}

uint8_array_index_of :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.kind == .UINT8_ARRAY && this.object && arguments.count > 0 {
        search_element := cast(u8) value_to_number(arguments[0]);
        str := this.object.primitive_value.s;

        start := 0;
        if arguments.count > 1 && arguments[1].type == .NUMBER {
            start = cast(int) arguments[1].number;
            if start < 0 start = max(0, str.count + start);
            if start > str.count start = str.count;
        }

        for i: start..str.count-1 {
            if str.data[i] == search_element return .{ type = .NUMBER, number = cast(float64) i };
        }
    }
    return .{ type = .NUMBER, number = -1.0 };
}

uint8_array_includes :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    index_val := uint8_array_index_of(vm, this, arguments, is_new);
    if index_val.number >= 0 return .{ type = .BOOLEAN, boolean = true };
    return .{ type = .BOOLEAN, boolean = false };
}

uint8_array_reverse :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.kind == .UINT8_ARRAY && this.object {
        str := this.object.primitive_value.s;
        len := str.count;
        for i: 0..(len / 2)-1 {
            temp := str.data[i];
            str.data[i] = str.data[len - 1 - i];
            str.data[len - 1 - i] = temp;
        }
        return this;
    }
    return .{ type = .UNDEFINED };
}

uint8_array_map :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.kind == .UINT8_ARRAY && this.object && arguments.count > 0 && arguments[0].type == .FUNCTION {
        str := this.object.primitive_value.s;
        length := str.count;

        object := allocate_object(vm);
        object.kind = .UINT8_ARRAY;
        object.prototype = vm.uint8_array_prototype;
        buffer := cast(*u8) alloc(length);
        object.primitive_value = .{ type = .STRING, s = string.{ length, buffer } };

        func := arguments[0];
        args: [3] Value;
        args[2] = this;

        this_argument := ifx arguments.count > 1 then arguments[1] else Value.{};

        for i: 0..length-1 {
            args[0] = .{ type = .NUMBER, number = cast(float64) str.data[i] };
            args[1] = .{ type = .NUMBER, number = cast(float64) i };
            result := call_value(vm, this_argument, func, args);
            buffer[i] = cast(u8) value_to_number(result);
        }

        return .{ type = .OBJECT, object = object };
    }
    return .{ type = .UNDEFINED };
}

uint8_array_filter :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.kind == .UINT8_ARRAY && this.object && arguments.count > 0 && arguments[0].type == .FUNCTION {
        str := this.object.primitive_value.s;
        length := str.count;

        func := arguments[0];
        args: [3] Value;
        args[2] = this;

        this_argument := ifx arguments.count > 1 then arguments[1] else Value.{};

        temp_buffer := cast(*u8) alloc(length);
        defer free(temp_buffer);

        filtered_length := 0;

        for i: 0..length-1 {
            args[0] = .{ type = .NUMBER, number = cast(float64) str.data[i] };
            args[1] = .{ type = .NUMBER, number = cast(float64) i };

            result := call_value(vm, this_argument, func, args);
            if is_truthy(result) {
                temp_buffer[filtered_length] = str.data[i];
                filtered_length += 1;
            }
        }

        object := allocate_object(vm);
        object.kind = .UINT8_ARRAY;
        object.prototype = vm.uint8_array_prototype;
        buffer := cast(*u8) alloc(filtered_length);
        if filtered_length > 0 memcpy(buffer, temp_buffer, filtered_length);
        object.primitive_value = .{ type = .STRING, s = string.{ filtered_length, buffer } };

        return .{ type = .OBJECT, object = object };
    }
    return .{ type = .UNDEFINED };
}

uint8_array_reduce :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.kind == .UINT8_ARRAY && this.object && arguments.count > 0 && arguments[0].type == .FUNCTION {
        str := this.object.primitive_value.s;
        length := str.count;
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
            accumulator = .{ type = .NUMBER, number = cast(float64) str.data[0] };
            start_index = 1;
        }

        for i: start_index..length-1 {
            args[0] = accumulator;
            args[1] = .{ type = .NUMBER, number = cast(float64) str.data[i] };
            args[2] = .{ type = .NUMBER, number = cast(float64) i };
            args[3] = this;
            accumulator = call_value(vm, .{ type = .UNDEFINED }, func, args);
        }

        return accumulator;
    }
    return .{ type = .UNDEFINED };
}

uint8_array_for_each :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.kind == .UINT8_ARRAY && this.object && arguments.count > 0 && arguments[0].type == .FUNCTION {
        str := this.object.primitive_value.s;
        length := str.count;

        func := arguments[0];
        args: [3] Value;
        args[2] = this;

        this_argument := ifx arguments.count > 1 then arguments[1] else Value.{};

        for i: 0..length-1 {
            args[0] = .{ type = .NUMBER, number = cast(float64) str.data[i] };
            args[1] = .{ type = .NUMBER, number = cast(float64) i };
            call_value(vm, this_argument, func, args);
        }
    }
    return .{ type = .UNDEFINED };
}
