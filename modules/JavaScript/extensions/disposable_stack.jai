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

disposable_stack_constructor :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if !is_new {
        throw_exception(vm, "TypeError: Constructor DisposableStack requires 'new'");
        return .{};
    }

    object: *Gc_Object;

    if this.type == .OBJECT && this.object {
        object = this.object;
    } else {
        object = allocate_object(vm);
    }

    object.prototype = vm.disposable_stack_prototype;

    return .{ type = .OBJECT, object = object };
}

async_disposable_stack_constructor :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if !is_new {
        throw_exception(vm, "TypeError: Constructor AsyncDisposableStack requires 'new'");
        return .{};
    }

    object: *Gc_Object;

    if this.type == .OBJECT && this.object {
        object = this.object;
    } else {
        object = allocate_object(vm);
    }

    object.prototype = vm.async_disposable_stack_prototype;

    return .{ type = .OBJECT, object = object };
}
