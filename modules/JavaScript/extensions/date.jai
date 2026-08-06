init_vm_date :: (vm: *Vm) {
    found, date_global_index := get_global_index(vm, "Date");

    if !vm.date_prototype {
        vm.date_prototype           = allocate_object(vm);
        vm.date_prototype.prototype = vm.object_prototype;
        vm.date_prototype.kind      = .DATE;

        add_instance_method(vm, vm.date_prototype, "getTime",              date_get_time);
        add_instance_method(vm, vm.date_prototype, "valueOf",              date_get_time);
        add_instance_method(vm, vm.date_prototype, "getTimezoneOffset",   date_get_timezone_offset);
        add_instance_method(vm, vm.date_prototype, "getFullYear",          date_get_full_year);
        add_instance_method(vm, vm.date_prototype, "getMonth",        date_get_month);
        add_instance_method(vm, vm.date_prototype, "getDate",         date_get_date);
        add_instance_method(vm, vm.date_prototype, "getHours",        date_get_hours);
        add_instance_method(vm, vm.date_prototype, "getMinutes",      date_get_minutes);
        add_instance_method(vm, vm.date_prototype, "getSeconds",      date_get_seconds);
        add_instance_method(vm, vm.date_prototype, "getMilliseconds", date_get_milliseconds);
        add_instance_method(vm, vm.date_prototype, "toString",             date_to_string);
        add_instance_method(vm, vm.date_prototype, "toISOString",          date_to_iso_string);
        add_instance_method(vm, vm.date_prototype, "@@Symbol.toPrimitive", date_to_primitive);
    }

    if found {
        vm.current_realm.globals[date_global_index].type = .NATIVE_FUNCTION;
        vm.current_realm.globals[date_global_index].native_function = date_constructor;

        date_object := allocate_object(vm);

        vm.current_realm.globals[date_global_index].object = date_object;

        date_object.prototype = vm.function_prototype;

        add_static_method(vm, date_object, "now", date_now);
        add_static_method(vm, date_object, "parse", date_parse);
        add_static_method(vm, date_object, "UTC", date_utc);

        add_static_property(vm, date_object, "name",   .{ type = .STRING, s = "Date" });
        add_static_property(vm, date_object, "length", .{ type = .NUMBER, number = 7 });

        prototype_value := Value.{
            type   = .OBJECT,
            object = vm.date_prototype,
        };

        add_static_property(vm, date_object,       "prototype",   prototype_value);
        add_static_property(vm, vm.date_prototype, "constructor", vm.current_realm.globals[date_global_index]);
    }
}

is_leap_year :: (y: int) -> bool {
    return (y % 4 == 0) && (y % 100 != 0 || y % 400 == 0);
}

floor_div :: (a: int, b: int) -> int {
    res := a / b;
    rem := a % b;
    if (rem != 0) && ((a < 0) != (b < 0)) res -= 1;
    return res;
}

days_from_year :: (y: int) -> int {
    return 365 * (y - 1970) + floor_div(y - 1969, 4) - floor_div(y - 1901, 100) + floor_div(y - 1601, 400);
}

