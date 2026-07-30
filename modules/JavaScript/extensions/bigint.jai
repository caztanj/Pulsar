to_primitive_helper :: (vm: *Vm, value: Value, hint: enum { NUMBER; STRING; }) -> Value {
    if value.type != .OBJECT && value.type != .ARRAY && value.type != .FUNCTION && value.type != .NATIVE_FUNCTION && value.type != .GENERATOR && value.type != .SYMBOL return value;

    current_obj := ifx value.type == .GENERATOR value.generator_object else value.object;
    if !current_obj return value;

    found_to_prim, to_prim_fn := lookup_property(vm, current_obj, "@@Symbol.toPrimitive");
    if vm.has_exception return .{};
    if found_to_prim && (to_prim_fn.type == .FUNCTION || to_prim_fn.type == .NATIVE_FUNCTION || (to_prim_fn.type == .OBJECT && to_prim_fn.object.kind == .PROXY)) {
        hint_val := Value.{ type = .STRING, s = ifx hint == .NUMBER "number" else "string" };
        res := call_value(vm, value, to_prim_fn, .[ hint_val ]);
        if vm.has_exception return .{};
        if res.type != .OBJECT && res.type != .ARRAY && res.type != .GENERATOR && res.type != .FUNCTION && res.type != .NATIVE_FUNCTION {
            return res;
        }
        throw_exception(vm, "TypeError: Cannot convert object to primitive value");
        return .{};
    }

    first_method  := ifx hint == .NUMBER then "valueOf" else "toString";
    second_method := ifx hint == .NUMBER then "toString" else "valueOf";

    found1, val1 := lookup_property(vm, current_obj, first_method);
    if vm.has_exception return .{};
    if found1 && (val1.type == .FUNCTION || val1.type == .NATIVE_FUNCTION) {
        res := call_value(vm, value, val1, .[]);
        if vm.has_exception return .{};
        if res.type != .OBJECT && res.type != .ARRAY && res.type != .GENERATOR && res.type != .FUNCTION && res.type != .NATIVE_FUNCTION {
            return res;
        }
    }

    found2, val2 := lookup_property(vm, current_obj, second_method);
    if vm.has_exception return .{};
    if found2 && (val2.type == .FUNCTION || val2.type == .NATIVE_FUNCTION) {
        res := call_value(vm, value, val2, .[]);
        if vm.has_exception return .{};
        if res.type != .OBJECT && res.type != .ARRAY && res.type != .GENERATOR && res.type != .FUNCTION && res.type != .NATIVE_FUNCTION {
            return res;
        }
    }

    throw_exception(vm, "TypeError: Cannot convert object to primitive value");
    return .{};
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

    prim := to_primitive_helper(vm, arguments[0], .NUMBER);
    if vm.has_exception return .{};

    if prim.type == {
        case .NUMBER;
            if isnan(prim.number) || isinf(prim.number) {
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
    }
}
