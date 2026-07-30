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
            s := trim(prim.s);
            if s.count == 0 return .{ type = .BIGINT, bigint_val = 0 };
            val, success := string_to_int(s);
            if !success {
                throw_exception(vm, "SyntaxError: Cannot convert string to BigInt");
                return .{};
            }
            return .{ type = .BIGINT, bigint_val = cast(s64) val };

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