days_before_month :: (m: int, leap: bool) -> int {
    MONTH_DAYS :: int.[0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
    days := MONTH_DAYS[m];
    if m >= 2 && leap days += 1;
    return days;
}

compute_date_millis :: (y_in: int, m_in: int, d_in: int, h_in: int, min_in: int, sec_in: int, ms_in: int, zone: Time_Zone) -> float64 {
    y := y_in;
    m := m_in;

    extra_y := floor_div(m, 12);
    m = m % 12;
    if m < 0 m += 12;
    y += extra_y;

    if abs(y) > 285616 return FLOAT64_NAN;

    leap := is_leap_year(y);
    total_days := days_from_year(y) + days_before_month(m, leap) + (d_in - 1);
    total_ms := cast(float64) total_days * 86400000.0 + cast(float64) h_in * 3600000.0 + cast(float64) min_in * 60000.0 + cast(float64) sec_in * 1000.0 + cast(float64) ms_in;

    if zone == .LOCAL {
        now := current_time_consensus();
        cal_utc := to_calendar(now, .UTC);
        cal_loc := to_calendar(now, .LOCAL);
        tz_offset_ms := cast(float64) (cal_loc.hour - cal_utc.hour) * 3600000.0 + cast(float64) (cal_loc.minute - cal_utc.minute) * 60000.0;
        total_ms -= tz_offset_ms;
    }

    return total_ms;
}

parse_date_string :: (s: string) -> float64, bool {
    str := trim(s);
    if str.count == 0 return FLOAT64_NAN, false;

    idx := 0;
    sign := 1;
    if str[idx] == #char "-" {
        sign = -1;
        idx += 1;
    } else if str[idx] == #char "+" {
        sign = 1;
        idx += 1;
    }

    year_digits := 0;
    year_val := 0;
    while idx < str.count && str[idx] >= #char "0" && str[idx] <= #char "9" {
        year_val = year_val * 10 + cast(int)(str[idx] - #char "0");
        year_digits += 1;
        idx += 1;
    }

    if year_digits == 0 return FLOAT64_NAN, false;
    if sign == -1 && year_val == 0 return FLOAT64_NAN, false;
    year := sign * year_val;

    month := 1;
    day := 1;
    hour := 0;
    minute := 0;
    second := 0;
    millisecond := 0;

    is_date_only := true;
    is_utc := true;

    if idx < str.count && str[idx] == #char "-" {
        idx += 1;
        m_val := 0;
        m_digits := 0;
        while idx < str.count && str[idx] >= #char "0" && str[idx] <= #char "9" {
            m_val = m_val * 10 + cast(int)(str[idx] - #char "0");
            m_digits += 1;
            idx += 1;
        }
        if m_digits > 0 month = m_val;

        if idx < str.count && str[idx] == #char "-" {
            idx += 1;
            d_val := 0;
            d_digits := 0;
            while idx < str.count && str[idx] >= #char "0" && str[idx] <= #char "9" {
                d_val = d_val * 10 + cast(int)(str[idx] - #char "0");
                d_digits += 1;
                idx += 1;
            }
            if d_digits > 0 day = d_val;
        }
    }

    if idx < str.count && (str[idx] == #char "T" || str[idx] == #char "t" || str[idx] == #char " ") {
        is_date_only = false;
        is_utc = false;
        idx += 1;

        h_val := 0;
        while idx < str.count && str[idx] >= #char "0" && str[idx] <= #char "9" {
            h_val = h_val * 10 + cast(int)(str[idx] - #char "0");
            idx += 1;
        }
        hour = h_val;

        if idx < str.count && str[idx] == #char ":" {
            idx += 1;
            min_val := 0;
            while idx < str.count && str[idx] >= #char "0" && str[idx] <= #char "9" {
                min_val = min_val * 10 + cast(int)(str[idx] - #char "0");
                idx += 1;
            }
            minute = min_val;

            if idx < str.count && str[idx] == #char ":" {
                idx += 1;
                sec_val := 0;
                while idx < str.count && str[idx] >= #char "0" && str[idx] <= #char "9" {
                    sec_val = sec_val * 10 + cast(int)(str[idx] - #char "0");
                    idx += 1;
                }
                second = sec_val;

                if idx < str.count && str[idx] == #char "." {
                    idx += 1;
                    ms_val := 0;
                    ms_digits := 0;
                    while idx < str.count && str[idx] >= #char "0" && str[idx] <= #char "9" {
                        if ms_digits < 3 ms_val = ms_val * 10 + cast(int)(str[idx] - #char "0");
                        ms_digits += 1;
                        idx += 1;
                    }
                    if ms_digits == 1 ms_val *= 100;
                    else if ms_digits == 2 ms_val *= 10;
                    millisecond = ms_val;
                }
            }
        }
    }

    if idx < str.count {
        if str[idx] == #char "Z" || str[idx] == #char "z" {
            is_utc = true;
            idx += 1;
        } else if str[idx] == #char "+" || str[idx] == #char "-" {
            is_utc = true;
            tz_sign := ifx str[idx] == #char "-" then -1 else 1;
            idx += 1;
            tz_h := 0;
            while idx < str.count && str[idx] >= #char "0" && str[idx] <= #char "9" {
                tz_h = tz_h * 10 + cast(int)(str[idx] - #char "0");
                idx += 1;
            }
            tz_m := 0;
            if idx < str.count && str[idx] == #char ":" {
                idx += 1;
                while idx < str.count && str[idx] >= #char "0" && str[idx] <= #char "9" {
                    tz_m = tz_m * 10 + cast(int)(str[idx] - #char "0");
                    idx += 1;
                }
            }
            minute -= tz_sign * tz_m;
            hour -= tz_sign * tz_h;
        }
    }

    if is_date_only is_utc = true;

    millis := compute_date_millis(year, month - 1, day, hour, minute, second, millisecond, ifx is_utc then .UTC else .LOCAL);
    if isnan(millis) return FLOAT64_NAN, false;
    return millis, true;
}

