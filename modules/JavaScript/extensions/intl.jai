init_vm_intl :: (vm: *Vm) {
    found, index := get_global_index(vm, "Intl");

    if found {
        intl_object := allocate_object(vm);

        vm.current_realm.globals[index].type   = .OBJECT;
        vm.current_realm.globals[index].object = intl_object;

        add_static_method(vm, intl_object, "Collator", intl_collator);
        add_static_method(vm, intl_object, "NumberFormat", intl_collator);
        add_static_method(vm, intl_object, "DateTimeFormat", intl_collator);
    }
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
