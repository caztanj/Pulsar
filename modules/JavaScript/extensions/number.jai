init_vm_number :: (vm: *Vm) {
    found, index := get_global_index(vm, "Number");

    if !vm.number_prototype {
        vm.number_prototype = allocate_object(vm);
        vm.number_prototype.prototype = vm.object_prototype;

        add_instance_method(vm, vm.number_prototype, "toString", number_to_string);
        add_instance_method(vm, vm.number_prototype, "valueOf",  number_value_of);
        add_instance_method(vm, vm.number_prototype, "toFixed",  number_to_fixed);
    }

    if found {
        vm.current_realm.globals[index].type            = .NATIVE_FUNCTION;
        vm.current_realm.globals[index].native_function = number_constructor;

        number_object := allocate_object(vm);
        vm.current_realm.globals[index].object = number_object;

        add_static_property(vm, number_object, "EPSILON",           .{ type = .NUMBER, number = 2.220446049250313e-16   });
        add_static_property(vm, number_object, "MAX_SAFE_INTEGER",  .{ type = .NUMBER, number = 9007199254740991.0      });
        add_static_property(vm, number_object, "MAX_VALUE",         .{ type = .NUMBER, number = 1.7976931348623157e+308 });
        add_static_property(vm, number_object, "MIN_SAFE_INTEGER",  .{ type = .NUMBER, number = -9007199254740991.0     });
        add_static_property(vm, number_object, "MIN_VALUE",         .{ type = .NUMBER, number = 4.9406564584124654e-324 });
        add_static_property(vm, number_object, "NaN",               .{ type = .NUMBER, number = not_a_number_value      });
        add_static_property(vm, number_object, "NEGATIVE_INFINITY", .{ type = .NUMBER, number = negative_infinity_value });
        add_static_property(vm, number_object, "POSITIVE_INFINITY", .{ type = .NUMBER, number = positive_infinity_value });

        add_static_method(vm, number_object, "isFinite",      number_is_finite);
        add_static_method(vm, number_object, "isInteger",     number_is_integer);
        add_static_method(vm, number_object, "isNaN",         number_is_nan_static);
        add_static_method(vm, number_object, "isSafeInteger", number_is_safe_integer);
        add_static_method(vm, number_object, "parseFloat",    number_parse_float);
        add_static_method(vm, number_object, "parseInt",      number_parse_int);

        prototype_value := Value.{
            type   = .OBJECT,
            object = vm.number_prototype,
        };

        add_static_property(vm, number_object, "prototype", prototype_value);
    }

    found_infinity, infinity_index := get_global_index(vm, "Infinity");
    if found_infinity {
        vm.current_realm.globals[infinity_index].type   = .NUMBER;
        vm.current_realm.globals[infinity_index].number = 1.0 / zero_value_for_division;
    }

    found_nan, nan_index := get_global_index(vm, "NaN");
    if found_nan {
        vm.current_realm.globals[nan_index].type = .NUMBER;
        vm.current_realm.globals[nan_index].number = not_a_number_value;
    }
}

number_constructor :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    number_value: float64 = 0.0;

    if arguments.count > 0 number_value = value_to_number(arguments[0]);

    if is_new {
        number_object := allocate_object(vm);

        number_object.primitive_value = .{ type = .NUMBER, number = number_value };
        number_object.prototype       = vm.number_prototype;

        return .{ type = .OBJECT, object = number_object };
    }

    return .{ type = .NUMBER, number = number_value };
}

number_is_finite :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .BOOLEAN, boolean = false };

    value := arguments[0];

    if value.type != .NUMBER return .{ type = .BOOLEAN, boolean = false };

    is_finite := value.number != positive_infinity_value && value.number != negative_infinity_value && value.number == value.number;

    return .{ type = .BOOLEAN, boolean = is_finite };
}

number_is_integer :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .BOOLEAN, boolean = false };

    value := arguments[0];

    if value.type != .NUMBER return .{ type = .BOOLEAN, boolean = false };

    number := value.number;
    if number != number return .{ type = .BOOLEAN, boolean = false };

    zero_value_for_division := 0.0;
    if number == 1.0 / zero_value_for_division || number == -1.0 / zero_value_for_division return .{ type = .BOOLEAN, boolean = false };

    is_integer := floor(number) == number;

    return .{ type = .BOOLEAN, boolean = is_integer };
}

number_is_nan_static :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .BOOLEAN, boolean = false };

    value := arguments[0];

    if value.type != .NUMBER return .{ type = .BOOLEAN, boolean = false };

    u := (cast(*u64) *value.number).*;

    is_nan_value := (u & 0x7FF0000000000000) == 0x7FF0000000000000 && (u & 0x000FFFFFFFFFFFFF) != 0;

    return .{ type = .BOOLEAN, boolean = is_nan_value };
}

number_is_safe_integer :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .BOOLEAN, boolean = false };

    value := arguments[0];

    if value.type != .NUMBER return .{ type = .BOOLEAN, boolean = false };

    number := value.number;
    if number != number return .{ type = .BOOLEAN, boolean = false };

    is_safe := floor(number) == number && abs(number) <= 9007199254740991.0;

    return .{ type = .BOOLEAN, boolean = is_safe };
}

number_parse_float :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .NUMBER, number = not_a_number_value };

    input_string := value_to_string(vm, arguments[0]);

    return .{ type = .NUMBER, number = string_to_float64(input_string) };
}

number_parse_int :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .NUMBER, number = not_a_number_value };

    input_string := value_to_string(vm, arguments[0]);

    radix := 10;
    if arguments.count > 1 {
        radix_number := value_to_number(arguments[1]);
        radix = cast(int) radix_number;
    }

    parsed_value: float64 = 0.0;

    if radix == 10 {
        parsed_value = cast(float64) string_to_int(input_string);
    } else {
        parsed_value = cast(float64) string_to_int(input_string, base = cast(u32) radix);
    }

    return .{ type = .NUMBER, number = parsed_value };
}

number_to_string :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    number_value: float64 = 0.0;

    if this.type == .NUMBER {
        number_value = this.number;
    } else if this.type == .OBJECT && this.object.kind == .PLAIN && this.object.primitive_value.type == .NUMBER {
        number_value = this.object.primitive_value.number;
    }

    radix := 10;
    if arguments.count > 0 {
        radix_value := value_to_number(arguments[0]);
        radix = cast(int) radix_value;
    }

    result_string := "";
    if radix == 10 {
        result_string = sprint("%", number_value);
    } else {
        result_string = sprint("%", formatInt(cast(s64) number_value, base = cast(u32) radix));
    }

    array_add(*vm.allocated_strings, result_string);

    return .{ type = .STRING, s = result_string };
}

number_value_of :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .NUMBER return this;

    if this.type == .OBJECT && (this.object.kind == .PLAIN || this.object.kind == .NUMBER_WRAPPER) && this.object.primitive_value.type == .NUMBER {
        return this.object.primitive_value;
    }

    return this;
}

number_to_fixed :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    number_value: float64 = 0.0;

    if this.type == .NUMBER {
        number_value = this.number;
    } else if this.type == .OBJECT && this.object.primitive_value.type == .NUMBER {
        number_value = this.object.primitive_value.number;
    }

    fraction_digits := 0;
    if arguments.count > 0 {
        fraction_digits_value := value_to_number(arguments[0]);
        fraction_digits = cast(int) fraction_digits_value;
    }

    result_string := sprint("%", formatFloat(number_value, width = 0, trailing_width = cast(s32) fraction_digits, zero_removal = .NO));

    array_add(*vm.allocated_strings, result_string);

    return .{ type = .STRING, s = result_string };
}