MONTH_NAMES :: string.["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
DAY_NAMES   :: string.["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

date_constructor :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if !is_new {
        now      := current_time_consensus();
        calendar := to_calendar(now, .LOCAL);

        month_str := ifx calendar.month_starting_at_0 >= 0 && calendar.month_starting_at_0 < 12 then MONTH_NAMES[calendar.month_starting_at_0] else "Jan";
        day_str   := ifx calendar.day_of_week_starting_at_0 >= 0 && calendar.day_of_week_starting_at_0 < 7 then DAY_NAMES[calendar.day_of_week_starting_at_0] else "Sun";

        s := sprint("% % % % %:%:% GMT", day_str, month_str, formatInt(calendar.day_of_month_starting_at_0 + 1, minimum_digits = 2), calendar.year, formatInt(calendar.hour, minimum_digits = 2), formatInt(calendar.minute, minimum_digits = 2), formatInt(calendar.second, minimum_digits = 2));

        return .{ type = .STRING, s = s };
    }

    milliseconds: float64;

    if arguments.count == 0 {
        now          := current_time_consensus();
        milliseconds  = to_float64_seconds(now - APOLLO_TIME_FOR_JAN_1_1970) * 1000.0;
    } else if arguments.count == 1 {
        arg := arguments[0];
        if arg.type == .STRING {
            millis, ok := parse_date_string(arg.s);
            if ok {
                milliseconds = millis;
            } else {
                milliseconds = FLOAT64_NAN;
            }
        } else if arg.type == .OBJECT && arg.object.kind == .DATE {
            milliseconds = arg.object.primitive_value.number;
        } else {
            prim := to_primitive(vm, arg, .NUMBER);
            if vm.has_exception return .{};
            if prim.type == .STRING {
                millis, ok := parse_date_string(prim.s);
                if ok {
                    milliseconds = millis;
                } else {
                    milliseconds = FLOAT64_NAN;
                }
            } else {
                milliseconds = abstract_to_number(vm, prim);
                if vm.has_exception return .{};
            }
        }
    } else {
        y_val := abstract_to_number(vm, arguments[0]);
        if vm.has_exception return .{};
        m_val := abstract_to_number(vm, arguments[1]);
        if vm.has_exception return .{};

        d_val: float64 = 1.0;
        if arguments.count > 2 {
            d_val = abstract_to_number(vm, arguments[2]);
            if vm.has_exception return .{};
        }

        h_val: float64 = 0.0;
        if arguments.count > 3 {
            h_val = abstract_to_number(vm, arguments[3]);
            if vm.has_exception return .{};
        }

        min_val: float64 = 0.0;
        if arguments.count > 4 {
            min_val = abstract_to_number(vm, arguments[4]);
            if vm.has_exception return .{};
        }

        sec_val: float64 = 0.0;
        if arguments.count > 5 {
            sec_val = abstract_to_number(vm, arguments[5]);
            if vm.has_exception return .{};
        }

        ms_val: float64 = 0.0;
        if arguments.count > 6 {
            ms_val = abstract_to_number(vm, arguments[6]);
            if vm.has_exception return .{};
        }

        if isnan(y_val) || isnan(m_val) || isnan(d_val) || isnan(h_val) || isnan(min_val) || isnan(sec_val) || isnan(ms_val) ||
           isinf(y_val) || isinf(m_val) || isinf(d_val) || isinf(h_val) || isinf(min_val) || isinf(sec_val) || isinf(ms_val) {
            milliseconds = FLOAT64_NAN;
        } else {
            y := cast(int) y_val;
            if y >= 0 && y <= 99 y += 1900;
            m := cast(int) m_val;
            d := cast(int) d_val;
            h := cast(int) h_val;
            min := cast(int) min_val;
            sec := cast(int) sec_val;
            ms := cast(int) ms_val;

            milliseconds = compute_date_millis(y, m, d, h, min, sec, ms, .LOCAL);
        }
    }

    if isnan(milliseconds) || isinf(milliseconds) || milliseconds > 8640000000000000.0 || milliseconds < -8640000000000000.0 {
        milliseconds = FLOAT64_NAN;
    } else {
        milliseconds = cast(float64) cast(s64) milliseconds;
    }

    ok, proto := get_prototype_from_constructor(vm, this, vm.date_prototype);
    if !ok return .{};

    date_object                 := allocate_object(vm);
    date_object.kind             = .DATE;
    date_object.primitive_value  = .{ type = .NUMBER, number = milliseconds };
    date_object.prototype        = proto;

    return .{ type = .OBJECT, object = date_object };
}

date_parse :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .NUMBER, number = FLOAT64_NAN };

    str := value_to_string(vm, arguments[0]);
    if vm.has_exception return .{};

    millis, ok := parse_date_string(str);
    if !ok return .{ type = .NUMBER, number = FLOAT64_NAN };

    return .{ type = .NUMBER, number = millis };
}

