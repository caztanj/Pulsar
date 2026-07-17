init_vm_error :: (vm: *Vm) {
    if !vm.error_prototype {
        vm.error_prototype = allocate_object(vm);
        vm.error_prototype.prototype = vm.object_prototype;

        add_instance_method(vm, vm.error_prototype, "toString", error_to_string);

        name_value := Value.{ type = .STRING, s = "Error" };
        set_object_property(vm, vm.error_prototype, "name", name_value);

        message_value := Value.{ type = .STRING, s = "" };
        set_object_property(vm, vm.error_prototype, "message", message_value);
    }

    error_classes := string.[
        "Error",
        "TypeError",
        "ReferenceError",
        "SyntaxError",
        "RangeError",
        "AggregateError"
    ];

    for error_classes {
        found, index := get_global_index(vm, it);

        if found {
            vm.current_realm.globals[index].type = .NATIVE_FUNCTION;
            if it == "Error"          vm.current_realm.globals[index].native_function = error_constructor_Error;
            if it == "TypeError"      vm.current_realm.globals[index].native_function = error_constructor_TypeError;
            if it == "ReferenceError" vm.current_realm.globals[index].native_function = error_constructor_ReferenceError;
            if it == "SyntaxError"    vm.current_realm.globals[index].native_function = error_constructor_SyntaxError;
            if it == "RangeError"     vm.current_realm.globals[index].native_function = error_constructor_RangeError;
            if it == "AggregateError" vm.current_realm.globals[index].native_function = error_constructor_AggregateError;

            error_constructor_object := allocate_object(vm);
            name_value := Value.{ type = .STRING, s = it };
            set_object_property(vm, error_constructor_object, "name", name_value);

            vm.current_realm.globals[index].object = error_constructor_object;

            specific_error_prototype := vm.error_prototype;

            if it != "Error" {
                specific_error_prototype = allocate_object(vm);
                specific_error_prototype.prototype = vm.error_prototype;

                set_object_property(vm, specific_error_prototype, "name", name_value);
                set_object_property(vm, specific_error_prototype, "message", Value.{ type = .STRING, s = "" });
            }

            error_constructor_object.prototype = vm.object_prototype;

            prototype_value := Value.{
                type   = .OBJECT,
                object = specific_error_prototype,
            };

            add_static_property(vm, error_constructor_object, "prototype",   prototype_value);
            add_static_property(vm, specific_error_prototype, "constructor", vm.current_realm.globals[index]);
        }
    }
}

error_constructor_Error          :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value { return error_constructor(vm, this, arguments, is_new, "Error"); }
error_constructor_TypeError      :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value { return error_constructor(vm, this, arguments, is_new, "TypeError"); }
error_constructor_ReferenceError :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value { return error_constructor(vm, this, arguments, is_new, "ReferenceError"); }
error_constructor_SyntaxError    :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value { return error_constructor(vm, this, arguments, is_new, "SyntaxError"); }
error_constructor_RangeError     :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value { return error_constructor(vm, this, arguments, is_new, "RangeError"); }

error_constructor :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool, name: string) -> Value {
    object := allocate_object(vm);

    found_property, index := get_global_index(vm, name);
    if found_property {
        found_prototype, prototype_value := lookup_property(vm, vm.current_realm.globals[index].object, "prototype");
        if prototype_value.type == .OBJECT object.prototype = prototype_value.object;
        else object.prototype = vm.error_prototype;
    } else {
        object.prototype = vm.error_prototype;
    }

    message := "";
    if arguments.count > 0 {
        message = value_to_string(vm, arguments[0]);
    }

    set_object_property(vm, object, "message", Value.{ type = .STRING, s = message });

    stack_trace := get_stack_trace_string(vm);
    set_object_property(vm, object, "stack", Value.{ type = .STRING, s = stack_trace });

    return .{ type = .OBJECT, object = object };
}

error_to_string :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .OBJECT return .{ type = .STRING, s = "Error" };

    found_name, name_value := lookup_property(vm, this.object, "name");
    found_message, message_value := lookup_property(vm, this.object, "message");

    name := ifx name_value.type == .STRING then name_value.s else "Error";
    message := ifx message_value.type == .STRING then message_value.s else "";

    if message.count > 0 {
        return .{ type = .STRING, s = allocate_string(vm, tprint("%: %", name, message)) };
    }

    return .{ type = .STRING, s = name };
}

error_constructor_AggregateError :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    return aggregate_error_constructor(vm, this, arguments, is_new);
}

