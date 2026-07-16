init_vm_console :: (vm: *Vm) {
    found, console_index := get_global_index(vm, "console");
    if found {
        console_object := allocate_object(vm);

        vm.current_realm.globals[console_index].type   = .OBJECT;
        vm.current_realm.globals[console_index].object = console_object;

        add_static_method(vm, console_object, "log",     console_log);
        add_static_method(vm, console_object, "error",   console_error);
        add_static_method(vm, console_object, "warn",    console_warn);
        add_static_method(vm, console_object, "info",    console_info);
        add_static_method(vm, console_object, "debug",   console_log);
        add_static_method(vm, console_object, "time",    console_time);
        add_static_method(vm, console_object, "timeEnd", console_timeEnd);
        add_static_method(vm, console_object, "assert",  console_assert);
        add_static_method(vm, console_object, "clear",   console_clear);
    }
}

console_stringify :: (vm: *Vm, builder: *String_Builder, value: Value, depth: int) {
    if value.type == {
        case .UNDEFINED;
            append(builder, "undefined");

        case .NULL;
            append(builder, "null");

        case .NUMBER;
            print_item_to_builder(builder, value.number);

        case .BOOLEAN;
            append(builder, ifx value.boolean "true" else "false");

        case .STRING;
            if depth > 0 append(builder, "'");
            append(builder, value.s);
            if depth > 0 append(builder, "'");

        case .FUNCTION; #through;
        case .NATIVE_FUNCTION;
            append(builder, "[Function]");

        case .ARRAY;
            if depth >= 2 {
                append(builder, "[Array]");
                return;
            }

            append(builder, "[ ");

            object := value.object;

            for object.elements {
                if it_index > 0 append(builder, ", ");
                console_stringify(vm, builder, it, depth + 1);
            }

            append(builder, " ]");

        case .OBJECT;
            if depth >= 2 {
                append(builder, "[Object]");
                return;
            }

            append(builder, "{ ");

            object := value.object;
            first := true;

            for object.elements {
                if it.type == .UNDEFINED continue;
                if !first append(builder, ", ");

                first = false;

                append(builder, tprint("%: ", it_index));
                console_stringify(vm, builder, it, depth + 1);
            }

            if object.shape {
                for object.shape.property_names {
                    offset_pointer := table_find_pointer(*object.shape.property_offsets, it);
                    if !offset_pointer || offset_pointer.* >= object.fields.count continue;

                    property_value := object.fields[offset_pointer.*];
                    if property_value.type == .UNDEFINED continue;
                    if !first append(builder, ", ");

                    first = false;

                    append(builder, it);
                    append(builder, ": ");

                    console_stringify(vm, builder, property_value, depth + 1);
                }
            }

            append(builder, " }");

        case .GENERATOR;
            append(builder, "[Generator]");
    }
}

console_print_args :: (vm: *Vm, arguments: [] Value, to_stderr: bool) {
    if vm.silence_console_output return;

    builder: String_Builder;
    builder.allocator = temp;

    for arguments {
        if it_index > 0 append(*builder, " ");
        console_stringify(vm, *builder, it, 0);
    }

    append(*builder, "\n");
    s := builder_to_string(*builder,, temp);
    write_string(s, to_standard_error = to_stderr);
}

console_log :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool = false) -> Value {
    console_print_args(vm, arguments, false);
    return .{};
}

console_error :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool = false) -> Value {
    console_print_args(vm, arguments, true);
    return .{};
}

console_warn :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool = false) -> Value {
    console_print_args(vm, arguments, true);
    return .{};
}

console_info :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool = false) -> Value {
    console_print_args(vm, arguments, false);
    return .{};
}

console_assert :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool = false) -> Value {
    if arguments.count == 0 return .{};

    condition := is_truthy(arguments[0]);
    if !condition {
        if vm.silence_console_output return .{};
        
        builder: String_Builder;
        builder.allocator = temp;
        append(*builder, "Assertion failed");

        if arguments.count > 1 {
            append(*builder, ": ");
            for 1..arguments.count-1 {
                if it > 1 append(*builder, " ");
                console_stringify(vm, *builder, arguments[it], 0);
            }
        }
        append(*builder, "\n");
        write_string(builder_to_string(*builder,, temp), to_standard_error = true);
    }

    return .{};
}

console_clear :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool = false) -> Value {
    write_string("\x1b[2J\x1b[H");
    return .{};
}

console_time :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool = false) -> Value {
    label := "default";
    if arguments.count > 0 {
        label = value_to_string(vm, arguments[0]);
    }

    start_time := seconds_since_init();
    table_set(*global_console_timers, label, start_time);

    return .{};
}

console_timeEnd :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool = false) -> Value {
    label := "default";
    if arguments.count > 0 {
        label = value_to_string(vm, arguments[0]);
    }

    start_time_ptr := table_find_pointer(*global_console_timers, label);
    if start_time_ptr {
        start_time := start_time_ptr.*;
        end_time := seconds_since_init();
        elapsed := (end_time - start_time) * 1000.0;

        if !vm.silence_console_output {
            builder: String_Builder;
            builder.allocator = temp;
            append(*builder, label);
            append(*builder, ": ");
            print_item_to_builder(*builder, elapsed);
            append(*builder, " ms\n");

            write_string(builder_to_string(*builder,, temp));
        }

        table_remove(*global_console_timers, label);
    } else {
        if !vm.silence_console_output print("Timer '%' does not exist\n", label);
    }

    return .{};
}

global_console_timers: Table(string, float64);