date_utc :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .NUMBER, number = FLOAT64_NAN };

    y_val := abstract_to_number(vm, arguments[0]);
    if vm.has_exception return .{};
    m_val := ifx arguments.count > 1 then abstract_to_number(vm, arguments[1]) else 0.0;
    if vm.has_exception return .{};

    d_val: float64 = 1.0;
    if arguments.count > 2 {
        d_val = abstract_to_number(vm, arguments[2]);
        if vm.has_exception return .{};
    }

    h_val: float64 = 0.0;
    if arguments.count > 3 {
        h_val = abstract_to_number(vm, arguments[3]);
        if vm.has_exception return .{};
    }

    min_val: float64 = 0.0;
    if arguments.count > 4 {
        min_val = abstract_to_number(vm, arguments[4]);
        if vm.has_exception return .{};
    }

    sec_val: float64 = 0.0;
    if arguments.count > 5 {
        sec_val = abstract_to_number(vm, arguments[5]);
        if vm.has_exception return .{};
    }

    ms_val: float64 = 0.0;
    if arguments.count > 6 {
        ms_val = abstract_to_number(vm, arguments[6]);
        if vm.has_exception return .{};
    }

    if isnan(y_val) || isnan(m_val) || isnan(d_val) || isnan(h_val) || isnan(min_val) || isnan(sec_val) || isnan(ms_val) ||
       isinf(y_val) || isinf(m_val) || isinf(d_val) || isinf(h_val) || isinf(min_val) || isinf(sec_val) || isinf(ms_val) {
        return .{ type = .NUMBER, number = FLOAT64_NAN };
    }

    y := cast(int) y_val;
    if y >= 0 && y <= 99 y += 1900;
    m := cast(int) m_val;
    d := cast(int) d_val;
    h := cast(int) h_val;
    min := cast(int) min_val;
    sec := cast(int) sec_val;
    ms := cast(int) ms_val;

    millis := compute_date_millis(y, m, d, h, min, sec, ms, .UTC);

    return .{ type = .NUMBER, number = millis };
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

Date_Components :: struct {
    year: int;
    month: int;       // 0..11
    day: int;         // 1..31
    day_of_week: int; // 0..6 (Sun=0, Mon=1, ...)
    hour: int;        // 0..23
    minute: int;      // 0..59
    second: int;      // 0..59
    millisecond: int; // 0..999
}

