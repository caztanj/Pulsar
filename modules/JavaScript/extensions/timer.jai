init_vm_timer :: (vm: *Vm) {
    found_set_timeout, set_timeout_index       := get_global_index(vm, "setTimeout");
    found_clear_timeout, clear_timeout_index   := get_global_index(vm, "clearTimeout");
    found_set_interval, set_interval_index     := get_global_index(vm, "setInterval");
    found_clear_interval, clear_interval_index := get_global_index(vm, "clearInterval");

    if found_set_timeout {
        vm.current_realm.globals[set_timeout_index].type            = .NATIVE_FUNCTION;
        vm.current_realm.globals[set_timeout_index].native_function = timer_set_timeout;
    }
    
    if found_clear_timeout {
        vm.current_realm.globals[clear_timeout_index].type            = .NATIVE_FUNCTION;
        vm.current_realm.globals[clear_timeout_index].native_function = timer_clear_timeout;
    }
    
    if found_set_interval {
        vm.current_realm.globals[set_interval_index].type            = .NATIVE_FUNCTION;
        vm.current_realm.globals[set_interval_index].native_function = timer_set_interval;
    }
    
    if found_clear_interval {
        vm.current_realm.globals[clear_interval_index].type            = .NATIVE_FUNCTION;
        vm.current_realm.globals[clear_interval_index].native_function = timer_clear_timeout;
    }
}

add_timer :: (vm: *Vm, arguments: [] Value, is_interval: bool) -> Value {
    if arguments.count < 1 {
        throw_exception(vm, "Timer requires a callback argument");
        return .{};
    }
    
    callback := arguments[0];
    if callback.type != .FUNCTION && callback.type != .NATIVE_FUNCTION {
        throw_exception(vm, "Timer callback must be a function");
        return .{};
    }
    
    delay_ms: float64 = 0;
    if arguments.count >= 2 {
        if arguments[1].type == .NUMBER {
            delay_ms = arguments[1].number;
        }
    }
    
    if delay_ms < 0 delay_ms = 0;
    
    timer_args: [..] Value;
    for i: 2..arguments.count - 1 {
        array_add(*timer_args, arguments[i]);
    }
    
    vm.timer_id_counter += 1;
    id := vm.timer_id_counter;
    
    now := seconds_since_init();
    
    timer := Timer.{
        id = id,
        callback = callback,
        arguments = timer_args,
        trigger_time = now + delay_ms / 1000.0,
        is_interval = is_interval,
        interval_ms = delay_ms
    };
    
    array_add(*vm.timer_queue, timer);
    
    return .{ type = .NUMBER, number = cast(float64) id };
}

timer_set_timeout :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    return add_timer(vm, arguments, false);
}

timer_set_interval :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    return add_timer(vm, arguments, true);
}

timer_clear_timeout :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count < 1 return .{};
    if arguments[0].type != .NUMBER return .{};
    
    id := cast(int) arguments[0].number;
    
    for vm.timer_queue {
        if it.id == id {
            array_free(it.arguments);
            array_unordered_remove_by_index(*vm.timer_queue, it_index);
            break;
        }
    }
    
    return .{};
}
