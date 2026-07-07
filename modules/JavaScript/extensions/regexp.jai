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
    pattern := "";
    
    if arguments.count > 0 {
        if arguments[0].type == .OBJECT && arguments[0].object && arguments[0].object.kind == .REGEXP {
            found_source, source_val := lookup_property(vm, arguments[0].object, "source");
            if found_source && source_val.type == .STRING {
                pattern = copy_string(source_val.s);
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
    regexp_object.kind      = .REGEXP;
    regexp_object.prototype = vm.regexp_prototype;
    
    regexp, success := Uniform.compile(pattern);
    if !success {
        throw_exception(vm, sprint("Invalid regular expression: %", pattern));
        return .{ type = .OBJECT, object = regexp_object };
    }
    
    regexp_object.regexp = regexp;
    
    set_object_property(vm, regexp_object, "source", .{ type = .STRING, s = copy_string(pattern) });
    set_object_property(vm, regexp_object, "flags",  .{ type = .STRING, s = copy_string(flags) });
    
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
    
    matched, captures := Uniform.match(str, this.object.regexp);
    array_free(captures);
    
    return .{ type = .BOOLEAN, boolean = matched };
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
    
    matched, captures := Uniform.match(str, this.object.regexp);
    defer array_free(captures);
    
    if !matched return .{ type = .NULL };
    
    array_object := allocate_object(vm);
    array_object.kind      = .ARRAY;
    array_object.prototype = vm.array_prototype;
    
    for captures {
        array_add(*array_object.elements, .{ type = .STRING, s = copy_string(it) });
    }
    
    set_object_property(vm, array_object, "length", .{ type = .NUMBER, number = cast(float64) captures.count });
    set_object_property(vm, array_object, "index",  .{ type = .NUMBER, number = 0.0 });
    set_object_property(vm, array_object, "input",  .{ type = .STRING, s = copy_string(str) });
    
    return .{ type = .OBJECT, object = array_object };
}
