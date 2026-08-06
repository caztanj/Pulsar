init_vm_data_view :: (vm: *Vm) {
    found, index := get_global_index(vm, "DataView");

    if !vm.data_view_prototype {
        vm.data_view_prototype = allocate_object(vm);
        vm.data_view_prototype.prototype = vm.object_prototype;
        add_instance_method(vm, vm.data_view_prototype, "buffer__getter__",     data_view_buffer_getter);
        add_instance_method(vm, vm.data_view_prototype, "byteLength__getter__", data_view_byte_length_getter);
        add_instance_method(vm, vm.data_view_prototype, "byteOffset__getter__", data_view_byte_offset_getter);
        add_instance_method(vm, vm.data_view_prototype, "getUint8",             data_view_get_uint8);
    }

    if found {
        vm.current_realm.globals[index].type            = .NATIVE_FUNCTION;
        vm.current_realm.globals[index].native_function = data_view_constructor;

        data_view_object := allocate_object(vm);
        vm.current_realm.globals[index].object = data_view_object;
        data_view_object.prototype = vm.function_prototype;

        set_object_property(vm, data_view_object, "name",   Value.{ type = .STRING, s = "DataView" });
        set_object_property(vm, data_view_object, "length", Value.{ type = .NUMBER, number = 1 });

        prototype_value := Value.{
            type   = .OBJECT,
            object = vm.data_view_prototype,
        };

        add_static_property(vm, data_view_object,    "prototype",   prototype_value);
        add_static_property(vm, vm.data_view_prototype, "constructor", vm.current_realm.globals[index]);
    }
}

data_view_constructor :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if !is_new {
        throw_exception(vm, "TypeError: Constructor DataView requires 'new'");
        return .{};
    }

    if arguments.count < 1 || arguments[0].type != .OBJECT || (arguments[0].object.kind != .ARRAY_BUFFER && arguments[0].object.kind != .SHARED_ARRAY_BUFFER) {
        throw_exception(vm, "TypeError: DataView constructor requires an ArrayBuffer or SharedArrayBuffer");
        return .{};
    }

    buffer_obj := arguments[0].object;
    if buffer_obj.is_detached {
        throw_exception(vm, "TypeError: Cannot construct DataView with detached ArrayBuffer");
        return .{};
    }
    buffer_length := buffer_obj.primitive_value.s.count;

    byte_offset := 0;
    has_byte_length := false;
    byte_length := 0;

    if arguments.count > 1 && arguments[1].type != .UNDEFINED {
        byte_offset_f := abstract_to_number(vm, arguments[1]);
        if vm.has_exception return .{};
        if isnan(byte_offset_f) || isinf(byte_offset_f) || byte_offset_f < 0 {
            throw_exception(vm, "RangeError: Invalid DataView byteOffset");
            return .{};
        }
        byte_offset = cast(int) byte_offset_f;
    }

    if byte_offset > buffer_length {
        throw_exception(vm, "RangeError: DataView byteOffset out of bounds");
        return .{};
    }

    if arguments.count > 2 && arguments[2].type != .UNDEFINED {
        has_byte_length = true;
        byte_length_f := abstract_to_number(vm, arguments[2]);
        if vm.has_exception return .{};
        if isnan(byte_length_f) || isinf(byte_length_f) || byte_length_f < 0 {
            throw_exception(vm, "RangeError: Invalid DataView byteLength");
            return .{};
        }
        byte_length = cast(int) byte_length_f;
        if byte_offset + byte_length > buffer_length {
            throw_exception(vm, "RangeError: DataView length exceeds ArrayBuffer length");
            return .{};
        }
    } else {
        has_byte_length = false;
        byte_length = buffer_length - byte_offset;
    }

    object: *Gc_Object;
    if this.type == .OBJECT {
        object = this.object;
    } else {
        object = allocate_object(vm);
        if this.type == .FUNCTION || this.type == .NATIVE_FUNCTION {
            found, prototype_value := lookup_property(vm, this.object, "prototype");
            if vm.has_exception return .{};
            if prototype_value.type == .OBJECT {
                object.prototype = prototype_value.object;
            } else {
                object.prototype = vm.data_view_prototype;
            }
        } else {
            object.prototype = vm.data_view_prototype;
        }
    }

    if buffer_obj.is_detached {
        throw_exception(vm, "TypeError: Cannot construct DataView with detached ArrayBuffer");
        return .{};
    }

    current_buffer_length := buffer_obj.primitive_value.s.count;
    if byte_offset > current_buffer_length {
        throw_exception(vm, "RangeError: DataView byteOffset out of bounds");
        return .{};
    }

    if has_byte_length {
        if byte_offset + byte_length > current_buffer_length {
            throw_exception(vm, "RangeError: DataView length exceeds ArrayBuffer length");
            return .{};
        }
    }

    object.kind = .DATA_VIEW;
    object.viewed_array_buffer = buffer_obj;

    array_add(*object.elements, arguments[0]);
    array_add(*object.elements, .{ type = .NUMBER, number = cast(float64) byte_offset });
    if has_byte_length {
        array_add(*object.elements, .{ type = .NUMBER, number = cast(float64) byte_length });
    } else {
        array_add(*object.elements, .{ type = .UNDEFINED });
    }

    return .{ type = .OBJECT, object = object };
}

