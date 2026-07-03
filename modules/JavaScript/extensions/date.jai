init_vm_date :: (vm: *Vm) {
    found, date_global_index := get_global_index(vm, "Date");

    if !vm.date_prototype {
        vm.date_prototype           = allocate_object(vm);
        vm.date_prototype.prototype = vm.object_prototype;
        vm.date_prototype.kind      = .DATE;

        add_instance_method(vm, vm.date_prototype, "getTime",         date_get_time);
        add_instance_method(vm, vm.date_prototype, "getFullYear",     date_get_full_year);
        add_instance_method(vm, vm.date_prototype, "getMonth",        date_get_month);
        add_instance_method(vm, vm.date_prototype, "getDate",         date_get_date);
        add_instance_method(vm, vm.date_prototype, "getHours",        date_get_hours);
        add_instance_method(vm, vm.date_prototype, "getMinutes",      date_get_minutes);
        add_instance_method(vm, vm.date_prototype, "getSeconds",      date_get_seconds);
        add_instance_method(vm, vm.date_prototype, "getMilliseconds", date_get_milliseconds);
        add_instance_method(vm, vm.date_prototype, "toString",        date_to_string);
        add_instance_method(vm, vm.date_prototype, "toISOString",     date_to_iso_string);
    }

    if found {
        vm.current_realm.globals[date_global_index].type = .NATIVE_FUNCTION;
        vm.current_realm.globals[date_global_index].native_function = date_constructor;

        date_object := allocate_object(vm);

        vm.current_realm.globals[date_global_index].object = date_object;

        date_object.prototype = vm.date_prototype;

        add_static_method(vm, date_object, "now", date_now);

        prototype_value := Value.{
            type   = .OBJECT,
            object = vm.date_prototype,
        };

        add_static_property(vm, date_object,       "prototype",   prototype_value);
        add_static_property(vm, vm.date_prototype, "constructor", vm.current_realm.globals[date_global_index]);
    }
}

date_constructor :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if !is_new {
        now      := current_time_consensus();
        calendar := to_calendar(now, .LOCAL);

        s := sprint("% % % %:%:% GMT%", calendar.month_starting_at_0, calendar.day_of_month_starting_at_0 + 1, calendar.year, calendar.hour, calendar.minute, calendar.second, calendar.time_zone);

        return .{ type = .STRING, s = s };
    }

    milliseconds: float64;

    if arguments.count == 0 {
        now          := current_time_consensus();
        milliseconds  = to_float64_seconds(now - APOLLO_TIME_FOR_JAN_1_1970) * 1000.0;
    } else if arguments.count == 1 {
        milliseconds = value_to_number(arguments[0]);
    } else {
        milliseconds = 0.0;
    }

    date_object                 := allocate_object(vm);
    date_object.kind             = .DATE;
    date_object.primitive_value  = .{ type = .NUMBER, number = milliseconds };
    date_object.prototype        = vm.date_prototype;

    return .{ type = .OBJECT, object = date_object };
}

date_now :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    now          := current_time_consensus();
    milliseconds := to_float64_seconds(now - APOLLO_TIME_FOR_JAN_1_1970) * 1000.0;

    return .{ type = .NUMBER, number = milliseconds };
}

get_date_milliseconds :: (this: Value) -> float64 {
    if this.type == .OBJECT && this.object.kind == .DATE return this.object.primitive_value.number;

    return 0.0;
}

get_apollo_from_millis :: (milliseconds: float64) -> Apollo_Time {
    diff := milliseconds_to_apollo(cast(s64) milliseconds);

    return APOLLO_TIME_FOR_JAN_1_1970 + diff;
}

date_get_time :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    return .{ type = .NUMBER, number = get_date_milliseconds(this) };
}

date_get_full_year :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    apollo   := get_apollo_from_millis(get_date_milliseconds(this));
    calendar := to_calendar(apollo, .LOCAL);

    return .{ type = .NUMBER, number = cast(float64) calendar.year };
}

date_get_month :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    apollo   := get_apollo_from_millis(get_date_milliseconds(this));
    calendar := to_calendar(apollo, .LOCAL);

    return .{ type = .NUMBER, number = cast(float64) calendar.month_starting_at_0 };
}

date_get_date :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    apollo   := get_apollo_from_millis(get_date_milliseconds(this));
    calendar := to_calendar(apollo, .LOCAL);

    return .{ type = .NUMBER, number = cast(float64) (calendar.day_of_month_starting_at_0 + 1) };
}

date_get_hours :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    apollo   := get_apollo_from_millis(get_date_milliseconds(this));
    calendar := to_calendar(apollo, .LOCAL);

    return .{ type = .NUMBER, number = cast(float64) calendar.hour };
}

date_get_minutes :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    apollo   := get_apollo_from_millis(get_date_milliseconds(this));
    calendar := to_calendar(apollo, .LOCAL);

    return .{ type = .NUMBER, number = cast(float64) calendar.minute };
}

date_get_seconds :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    apollo   := get_apollo_from_millis(get_date_milliseconds(this));
    calendar := to_calendar(apollo, .LOCAL);

    return .{ type = .NUMBER, number = cast(float64) calendar.second };
}

date_get_milliseconds :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    apollo   := get_apollo_from_millis(get_date_milliseconds(this));
    calendar := to_calendar(apollo, .LOCAL);

    return .{ type = .NUMBER, number = cast(float64) calendar.millisecond };
}

date_to_string :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    apollo   := get_apollo_from_millis(get_date_milliseconds(this));
    calendar := to_calendar(apollo, .LOCAL);

    s := sprint("%-%-% %:%:%", calendar.year, calendar.month_starting_at_0 + 1, calendar.day_of_month_starting_at_0 + 1, calendar.hour, calendar.minute, calendar.second);

    array_add(*vm.allocated_strings, s);

    return .{ type = .STRING, s = s };
}

date_to_iso_string :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    apollo   := get_apollo_from_millis(get_date_milliseconds(this));
    calendar := to_calendar(apollo, .UTC);

    s := sprint("%-%-%T%:%:%.%Z", formatInt(calendar.year, minimum_digits = 4), formatInt(calendar.month_starting_at_0 + 1, minimum_digits = 2), formatInt(calendar.day_of_month_starting_at_0 + 1, minimum_digits = 2), formatInt(calendar.hour, minimum_digits = 2), formatInt(calendar.minute, minimum_digits = 2), formatInt(calendar.second, minimum_digits=2), formatInt(calendar.millisecond, minimum_digits = 3));

    array_add(*vm.allocated_strings, s);

    return .{ type = .STRING, s = s };
}