millis_to_components :: (millis: float64) -> Date_Components {
    comp: Date_Components;
    if isnan(millis) return comp;

    day := cast(int) floor(millis / 86400000.0);
    time := cast(int) fmod_cycling(millis, 86400000.0);
    if time < 0 time += 86400000;

    comp.hour = time / 3600000;
    time = time % 3600000;
    comp.minute = time / 60000;
    time = time % 60000;
    comp.second = time / 1000;
    comp.millisecond = time % 1000;

    dow := (day + 4) % 7;
    if dow < 0 dow += 7;
    comp.day_of_week = dow;

    y := 1970 + cast(int) floor(cast(float64) day / 365.2425);
    while days_from_year(y + 1) <= day y += 1;
    while days_from_year(y) > day y -= 1;
    comp.year = y;

    day_in_year := day - days_from_year(y);
    leap := is_leap_year(y);

    m := 11;
    while m > 0 && days_before_month(m, leap) > day_in_year m -= 1;
    comp.month = m;
    comp.day = day_in_year - days_before_month(m, leap) + 1;

    return comp;
}

format_year_string :: (year: int) -> string {
    if year < 0 {
        return tprint("-%", formatInt(-year, minimum_digits = 4));
    } else {
        return tprint("%", formatInt(year, minimum_digits = 4));
    }
}

date_get_time :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    return .{ type = .NUMBER, number = get_date_milliseconds(this) };
}

date_get_timezone_offset :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    millis := get_date_milliseconds(this);
    if isnan(millis) || isinf(millis) return .{ type = .NUMBER, number = FLOAT64_NAN };

    now := current_time_consensus();
    cal_utc := to_calendar(now, .UTC);
    cal_loc := to_calendar(now, .LOCAL);
    tz_offset_minutes := cast(float64) ((cal_utc.hour - cal_loc.hour) * 60 + (cal_utc.minute - cal_loc.minute));
    return .{ type = .NUMBER, number = tz_offset_minutes };
}

date_get_full_year :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    millis := get_date_milliseconds(this);
    if isnan(millis) || isinf(millis) return .{ type = .NUMBER, number = FLOAT64_NAN };
    comp := millis_to_components(millis);
    return .{ type = .NUMBER, number = cast(float64) comp.year };
}

date_get_month :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    millis := get_date_milliseconds(this);
    if isnan(millis) || isinf(millis) return .{ type = .NUMBER, number = FLOAT64_NAN };
    comp := millis_to_components(millis);
    return .{ type = .NUMBER, number = cast(float64) comp.month };
}

date_get_date :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    millis := get_date_milliseconds(this);
    if isnan(millis) || isinf(millis) return .{ type = .NUMBER, number = FLOAT64_NAN };
    comp := millis_to_components(millis);
    return .{ type = .NUMBER, number = cast(float64) comp.day };
}

date_get_hours :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    millis := get_date_milliseconds(this);
    if isnan(millis) || isinf(millis) return .{ type = .NUMBER, number = FLOAT64_NAN };
    comp := millis_to_components(millis);
    return .{ type = .NUMBER, number = cast(float64) comp.hour };
}

date_get_minutes :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    millis := get_date_milliseconds(this);
    if isnan(millis) || isinf(millis) return .{ type = .NUMBER, number = FLOAT64_NAN };
    comp := millis_to_components(millis);
    return .{ type = .NUMBER, number = cast(float64) comp.minute };
}

date_get_seconds :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    millis := get_date_milliseconds(this);
    if isnan(millis) || isinf(millis) return .{ type = .NUMBER, number = FLOAT64_NAN };
    comp := millis_to_components(millis);
    return .{ type = .NUMBER, number = cast(float64) comp.second };
}

date_get_milliseconds :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    millis := get_date_milliseconds(this);
    if isnan(millis) || isinf(millis) return .{ type = .NUMBER, number = FLOAT64_NAN };
    comp := millis_to_components(millis);
    return .{ type = .NUMBER, number = cast(float64) comp.millisecond };
}