data_view_buffer_getter :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .OBJECT || this.object.kind != .DATA_VIEW {
        throw_exception(vm, "TypeError: get buffer called on incompatible receiver");
        return .{};
    }

    if this.object.elements.count > 0 {
        return this.object.elements[0];
    }
    if this.object.viewed_array_buffer {
        return .{ type = .OBJECT, object = this.object.viewed_array_buffer };
    }
    return .{ type = .UNDEFINED };
}

data_view_byte_length_getter :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .OBJECT || this.object.kind != .DATA_VIEW {
        throw_exception(vm, "TypeError: get byteLength called on incompatible receiver");
        return .{};
    }

    buffer_obj := this.object.viewed_array_buffer;
    if !buffer_obj && this.object.elements.count > 0 && this.object.elements[0].type == .OBJECT {
        buffer_obj = this.object.elements[0].object;
    }
    if buffer_obj && buffer_obj.is_detached return .{ type = .NUMBER, number = 0 };

    if this.object.elements.count >= 3 {
        byte_offset := 0;
        if this.object.elements.count >= 2 && this.object.elements[1].type == .NUMBER {
            byte_offset = cast(int) this.object.elements[1].number;
        }

        buffer_len := ifx buffer_obj then buffer_obj.primitive_value.s.count else 0;

        if this.object.elements[2].type == .UNDEFINED {
            if byte_offset > buffer_len return .{ type = .NUMBER, number = 0 };
            return .{ type = .NUMBER, number = cast(float64) (buffer_len - byte_offset) };
        } else if this.object.elements[2].type == .NUMBER {
            byte_len := cast(int) this.object.elements[2].number;
            if byte_offset + byte_len > buffer_len return .{ type = .NUMBER, number = 0 };
            return .{ type = .NUMBER, number = cast(float64) byte_len };
        }
    }
    return .{ type = .NUMBER, number = 0 };
}

data_view_byte_offset_getter :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .OBJECT || this.object.kind != .DATA_VIEW {
        throw_exception(vm, "TypeError: get byteOffset called on incompatible receiver");
        return .{};
    }

    buffer_obj := this.object.viewed_array_buffer;
    if !buffer_obj && this.object.elements.count > 0 && this.object.elements[0].type == .OBJECT {
        buffer_obj = this.object.elements[0].object;
    }
    if buffer_obj && buffer_obj.is_detached return .{ type = .NUMBER, number = 0 };

    if this.object.elements.count >= 2 && this.object.elements[1].type == .NUMBER {
        byte_offset := cast(int) this.object.elements[1].number;
        buffer_len := ifx buffer_obj then buffer_obj.primitive_value.s.count else 0;

        if this.object.elements.count >= 3 && this.object.elements[2].type == .NUMBER {
            byte_len := cast(int) this.object.elements[2].number;
            if byte_offset + byte_len > buffer_len return .{ type = .NUMBER, number = 0 };
        } else {
            if byte_offset > buffer_len return .{ type = .NUMBER, number = 0 };
        }

        return .{ type = .NUMBER, number = cast(float64) byte_offset };
    }
    return .{ type = .NUMBER, number = 0 };
}

data_view_get_uint8 :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .OBJECT || this.object.kind != .DATA_VIEW {
        throw_exception(vm, "TypeError: Method DataView.prototype.getUint8 called on incompatible receiver");
        return .{};
    }

    if this.object.elements.count < 3 return .{ type = .UNDEFINED };

    buffer_val := this.object.elements[0];
    if buffer_val.type != .OBJECT || (buffer_val.object.kind != .ARRAY_BUFFER && buffer_val.object.kind != .SHARED_ARRAY_BUFFER) return .{ type = .UNDEFINED };

    buffer_obj := buffer_val.object;
    if buffer_obj.is_detached {
        throw_exception(vm, "TypeError: ArrayBuffer is detached");
        return .{};
    }

    byte_offset := cast(int) this.object.elements[1].number;
    buffer_len := buffer_obj.primitive_value.s.count;

    byte_length := 0;
    if this.object.elements[2].type == .UNDEFINED {
        if byte_offset > buffer_len {
            throw_exception(vm, "RangeError: Offset out of bounds");
            return .{};
        }
        byte_length = buffer_len - byte_offset;
    } else {
        byte_length = cast(int) this.object.elements[2].number;
        if byte_offset + byte_length > buffer_len {
            throw_exception(vm, "RangeError: View out of bounds");
            return .{};
        }
    }

    index := 0;
    if arguments.count > 0 {
        index_f := value_to_number(arguments[0]);
        if isnan(index_f) || isinf(index_f) || index_f < 0 {
            throw_exception(vm, "RangeError: Invalid index");
            return .{};
        }
        index = cast(int) index_f;
    }

    if index >= byte_length {
        throw_exception(vm, "RangeError: Index out of bounds");
        return .{};
    }

    data_ptr := buffer_obj.primitive_value.s.data;
    if !data_ptr return .{ type = .NUMBER, number = 0 };

    value := data_ptr[byte_offset + index];

    return .{ type = .NUMBER, number = cast(float64) value };
}
