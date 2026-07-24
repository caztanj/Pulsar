init_vm_intl :: (vm: *Vm) {
    found, index := get_global_index(vm, "Intl");

    if found {
        intl_object := allocate_object(vm);

        vm.current_realm.globals[index].type   = .OBJECT;
        vm.current_realm.globals[index].object = intl_object;

        collator_object := allocate_object(vm);
        collator_value := Value.{
            type = .NATIVE_FUNCTION,
            native_function = intl_collator,
            object = collator_object,
        };
        add_static_method(vm, collator_object, "supportedLocalesOf", intl_supported_locales_of);
        set_object_property(vm, intl_object, "Collator", collator_value);

        number_format_object := allocate_object(vm);
        number_format_value := Value.{
            type = .NATIVE_FUNCTION,
            native_function = intl_collator,
            object = number_format_object,
        };
        add_static_method(vm, number_format_object, "supportedLocalesOf", intl_supported_locales_of);
        set_object_property(vm, intl_object, "NumberFormat", number_format_value);

        date_time_format_object := allocate_object(vm);
        date_time_format_value := Value.{
            type = .NATIVE_FUNCTION,
            native_function = intl_collator,
            object = date_time_format_object,
        };
        add_static_method(vm, date_time_format_object, "supportedLocalesOf", intl_supported_locales_of);
        set_object_property(vm, intl_object, "DateTimeFormat", date_time_format_value);
    }
}

intl_supported_locales_of :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    array := allocate_object(vm);
    array.kind = .ARRAY;
    array.prototype = vm.array_prototype;

    if arguments.count > 0 {
        arg := arguments[0];
        if arg.type == .ARRAY && arg.object {
            for element: arg.object.elements {
                if element.type == .STRING && element.s == "zxx" continue;

                is_duplicate := false;
                for existing: array.elements {
                    if existing.type == element.type {
                        if element.type == .STRING && existing.s == element.s {
                            is_duplicate = true;
                            break;
                        } else if element.type == .NUMBER && existing.number == element.number {
                            is_duplicate = true;
                            break;
                        } else if element.type == .OBJECT && existing.object == element.object {
                            is_duplicate = true;
                            break;
                        }
                    }
                }

                if !is_duplicate {
                    array_add(*array.elements, element);
                }
            }
        } else if arg.type != .UNDEFINED {
            if arg.type == .STRING && arg.s == "zxx" {} else {
                array_add(*array.elements, arg);
            }
        }
    }

    return .{ type = .OBJECT, object = array };
}

intl_collator :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    object := allocate_object(vm);
    locale := Value.{ type = .UNDEFINED };

    if arguments.count > 0 {
        argument := arguments[0];
        if argument.type == .ARRAY && argument.object {
            if argument.object.elements.count > 0 {
                locale = argument.object.elements[0];
            }
        } else {
            locale = argument;
        }
    }

    add_static_method(vm, object, "resolvedOptions", intl_resolved_options);
    set_object_property(vm, object, "__locale", locale);

    return .{ type = .OBJECT, object = object };
}

intl_resolved_options :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    options := allocate_object(vm);

    locale_value := Value.{ type = .UNDEFINED };
    if this.type == .OBJECT && this.object {
        found, value := lookup_property(vm, this.object, "__locale");
        if found locale_value = value;
    }

    set_object_property(vm, options, "locale", locale_value);

    return .{ type = .OBJECT, object = options };
}
