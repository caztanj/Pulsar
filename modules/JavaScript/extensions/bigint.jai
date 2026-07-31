bigint_this_value :: (vm: *Vm, this: Value) -> Value, bool {
    if this.type == .BIGINT return this, true;
    if this.type == .OBJECT && this.object && this.object.kind == .BIGINT_WRAPPER {
        if this.object.primitive_value.type == .BIGINT {
            return this.object.primitive_value, true;
        }
    }
    throw_exception(vm, "TypeError: BigInt.prototype method called on incompatible receiver");
    return .{}, false;
}

format_bigint_radix :: (vm: *Vm, n: s64, radix: int) -> string {
    if n == 0 return "0";
    digits := "0123456789abcdefghijklmnopqrstuvwxyz";
    is_neg := n < 0;
    un: u64 = cast(u64) (ifx is_neg then -n else n);
    buf: [65] u8;
    idx := 65;
    u_radix := cast(u64) radix;
    while un > 0 {
        rem := un % u_radix;
        un /= u_radix;
        idx -= 1;
        buf[idx] = digits[rem];
    }
    if is_neg {
        idx -= 1;
        buf[idx] = #char "-";
    }
    str: string;
    str.data = buf.data + idx;
    str.count = 65 - idx;
    return allocate_string(vm, str);
}

bigint_to_string :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    val, ok := bigint_this_value(vm, this);
    if !ok return .{};

    radix := 10;
    if arguments.count > 0 && arguments[0].type != .UNDEFINED {
        radix_num := abstract_to_number(vm, arguments[0]);
        if vm.has_exception return .{};
        radix = cast(int) radix_num;
        if radix < 2 || radix > 36 {
            throw_exception(vm, "RangeError: toString() radix argument must be between 2 and 36");
            return .{};
        }
    }

    res := format_bigint_radix(vm, val.bigint_val, radix);
    return .{ type = .STRING, s = res };
}

bigint_value_of :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    val, ok := bigint_this_value(vm, this);
    if !ok return .{};
    return val;
}

parse_string_to_bigint :: (s_input: string) -> s64, bool {
    s := trim(s_input);
    if s.count == 0 return 0, true;

    if s.count >= 2 && s[0] == #char "0" {
        c := s[1];
        if c == #char "b" || c == #char "B" {
            digits := s;
            digits.data  += 2;
            digits.count -= 2;
            if digits.count == 0 return 0, false;
            result: u64 = 0;
            for i: 0..digits.count-1 {
                ch := digits[i];
                if ch < #char "0" || ch > #char "1" return 0, false;
                result = result * 2 + (cast(u64) (ch - #char "0"));
            }
            return cast,no_check(s64) result, true;
        } else if c == #char "o" || c == #char "O" {
            digits := s;
            digits.data  += 2;
            digits.count -= 2;
            if digits.count == 0 return 0, false;
            result: u64 = 0;
            for i: 0..digits.count-1 {
                ch := digits[i];
                if ch < #char "0" || ch > #char "7" return 0, false;
                result = result * 8 + (cast(u64) (ch - #char "0"));
            }
            return cast,no_check(s64) result, true;
        } else if c == #char "x" || c == #char "X" {
            digits := s;
            digits.data  += 2;
            digits.count -= 2;
            if digits.count == 0 return 0, false;
            result: u64 = 0;
            for i: 0..digits.count-1 {
                ch := digits[i];
                digit: u64 = 255;
                if ch >= #char "0" && ch <= #char "9" digit = cast(u64) (ch - #char "0");
                else if ch >= #char "a" && ch <= #char "f" digit = cast(u64) (10 + ch - #char "a");
                else if ch >= #char "A" && ch <= #char "F" digit = cast(u64) (10 + ch - #char "A");
                if digit >= 16 return 0, false;
                result = result * 16 + digit;
            }
            return cast,no_check(s64) result, true;
        }
    }

    digits := s;
    sign: s64 = 1;
    if digits[0] == #char "+" {
        digits.data  += 1;
        digits.count -= 1;
    } else if digits[0] == #char "-" {
        sign          = -1;
        digits.data  += 1;
        digits.count -= 1;
    }

    if digits.count == 0 return 0, false;

    result: u64 = 0;
    for i: 0..digits.count-1 {
        ch := digits[i];
        if ch < #char "0" || ch > #char "9" return 0, false;
        result = result * 10 + (cast(u64) (ch - #char "0"));
    }

    final_val := (cast,no_check(s64) result) * sign;
    return final_val, true;
}

bigint_constructor :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if is_new {
        throw_exception(vm, "TypeError: BigInt is not a constructor");
        return .{};
    }
    if arguments.count == 0 return .{ type = .BIGINT, bigint_val = 0 };

    prim := to_primitive(vm, arguments[0], .NUMBER);
    if vm.has_exception return .{};

    if prim.type == {
        case .NUMBER;
            if isnan(prim.number) || isinf(prim.number) || (cast(float64) (cast(s64) prim.number) != prim.number) {
                throw_exception(vm, "RangeError: The number cannot be converted to a BigInt because it is not an integer");
                return .{};
            }
            return .{ type = .BIGINT, bigint_val = cast(s64) prim.number };

        case .BOOLEAN;
            return .{ type = .BIGINT, bigint_val = ifx prim.boolean then 1 else 0 };

        case .BIGINT;
            return prim;

        case .STRING;
            val, success := parse_string_to_bigint(prim.s);
            if !success {
                throw_exception(vm, "SyntaxError: Cannot convert string to BigInt");
                return .{};
            }
            return .{ type = .BIGINT, bigint_val = val };

        case .SYMBOL;
            throw_exception(vm, "TypeError: Cannot convert a Symbol value to a BigInt");
            return .{};

        case .UNDEFINED;
            throw_exception(vm, "TypeError: Cannot convert undefined to a BigInt");
            return .{};

        case .NULL;
            throw_exception(vm, "TypeError: Cannot convert null to a BigInt");
            return .{};
    }

    return .{ type = .BIGINT, bigint_val = 0 };
}

init_vm_bigint :: (vm: *Vm) {
    found, index := get_global_index(vm, "BigInt");

    if !vm.bigint_prototype {
        vm.bigint_prototype           = allocate_object(vm);
        vm.bigint_prototype.prototype = vm.object_prototype;

        add_instance_method(vm, vm.bigint_prototype, "toString", bigint_to_string);
        add_instance_method(vm, vm.bigint_prototype, "valueOf",  bigint_value_of);
        set_object_property(vm, vm.bigint_prototype, "@@Symbol.toStringTag", Value.{ type = .STRING, s = "BigInt" });
    }

    if found {
        bigint_obj := allocate_object(vm);
        bigint_obj.prototype = vm.function_prototype;
        set_object_property(vm, bigint_obj, "name", .{ type = .STRING, s = "BigInt" });
        set_object_property(vm, bigint_obj, "length", .{ type = .NUMBER, number = 1 });

        bigint_val := Value.{
            type = .NATIVE_FUNCTION,
            native_function = bigint_constructor,
            object = bigint_obj,
        };

        vm.current_realm.globals[index] = bigint_val;

        prototype_value := Value.{
            type   = .OBJECT,
            object = vm.bigint_prototype,
        };

        add_static_property(vm, bigint_obj, "prototype", prototype_value);
        add_static_property(vm, vm.bigint_prototype, "constructor", bigint_val);
    }
}
