init_vm_math :: (vm: *Vm) {
    found, index := get_global_index(vm, "Math");

    if found {
        math_object := allocate_object(vm);

        vm.current_realm.globals[index].type   = .OBJECT;
        vm.current_realm.globals[index].object = math_object;

        add_static_method(vm, math_object, "min",    math_min);
        add_static_method(vm, math_object, "max",    math_max);
        add_static_method(vm, math_object, "sqrt",   math_sqrt);
        add_static_method(vm, math_object, "abs",    math_abs);
        add_static_method(vm, math_object, "floor",  math_floor);
        add_static_method(vm, math_object, "ceil",   math_ceil);
        add_static_method(vm, math_object, "round",  math_round);
        add_static_method(vm, math_object, "random", math_random);
        add_static_method(vm, math_object, "trunc",  math_trunc);
        add_static_method(vm, math_object, "sign",   math_sign);
        add_static_method(vm, math_object, "cbrt",   math_cbrt);
        add_static_method(vm, math_object, "pow",    math_pow);
        add_static_method(vm, math_object, "exp",    math_exp);
        add_static_method(vm, math_object, "log",    math_log);
        add_static_method(vm, math_object, "sin",    math_sin);
        add_static_method(vm, math_object, "cos",    math_cos);
        add_static_method(vm, math_object, "tan",    math_tan);
        add_static_method(vm, math_object, "hypot",  math_hypot);
        add_static_method(vm, math_object, "log10",  math_log10);
        add_static_method(vm, math_object, "asin",   math_asin);
        add_static_method(vm, math_object, "acos",   math_acos);
        add_static_method(vm, math_object, "atan",   math_atan);
        add_static_method(vm, math_object, "atan2",  math_atan2);
        add_static_method(vm, math_object, "log2",   math_log2);

        add_static_property(vm, math_object, "PI", .{ type = .NUMBER, number = 3.141592653589793 });
        add_static_property(vm, math_object, "E",  .{ type = .NUMBER, number = 2.718281828459045 });
    }
}

math_min :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    minimum := minimum_value;

    for arguments {
        value := value_to_number(it);

        if value != value return .{ type = .NUMBER, number = not_a_number_value };

        if value < minimum {
            minimum = value;
        } else if value == 0.0 && minimum == 0.0 {
            if (cast(*u64) *value).* == 0x8000000000000000 {
                minimum = value;
            }
        }
    }

    return .{ type = .NUMBER, number = minimum };
}

math_max :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    maximum := maximum_value;

    for arguments {
        value := value_to_number(it);

        if value != value return .{ type = .NUMBER, number = not_a_number_value };

        if value > maximum {
            maximum = value;
        } else if value == 0.0 && maximum == 0.0 {
            if (cast(*u64) *value).* == 0 {
                maximum = value;
            }
        }
    }

    return .{ type = .NUMBER, number = maximum };
}

math_sqrt :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .NUMBER, number = not_a_number_value };
    return .{ type = .NUMBER, number = sqrt(value_to_number(arguments[0])) };
}

math_abs :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .NUMBER, number = not_a_number_value };
    return .{ type = .NUMBER, number = abs(value_to_number(arguments[0])) };
}

math_floor :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .NUMBER, number = not_a_number_value };
    return .{ type = .NUMBER, number = floor(value_to_number(arguments[0])) };
}

math_ceil :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .NUMBER, number = not_a_number_value };
    return .{ type = .NUMBER, number = ceil(value_to_number(arguments[0])) };
}

math_round :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .NUMBER, number = not_a_number_value };
    return .{ type = .NUMBER, number = floor(value_to_number(arguments[0]) + 0.5) };
}

math_random :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    return .{ type = .NUMBER, number = random_get_zero_to_one_new() };
}

math_trunc :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .NUMBER, number = not_a_number_value };

    value := value_to_number(arguments[0]);

    return .{ type = .NUMBER, number = ifx value >= 0 then floor(value) else ceil(value) };
}

math_sign :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .NUMBER, number = not_a_number_value };

    value := value_to_number(arguments[0]);

    if value > 0 return .{ type = .NUMBER, number = 1.0 };
    if value < 0 return .{ type = .NUMBER, number = -1.0 };

    return .{ type = .NUMBER, number = value };
}

math_cbrt :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .NUMBER, number = not_a_number_value };

    value := value_to_number(arguments[0]);

    if value < 0 return .{ type = .NUMBER, number = -pow(-value, 1.0 / 3.0) };

    return .{ type = .NUMBER, number = pow(value, 1.0 / 3.0) };
}

math_pow :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count < 2 return .{ type = .NUMBER, number = not_a_number_value };
    return .{ type = .NUMBER, number = pow(value_to_number(arguments[0]), value_to_number(arguments[1])) };
}

math_exp :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .NUMBER, number = not_a_number_value };
    return .{ type = .NUMBER, number = exp(value_to_number(arguments[0])) };
}

math_log :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .NUMBER, number = not_a_number_value };
    return .{ type = .NUMBER, number = log(value_to_number(arguments[0])) };
}

math_sin :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .NUMBER, number = not_a_number_value };
    return .{ type = .NUMBER, number = sin(value_to_number(arguments[0])) };
}

math_cos :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .NUMBER, number = not_a_number_value };
    return .{ type = .NUMBER, number = cos(value_to_number(arguments[0])) };
}

math_tan :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .NUMBER, number = not_a_number_value };
    return .{ type = .NUMBER, number = tan(value_to_number(arguments[0])) };
}

math_hypot :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    sum: float64 = 0.0;

    for arguments {
        value := value_to_number(it);
        sum += value * value;
    }

    return .{ type = .NUMBER, number = sqrt(sum) };
}

math_log10 :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .NUMBER, number = not_a_number_value };
    return .{ type = .NUMBER, number = log(value_to_number(arguments[0])) / log(10.0) };
}

math_asin :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .NUMBER, number = not_a_number_value };
    return .{ type = .NUMBER, number = asin(value_to_number(arguments[0])) };
}

math_acos :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .NUMBER, number = not_a_number_value };
    return .{ type = .NUMBER, number = acos(value_to_number(arguments[0])) };
}

math_atan :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .NUMBER, number = not_a_number_value };
    return .{ type = .NUMBER, number = atan(value_to_number(arguments[0])) };
}

math_atan2 :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count < 2 return .{ type = .NUMBER, number = not_a_number_value };
    return .{ type = .NUMBER, number = atan2(value_to_number(arguments[0]), value_to_number(arguments[1])) };
}

math_log2 :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .NUMBER, number = not_a_number_value };
    return .{ type = .NUMBER, number = log(value_to_number(arguments[0])) / log(2.0) };
}