init_vm_symbol :: (vm: *Vm) {
    found, symbol_index := get_global_index(vm, "Symbol");

    if !vm.symbol_prototype {
        vm.symbol_prototype           = allocate_object(vm);
        vm.symbol_prototype.prototype = vm.object_prototype;

        add_instance_method(vm, vm.symbol_prototype, "toString", symbol_to_string);
        add_instance_method(vm, vm.symbol_prototype, "valueOf",  symbol_value_of);
    }

    if found {
        vm.current_realm.globals[symbol_index].type            = .NATIVE_FUNCTION;
        vm.current_realm.globals[symbol_index].native_function = symbol_constructor;

        symbol_object := allocate_object(vm);

        vm.current_realm.globals[symbol_index].object = symbol_object;

        symbol_object.prototype = vm.symbol_prototype;

        prototype_value := Value.{
            type   = .OBJECT,
            object = vm.symbol_prototype,
        };

        add_static_property(vm, symbol_object,       "prototype",   prototype_value);
        add_static_property(vm, vm.symbol_prototype, "constructor", vm.current_realm.globals[symbol_index]);
    }
}

symbol_constructor :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if is_new {
        throw_exception(vm, "Symbol is not a constructor");
        return .{};
    }

    description_value: Value = .{ type = .UNDEFINED };
    if arguments.count > 0 && arguments[0].type != .UNDEFINED {
        description_value = .{ type = .STRING, s = value_to_string(vm, arguments[0]) };
    }

    object                 := allocate_object(vm);
    object.kind             = .SYMBOL;
    object.primitive_value  = description_value;
    object.prototype        = vm.symbol_prototype;

    return .{ type = .SYMBOL, symbol_object = object };
}

symbol_to_string :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .SYMBOL {
        if this.symbol_object.primitive_value.type == .STRING {
            return .{ type = .STRING, s = tprint("Symbol(%)", this.symbol_object.primitive_value.s) };
        } else {
            return .{ type = .STRING, s = "Symbol()" };
        }
    } else if this.type == .OBJECT && this.object.kind == .SYMBOL {
        if this.object.primitive_value.type == .STRING {
            return .{ type = .STRING, s = tprint("Symbol(%)", this.object.primitive_value.s) };
        } else {
            return .{ type = .STRING, s = "Symbol()" };
        }
    }

    throw_exception(vm, "Symbol.prototype.toString requires that 'this' be a Symbol");
    return .{};
}

symbol_value_of :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .SYMBOL return this;
    if this.type == .OBJECT && this.object.kind == .SYMBOL {
        return .{ type = .SYMBOL, symbol_object = this.object };
    }

    throw_exception(vm, "Symbol.prototype.valueOf requires that 'this' be a Symbol");
    return .{};
}
