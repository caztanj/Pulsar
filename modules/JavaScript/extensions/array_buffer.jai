init_vm_array_buffer :: (vm: *Vm) {
    found, index := get_global_index(vm, "ArrayBuffer");

    if !vm.array_buffer_prototype {
        vm.array_buffer_prototype = allocate_object(vm);
        vm.array_buffer_prototype.prototype = vm.object_prototype;
        add_instance_method(vm, vm.array_buffer_prototype, "byteLength__getter__", array_buffer_byte_length_getter);
        add_instance_method(vm, vm.array_buffer_prototype, "resizable__getter__",  array_buffer_resizable_getter);
    }

    if found {
        vm.current_realm.globals[index].type            = .NATIVE_FUNCTION;
        vm.current_realm.globals[index].native_function = array_buffer_constructor;

        array_buffer_object := allocate_object(vm);
        vm.current_realm.globals[index].object = array_buffer_object;
        array_buffer_object.prototype = vm.function_prototype;

        set_object_property(vm, array_buffer_object, "name",   Value.{ type = .STRING, s = "ArrayBuffer" });
        set_object_property(vm, array_buffer_object, "length", Value.{ type = .NUMBER, number = 1 });

        prototype_value := Value.{
            type   = .OBJECT,
            object = vm.array_buffer_prototype,
        };

        add_static_property(vm, array_buffer_object,    "prototype",   prototype_value);
        add_static_property(vm, vm.array_buffer_prototype, "constructor", vm.current_realm.globals[index]);
    }
}

array_buffer_constructor :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if !is_new {
        throw_exception(vm, "TypeError: Constructor ArrayBuffer requires 'new'");
        return .{};
    }

    length := 0;
    if arguments.count > 0 {
        arg := arguments[0];
        length_f := abstract_to_number(vm, arg);
        if vm.has_exception return .{};

        if isnan(length_f) {
            length_f = 0;
        } else if !isinf(length_f) {
            length_f = cast(float64) cast(s64) length_f;
        }

        if length_f < 0 || isinf(length_f) || length_f > 9007199254740991 {
            throw_exception(vm, "RangeError: Invalid ArrayBuffer length");
            return .{};
        }
        length = cast(int) length_f;
    }

    max_length := -1;
    if arguments.count > 1 && arguments[1].type == .OBJECT && arguments[1].object {
        found_max, max_val := lookup_property(vm, arguments[1].object, "maxByteLength");
        if vm.has_exception return .{};

        if found_max && max_val.type != .UNDEFINED {
            max_len_f := abstract_to_number(vm, max_val);
            if vm.has_exception return .{};

            if isnan(max_len_f) {
                max_len_f = 0;
            } else if !isinf(max_len_f) {
                max_len_f = cast(float64) cast(s64) max_len_f;
            }

            if max_len_f < 0 || isinf(max_len_f) || max_len_f > 9007199254740991 {
                throw_exception(vm, "RangeError: Invalid maxByteLength");
                return .{};
            }
            if max_len_f > 2147483647 {
                throw_exception(vm, "RangeError: ArrayBuffer maxByteLength allocation limit exceeded");
                return .{};
            }
            max_length = cast(int) max_len_f;
        }
    }

    if max_length >= 0 && length > max_length {
        throw_exception(vm, "RangeError: ArrayBuffer length is larger than maxByteLength");
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
                object.prototype = vm.array_buffer_prototype;
            }
        } else {
            object.prototype = vm.array_buffer_prototype;
        }
    }
    object.kind = .ARRAY_BUFFER;

    if length > 2147483647 {
        throw_exception(vm, "RangeError: ArrayBuffer allocation limit exceeded");
        return .{};
    }

    data_ptr := alloc(length);
    memset(data_ptr, 0, length);

    s: string;
    s.data = data_ptr;
    s.count = length;

    object.primitive_value = .{ type = .STRING, s = s };

    if max_length >= 0 {
        array_add(*object.elements, .{ type = .NUMBER, number = cast(float64) max_length });
    }

    return .{ type = .OBJECT, object = object };
}

array_buffer_byte_length_getter :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .OBJECT || this.object.kind != .ARRAY_BUFFER {
        throw_exception(vm, "TypeError: get byteLength called on incompatible receiver");
        return .{};
    }

    return .{ type = .NUMBER, number = cast(float64) this.object.primitive_value.s.count };
}

array_buffer_resizable_getter :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .OBJECT || this.object.kind != .ARRAY_BUFFER {
        throw_exception(vm, "TypeError: get resizable called on incompatible receiver");
        return .{};
    }

    is_resizable := this.object.elements.count > 0;
    return .{ type = .BOOLEAN, boolean = is_resizable };
}
