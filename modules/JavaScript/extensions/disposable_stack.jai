init_vm_disposable_stack :: (vm: *Vm) {
    {
        found, index := get_global_index(vm, "DisposableStack");
        if found {
            vm.current_realm.globals[index].type            = .NATIVE_FUNCTION;
            vm.current_realm.globals[index].native_function = disposable_stack_constructor;

            constructor_object := allocate_object(vm);
            constructor_object.prototype = vm.function_prototype;
            vm.current_realm.globals[index].object = constructor_object;

            set_object_property(vm, constructor_object, "name",   Value.{ type = .STRING, s = "DisposableStack" });
            set_object_property(vm, constructor_object, "length", Value.{ type = .NUMBER, number = 0 });

            if !vm.disposable_stack_prototype {
                vm.disposable_stack_prototype = allocate_object(vm);
                vm.disposable_stack_prototype.prototype = vm.object_prototype;
            }

            prototype_value := Value.{ type = .OBJECT, object = vm.disposable_stack_prototype };

            add_static_property(vm, constructor_object,            "prototype",   prototype_value);
            add_static_property(vm, vm.disposable_stack_prototype, "constructor", vm.current_realm.globals[index]);
        }
    }

    {
        found, index := get_global_index(vm, "AsyncDisposableStack");
        if found {
            vm.current_realm.globals[index].type            = .NATIVE_FUNCTION;
            vm.current_realm.globals[index].native_function = async_disposable_stack_constructor;

            constructor_object := allocate_object(vm);
            constructor_object.prototype = vm.function_prototype;
            vm.current_realm.globals[index].object = constructor_object;

            set_object_property(vm, constructor_object, "name",   Value.{ type = .STRING, s = "AsyncDisposableStack" });
            set_object_property(vm, constructor_object, "length", Value.{ type = .NUMBER, number = 0 });

            if !vm.async_disposable_stack_prototype {
                vm.async_disposable_stack_prototype = allocate_object(vm);
                vm.async_disposable_stack_prototype.prototype = vm.object_prototype;
            }

            prototype_value := Value.{ type = .OBJECT, object = vm.async_disposable_stack_prototype };

            add_static_property(vm, constructor_object,                  "prototype",   prototype_value);
            add_static_property(vm, vm.async_disposable_stack_prototype, "constructor", vm.current_realm.globals[index]);
        }
    }
}

get_prototype_from_constructor :: (vm: *Vm, new_target: Value, default_proto: *Gc_Object) -> (ok: bool, proto: *Gc_Object) {
    new_target_obj: *Gc_Object;

    if new_target.type == .OBJECT || new_target.type == .FUNCTION || new_target.type == .NATIVE_FUNCTION {
        new_target_obj = new_target.object;
    }

    if new_target_obj {
        found, proto_val := lookup_property(vm, new_target_obj, "prototype");
        if vm.has_exception return false, null;
        if found && (proto_val.type == .OBJECT || proto_val.type == .ARRAY) && proto_val.object {
            return true, proto_val.object;
        }
    }

    return true, default_proto;
}

disposable_stack_constructor :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if !is_new {
        throw_exception(vm, "TypeError: Constructor DisposableStack requires 'new'");
        return .{};
    }

    ok, proto := get_prototype_from_constructor(vm, this, vm.disposable_stack_prototype);
    if !ok return .{};

    object := allocate_object(vm);
    object.prototype = proto;

    return .{ type = .OBJECT, object = object };
}

async_disposable_stack_constructor :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if !is_new {
        throw_exception(vm, "TypeError: Constructor AsyncDisposableStack requires 'new'");
        return .{};
    }

    ok, proto := get_prototype_from_constructor(vm, this, vm.async_disposable_stack_prototype);
    if !ok return .{};

    object := allocate_object(vm);
    object.prototype = proto;

    return .{ type = .OBJECT, object = object };
}
