init_vm_function :: (vm: *Vm) {
    if !vm.function_prototype {
        vm.function_prototype = allocate_object(vm);
        vm.function_prototype.prototype = vm.object_prototype;

        add_instance_method(vm, vm.function_prototype, "call", function_call);
        add_instance_method(vm, vm.function_prototype, "bind", function_bind);

        function_constructor_object := allocate_object(vm);
        function_constructor_object.prototype = vm.function_prototype;

        set_object_property(vm, function_constructor_object, "prototype", Value.{ type = .OBJECT, object = vm.function_prototype });
        set_object_property(vm, vm.function_prototype, "constructor", Value.{ type = .OBJECT, object = function_constructor_object });
        set_object_property(vm, function_constructor_object, "name", Value.{ type = .STRING, s = "Function" });

        found, index := get_global_index(vm, "Function");
        if found {
            vm.current_realm.globals[index].type = .NATIVE_FUNCTION;
            vm.current_realm.globals[index].native_function = function_constructor;
            vm.current_realm.globals[index].object = function_constructor_object;

            set_object_property(vm, vm.function_prototype, "constructor", vm.current_realm.globals[index]);
        }

        vm.async_function_prototype = allocate_object(vm);
        vm.async_function_prototype.prototype = vm.function_prototype;

        async_function_constructor_object := allocate_object(vm);
        async_function_constructor_object.prototype = function_constructor_object;
        vm.async_function_constructor_object = async_function_constructor_object;

        async_func_val := Value.{
            type = .NATIVE_FUNCTION,
            native_function = function_constructor,
            object = async_function_constructor_object,
        };

        set_object_property(vm, async_function_constructor_object, "prototype", Value.{ type = .OBJECT, object = vm.async_function_prototype });
        set_object_property(vm, async_function_constructor_object, "name", Value.{ type = .STRING, s = "AsyncFunction" });
        set_object_property(vm, async_function_constructor_object, "length", Value.{ type = .NUMBER, number = 1 });

        set_object_property(vm, vm.async_function_prototype, "constructor", async_func_val);

        symbol_tag_val := Value.{ type = .STRING, s = "AsyncFunction" };
        set_object_property(vm, vm.async_function_prototype, "@@Symbol.toStringTag", symbol_tag_val);
    }
}

function_constructor :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    dummy := Value.{ type = .NATIVE_FUNCTION, native_function = empty_function };

    if is_new && this.type == .OBJECT {
        dummy.object = this.object;
    } else {
        dummy.object = allocate_object(vm);
    }

    if vm.current_native_callee.type == .NATIVE_FUNCTION && vm.current_native_callee.object {
        dummy.object.realm = vm.current_native_callee.object.realm;

        if !is_new || this.type != .OBJECT {
            found, prototype_value := lookup_property(vm, vm.current_native_callee.object, "prototype");
            if found && (prototype_value.type == .OBJECT || prototype_value.type == .ARRAY) {
                dummy.object.prototype = prototype_value.object;
            } else {
                dummy.object.prototype = vm.function_prototype;
            }
        }
    } else {
        if !is_new || this.type != .OBJECT {
            dummy.object.prototype = vm.function_prototype;
        }
    }

    param_count := 0;
    if arguments.count > 1 {
        for i: 0..arguments.count - 2 {
            s := value_to_string(vm, arguments[i]);
            parts := split(s, ",");
            defer array_free(parts);
            for parts {
                trimmed := trim(it);
                if trimmed.count > 0 param_count += 1;
            }
        }
    }

    set_object_property(vm, dummy.object, "length", Value.{ type = .NUMBER, number = cast(float64) param_count });

    return dummy;
}

empty_function :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    return .{ type = .UNDEFINED };
}

function_call :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .FUNCTION && this.type != .NATIVE_FUNCTION {
        throw_exception(vm, "TypeError: Function.prototype.call called on non-function");
        return .{};
    }

    this_arg := Value.{};
    if arguments.count > 0 this_arg = arguments[0];

    call_args: [] Value;
    if arguments.count > 1 {
        call_args.data = arguments.data + 1;
        call_args.count = arguments.count - 1;
    }

    return call_value(vm, this_arg, this, call_args, false);
}

function_bind :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .FUNCTION && this.type != .NATIVE_FUNCTION {
        throw_exception(vm, "TypeError: Function.prototype.bind called on non-function");
        return .{};
    }

    bound_object := allocate_object(vm);
    bound_object.prototype = vm.function_prototype;

    array_add(*bound_object.fields, this);

    this_arg := Value.{};
    if arguments.count > 0 this_arg = arguments[0];
    array_add(*bound_object.fields, this_arg);

    for i: 1..arguments.count - 1 {
        array_add(*bound_object.fields, arguments[i]);
    }

    result := Value.{
        type = .NATIVE_FUNCTION,
        native_function = bound_function_runner,
        object = bound_object,
    };

    return result;
}

bound_function_runner :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    callee := vm.current_native_callee;

    if !callee.object || callee.object.fields.count < 2 {
        throw_exception(vm, "TypeError: Invalid bound function");
        return .{};
    }

    target_func := callee.object.fields[0];
    bound_this  := callee.object.fields[1];

    final_args: [..] Value;
    for i: 2..callee.object.fields.count - 1 {
        array_add(*final_args, callee.object.fields[i]);
    }
    for arguments {
        array_add(*final_args, it);
    }

    effective_this := ifx is_new then this else bound_this;

    result := call_value(vm, effective_this, target_func, final_args, is_new);

    array_free(final_args);
    return result;
}
