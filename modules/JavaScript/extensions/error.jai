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
        "RangeError"
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