date_to_string :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    millis := get_date_milliseconds(this);
    if isnan(millis) || isinf(millis) {
        s := copy_string("Invalid Date");
        table_set(*vm.allocated_strings, s.data, .{ s = s, marked = false });
        return .{ type = .STRING, s = s };
    }

    comp := millis_to_components(millis);

    month_str := ifx comp.month >= 0 && comp.month < 12 then MONTH_NAMES[comp.month] else "Jan";
    day_str   := ifx comp.day_of_week >= 0 && comp.day_of_week < 7 then DAY_NAMES[comp.day_of_week] else "Sun";
    year_str  := format_year_string(comp.year);

    s := sprint("% % % % %:%:% GMT", day_str, month_str, formatInt(comp.day, minimum_digits = 2), year_str, formatInt(comp.hour, minimum_digits = 2), formatInt(comp.minute, minimum_digits = 2), formatInt(comp.second, minimum_digits = 2));

    table_set(*vm.allocated_strings, s.data, .{ s = s, marked = false });

    return .{ type = .STRING, s = s };
}

date_to_iso_string :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    millis := get_date_milliseconds(this);
    if isnan(millis) || isinf(millis) {
        throw_exception(vm, "RangeError: Invalid time value");
        return .{};
    }

    comp := millis_to_components(millis);
    year_str := format_year_string(comp.year);

    s := sprint("%-%-%T%:%:%.%Z", year_str, formatInt(comp.month + 1, minimum_digits = 2), formatInt(comp.day, minimum_digits = 2), formatInt(comp.hour, minimum_digits = 2), formatInt(comp.minute, minimum_digits = 2), formatInt(comp.second, minimum_digits = 2), formatInt(comp.millisecond, minimum_digits = 3));

    table_set(*vm.allocated_strings, s.data, .{ s = s, marked = false });

    return .{ type = .STRING, s = s };
}

date_to_primitive :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if (this.type != .OBJECT && this.type != .ARRAY && this.type != .FUNCTION && this.type != .NATIVE_FUNCTION) || !this.object {
        throw_exception(vm, "TypeError: Date.prototype[Symbol.toPrimitive] called on non-object");
        return .{};
    }

    if arguments.count == 0 || arguments[0].type != .STRING {
        throw_exception(vm, "TypeError: Invalid hint for Date.prototype[Symbol.toPrimitive]");
        return .{};
    }

    hint := arguments[0].s;
    if hint != "string" && hint != "number" && hint != "default" {
        throw_exception(vm, "TypeError: Invalid hint for Date.prototype[Symbol.toPrimitive]");
        return .{};
    }

    try_first := ifx hint == "number" then "number" else "string";

    if try_first == "string" {
        found_fn, fn_val := lookup_property(vm, this.object, "toString");
        if vm.has_exception return .{};
        if found_fn && (fn_val.type == .FUNCTION || fn_val.type == .NATIVE_FUNCTION) {
            res := call_value(vm, this, fn_val, .[]);
            if vm.has_exception return .{};
            if res.type != .OBJECT && res.type != .ARRAY && res.type != .FUNCTION && res.type != .NATIVE_FUNCTION return res;
        }

        found_fn2, fn_val2 := lookup_property(vm, this.object, "valueOf");
        if vm.has_exception return .{};
        if found_fn2 && (fn_val2.type == .FUNCTION || fn_val2.type == .NATIVE_FUNCTION) {
            res := call_value(vm, this, fn_val2, .[]);
            if vm.has_exception return .{};
            if res.type != .OBJECT && res.type != .ARRAY && res.type != .FUNCTION && res.type != .NATIVE_FUNCTION return res;
        }
    } else {
        found_fn, fn_val := lookup_property(vm, this.object, "valueOf");
        if vm.has_exception return .{};
        if found_fn && (fn_val.type == .FUNCTION || fn_val.type == .NATIVE_FUNCTION) {
            res := call_value(vm, this, fn_val, .[]);
            if vm.has_exception return .{};
            if res.type != .OBJECT && res.type != .ARRAY && res.type != .FUNCTION && res.type != .NATIVE_FUNCTION return res;
        }

        found_fn2, fn_val2 := lookup_property(vm, this.object, "toString");
        if vm.has_exception return .{};
        if found_fn2 && (fn_val2.type == .FUNCTION || fn_val2.type == .NATIVE_FUNCTION) {
            res := call_value(vm, this, fn_val2, .[]);
            if vm.has_exception return .{};
            if res.type != .OBJECT && res.type != .ARRAY && res.type != .FUNCTION && res.type != .NATIVE_FUNCTION return res;
        }
    }

    throw_exception(vm, "TypeError: Cannot convert Date to primitive");
    return .{};
}