aggregate_error_constructor :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    object := allocate_object(vm);

    found_property, index := get_global_index(vm, "AggregateError");
    if found_property {
        found_prototype, prototype_value := lookup_property(vm, vm.current_realm.globals[index].object, "prototype");
        if prototype_value.type == .OBJECT object.prototype = prototype_value.object;
        else object.prototype = vm.error_prototype;
    } else {
        object.prototype = vm.error_prototype;
    }

    errors_arg := Value.{ type = .UNDEFINED };
    if arguments.count > 0 {
        errors_arg = arguments[0];
    }

    list, success := iterable_to_list(vm, errors_arg);
    if !success return .{};

    errors_array := allocate_object(vm);
    errors_array.kind = .ARRAY;
    for list {
        array_add(*errors_array.elements, it);
    }
    set_object_property(vm, object, "errors", .{ type = .ARRAY, object = errors_array });

    message := "";
    if arguments.count > 1 && arguments[1].type != .UNDEFINED {
        message = value_to_string(vm, arguments[1]);
    }
    set_object_property(vm, object, "message", Value.{ type = .STRING, s = message });

    if arguments.count > 2 {
        options := arguments[2];
        if options.type == .OBJECT || options.type == .ARRAY || options.type == .FUNCTION || options.type == .NATIVE_FUNCTION {
            options_obj := options.object;
            if options_obj {
                found_cause, cause_val := lookup_property(vm, options_obj, "cause");
                if vm.has_exception return .{};

                if found_cause {
                    set_object_property(vm, object, "cause", cause_val);
                }
            }
        }
    }

    stack_trace := get_stack_trace_string(vm);
    set_object_property(vm, object, "stack", Value.{ type = .STRING, s = stack_trace });

    return .{ type = .OBJECT, object = object };
}

iterable_to_list :: (vm: *Vm, iterable: Value) -> [..] Value, bool {
    result: [..] Value;

    if iterable.type == .UNDEFINED || iterable.type == .NULL {
        throw_exception(vm, "TypeError: iterable is not an object");
        return result, false;
    }

    object: *Gc_Object;
    if iterable.type == .OBJECT || iterable.type == .ARRAY || iterable.type == .FUNCTION || iterable.type == .NATIVE_FUNCTION || iterable.type == .SYMBOL {
        object = iterable.object;
    } else if iterable.type == .GENERATOR {
        object = iterable.generator_object;
    } else if iterable.type == .STRING {
        object = vm.string_prototype;
    } else if iterable.type == .NUMBER {
        object = vm.number_prototype;
    } else if iterable.type == .BOOLEAN {
        object = vm.boolean_prototype;
    } else {
        throw_exception(vm, "TypeError: iterable is not an object");
        return result, false;
    }

    iterator_symbol_name := "@@Symbol.iterator";
    found_method, method := lookup_property(vm, object, iterator_symbol_name);
    if vm.has_exception return result, false;

    if !found_method || method.type == .UNDEFINED || method.type == .NULL {
        if iterable.type == .ARRAY && object && object.kind == .ARRAY {
            for object.elements {
                array_add(*result, it);
            }
            return result, true;
        }
        if iterable.type == .STRING {
            for i: 0..iterable.s.count - 1 {
                char := slice(iterable.s, i, 1);
                array_add(*result, .{ type = .STRING, s = allocate_string(vm, char) });
            }
            return result, true;
        }
        throw_exception(vm, "TypeError: object is not iterable");
        return result, false;
    }

    iterator := call_value(vm, iterable, method, .[]);
    if vm.has_exception return result, false;

    if iterator.type != .OBJECT {
        throw_exception(vm, "TypeError: iterator is not an object");
        return result, false;
    }

    while true {
        found_next, next_method := lookup_property(vm, iterator.object, "next");
        if vm.has_exception return result, false;

        if !found_next || (next_method.type != .FUNCTION && next_method.type != .NATIVE_FUNCTION) {
            throw_exception(vm, "TypeError: iterator next is not callable");
            return result, false;
        }

        next_result := call_value(vm, iterator, next_method, .[]);
        if vm.has_exception return result, false;

        if next_result.type != .OBJECT {
            throw_exception(vm, "TypeError: iterator next() returned a non-object");
            return result, false;
        }

        found_done, done_val := lookup_property(vm, next_result.object, "done");
        if vm.has_exception return result, false;

        if found_done && is_truthy(done_val) {
            break;
        }

        found_val, val := lookup_property(vm, next_result.object, "value");
        if vm.has_exception return result, false;

        array_add(*result, val);
    }

    return result, true;
}
