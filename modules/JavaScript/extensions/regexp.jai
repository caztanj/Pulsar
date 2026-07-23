init_vm_regexp :: (vm: *Vm) {
    found, index := get_global_index(vm, "RegExp");

    if !vm.regexp_prototype {
        vm.regexp_prototype = allocate_object(vm);
        vm.regexp_prototype.prototype = vm.object_prototype;

        add_instance_method(vm, vm.regexp_prototype, "test", regexp_test);
        add_instance_method(vm, vm.regexp_prototype, "exec", regexp_exec);
    }

    if found {
        vm.current_realm.globals[index].type            = .NATIVE_FUNCTION;
        vm.current_realm.globals[index].native_function = regexp_constructor;

        regexp_object := allocate_object(vm);

        vm.current_realm.globals[index].object = regexp_object;

        regexp_object.prototype = vm.regexp_prototype;

        prototype_value := Value.{
            type   = .OBJECT,
            object = vm.regexp_prototype,
        };

        add_static_property(vm, regexp_object,       "prototype",   prototype_value);
        add_static_property(vm, vm.regexp_prototype, "constructor", vm.current_realm.globals[index]);
    }
}

regexp_constructor :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if !is_new && arguments.count > 0 && arguments[0].type == .OBJECT && arguments[0].object && arguments[0].object.kind == .REGEXP {
        if arguments.count == 1 || arguments[1].type == .UNDEFINED {
            return arguments[0];
        }
    }

    pattern := "";
    
    if arguments.count > 0 {
        if arguments[0].type == .OBJECT && arguments[0].object && arguments[0].object.kind == .REGEXP {
            found_source, source_val := lookup_property(vm, arguments[0].object, "source");
            if found_source && source_val.type == .STRING {
                pattern = allocate_string(vm, source_val.s);
            }
        } else if arguments[0].type != .UNDEFINED {
            pattern = value_to_string(vm, arguments[0]);
        }
    }
    
    flags := "";
    if arguments.count > 1 && arguments[1].type != .UNDEFINED {
        flags = value_to_string(vm, arguments[1]);
    }
    
    regexp_object := allocate_object(vm);
    regexp_object.prototype = vm.regexp_prototype;
    
    regexp, success := Uniform.compile(pattern);
    if !success {
        msg := sprint("Invalid regular expression: %", pattern);
        throw_exception(vm, allocate_string(vm, msg));
        free(msg);
        return .{ type = .OBJECT, object = regexp_object };
    }
    
    regexp_object.kind   = .REGEXP;
    regexp_object.regexp = regexp;
    
    set_object_property(vm, regexp_object, "source", .{ type = .STRING, s = allocate_string(vm, pattern) });
    set_object_property(vm, regexp_object, "flags",  .{ type = .STRING, s = allocate_string(vm, flags) });
    
    return .{ type = .OBJECT, object = regexp_object };
}

regexp_test :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .OBJECT || this.object.kind != .REGEXP {
        throw_exception(vm, "Method RegExp.prototype.test called on incompatible receiver");
        return .{ type = .BOOLEAN, boolean = false };
    }
    
    str := "undefined";
    if arguments.count > 0 {
        str = value_to_string(vm, arguments[0]);
    }
    
    flags_val := get_property_or_undefined(vm, this.object, "flags");
    flags := ifx flags_val.type == .STRING then flags_val.s else "";
    is_global := contains(flags, "g");
    is_sticky := contains(flags, "y");

    last_index := 0;
    if is_global || is_sticky {
        last_index_val := get_property_or_undefined(vm, this.object, "lastIndex");
        if last_index_val.type == .NUMBER {
            last_index = cast(int) last_index_val.number;
            if last_index < 0 last_index = 0;
        }
    }

    if last_index > str.count {
        if is_global || is_sticky {
            set_object_property(vm, this.object, "lastIndex", .{ type = .NUMBER, number = 0.0 });
        }
        return .{ type = .BOOLEAN, boolean = false };
    }

    anchor: Uniform.Anchor = .UNANCHORED;
    if is_sticky anchor = .ANCHOR_START;

    matched, captures := Uniform.match(str, this.object.regexp, anchor, last_index);
    defer array_free(captures);
    
    if !matched {
        if is_global || is_sticky {
            set_object_property(vm, this.object, "lastIndex", .{ type = .NUMBER, number = 0.0 });
        }
        return .{ type = .BOOLEAN, boolean = false };
    }

    match_index := last_index;
    if captures.count > 0 && captures[0].data >= str.data && captures[0].data <= str.data + str.count {
        match_index = cast(int)(captures[0].data - str.data);
    }
    
    if is_global || is_sticky {
        new_last_index := match_index + captures[0].count;
        set_object_property(vm, this.object, "lastIndex", .{ type = .NUMBER, number = cast(float64) new_last_index });
    }
    
    return .{ type = .BOOLEAN, boolean = true };
}

regexp_exec :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .OBJECT || this.object.kind != .REGEXP {
        throw_exception(vm, "Method RegExp.prototype.exec called on incompatible receiver");
        return .{ type = .UNDEFINED };
    }
    
    str := "undefined";
    if arguments.count > 0 {
        str = value_to_string(vm, arguments[0]);
    }

    flags_val := get_property_or_undefined(vm, this.object, "flags");
    flags := ifx flags_val.type == .STRING then flags_val.s else "";
    is_global := contains(flags, "g");
    is_sticky := contains(flags, "y");

    last_index := 0;
    if is_global || is_sticky {
        last_index_val := get_property_or_undefined(vm, this.object, "lastIndex");
        if last_index_val.type == .NUMBER {
            last_index = cast(int) last_index_val.number;
            if last_index < 0 last_index = 0;
        }
    }

    if last_index > str.count {
        if is_global || is_sticky {
            set_object_property(vm, this.object, "lastIndex", .{ type = .NUMBER, number = 0.0 });
        }
        return .{ type = .NULL };
    }

    anchor: Uniform.Anchor = .UNANCHORED;
    if is_sticky anchor = .ANCHOR_START;

    matched, captures := Uniform.match(str, this.object.regexp, anchor, last_index);
    defer array_free(captures);
    
    if !matched {
        if is_global || is_sticky {
            set_object_property(vm, this.object, "lastIndex", .{ type = .NUMBER, number = 0.0 });
        }
        return .{ type = .NULL };
    }

    match_index := last_index;
    if captures.count > 0 && captures[0].data >= str.data && captures[0].data <= str.data + str.count {
        match_index = cast(int)(captures[0].data - str.data);
    }
    
    if is_global || is_sticky {
        new_last_index := match_index + captures[0].count;
        set_object_property(vm, this.object, "lastIndex", .{ type = .NUMBER, number = cast(float64) new_last_index });
    }
    
    array_object := allocate_object(vm);
    array_object.kind      = .ARRAY;
    array_object.prototype = vm.array_prototype;
    
    for captures {
        array_add(*array_object.elements, .{ type = .STRING, s = allocate_string(vm, it) });
    }
    
    set_object_property(vm, array_object, "length", .{ type = .NUMBER, number = cast(float64) captures.count });
    set_object_property(vm, array_object, "index",  .{ type = .NUMBER, number = cast(float64) match_index });
    set_object_property(vm, array_object, "input",  .{ type = .STRING, s = allocate_string(vm, str) });
    
    return .{ type = .OBJECT, object = array_object };
}
