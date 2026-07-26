init_vm_data_view :: (vm: *Vm) {
    found, index := get_global_index(vm, "DataView");

    if !vm.data_view_prototype {
        vm.data_view_prototype = allocate_object(vm);
        vm.data_view_prototype.prototype = vm.object_prototype;
        add_instance_method(vm, vm.data_view_prototype, "getUint8", data_view_get_uint8);
    }

    if found {
        vm.current_realm.globals[index].type            = .NATIVE_FUNCTION;
        vm.current_realm.globals[index].native_function = data_view_constructor;

        data_view_object := allocate_object(vm);
        vm.current_realm.globals[index].object = data_view_object;
        data_view_object.prototype = vm.data_view_prototype;

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

    if arguments.count < 1 || arguments[0].type != .OBJECT || arguments[0].object.kind != .ARRAY_BUFFER {
        throw_exception(vm, "TypeError: DataView constructor requires an ArrayBuffer");
        return .{};
    }

    buffer_obj := arguments[0].object;
    buffer_length := buffer_obj.primitive_value.s.count;

    byte_offset := 0;
    byte_length := buffer_length;

    if arguments.count > 1 && arguments[1].type != .UNDEFINED {
        byte_offset_f := value_to_number(arguments[1]);
        if isnan(byte_offset_f) || isinf(byte_offset_f) || byte_offset_f < 0 {
            throw_exception(vm, "RangeError: Invalid DataView byteOffset");
            return .{};
        }
        byte_offset = cast(int) byte_offset_f;
    }

    if arguments.count > 2 && arguments[2].type != .UNDEFINED {
        byte_length_f := value_to_number(arguments[2]);
        if isnan(byte_length_f) || isinf(byte_length_f) || byte_length_f < 0 {
            throw_exception(vm, "RangeError: Invalid DataView byteLength");
            return .{};
        }
        byte_length = cast(int) byte_length_f;
    } else {
        byte_length = buffer_length - byte_offset;
    }

    if byte_offset + byte_length > buffer_length {
        throw_exception(vm, "RangeError: DataView length exceeds ArrayBuffer length");
        return .{};
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
    object.kind = .DATA_VIEW;

    array_add(*object.elements, arguments[0]);
    array_add(*object.elements, .{ type = .NUMBER, number = cast(float64) byte_offset });
    array_add(*object.elements, .{ type = .NUMBER, number = cast(float64) byte_length });

    return .{ type = .OBJECT, object = object };
}

data_view_get_uint8 :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .OBJECT || this.object.kind != .DATA_VIEW {
        throw_exception(vm, "TypeError: Method DataView.prototype.getUint8 called on incompatible receiver");
        return .{};
    }

    if this.object.elements.count < 3 return .{ type = .UNDEFINED };

    buffer_val := this.object.elements[0];
    if buffer_val.type != .OBJECT || buffer_val.object.kind != .ARRAY_BUFFER return .{ type = .UNDEFINED };

    byte_offset := cast(int) this.object.elements[1].number;
    byte_length := cast(int) this.object.elements[2].number;

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

    buffer_obj := buffer_val.object;
    data_ptr := buffer_obj.primitive_value.s.data;
    if !data_ptr return .{ type = .NUMBER, number = 0 };

    value := data_ptr[byte_offset + index];

    return .{ type = .NUMBER, number = cast(float64) value };
}
