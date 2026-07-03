init_vm_promise :: (vm: *Vm) {
    found, index := get_global_index(vm, "Promise");

    if found {
        vm.current_realm.globals[index].type        = .NATIVE_FUNCTION;
        vm.current_realm.globals[index].native_function = promise_constructor;
    }
}

promise_constructor :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    object := allocate_object(vm);

    object.kind           = .PROMISE;
    object.promise_status = .PENDING;

    result := Value.{ type = .OBJECT, object = object };

    if arguments.count > 0 {
        executor := arguments[0];

        resolve_object := allocate_object(vm);

        set_object_property(vm, resolve_object, "__promise", result);

        resolve_value := Value.{
            type            = .NATIVE_FUNCTION,
            native_function = promise_resolve,
            object          = resolve_object,
        };

        exec_arguments: [1] Value = .[
            resolve_value,
        ];

        call_value(vm, .{}, executor, exec_arguments);
    }

    add_instance_method(vm, object, "then", promise_then);

    return result;
}

promise_resolve :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .NATIVE_FUNCTION && this.object {
        found, promise_value := lookup_property(vm, this.object, "__promise");

        if found && promise_value.type == .OBJECT && promise_value.object.kind == .PROMISE {
            promise_object := promise_value.object;

            if promise_object.promise_status == .PENDING {
                value := ifx arguments.count > 0 arguments[0] else Value.{};

                promise_object.promise_status = .FULFILLED;
                promise_object.promise_result = value;

                for promise_object.promise_then_callbacks {
                    task := Microtask.{
                        callback = it,
                        arg      = value,
                    };

                    array_add(*vm.microtask_queue, task);
                }
            }
        }
    }

    return .{};
}

promise_then :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.kind == .PROMISE {
        promise_object := this.object;

        if arguments.count > 0 {
            callback := arguments[0];

            if promise_object.promise_status == .FULFILLED {
                task := Microtask.{
                    callback = callback,
                    arg      = promise_object.promise_result,
                };

                array_add(*vm.microtask_queue, task);
            } else {
                array_add(*promise_object.promise_then_callbacks, callback);
            }
        }
    }

    return this;
}