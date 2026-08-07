init_vm_string :: (vm: *Vm) {
    found, index := get_global_index(vm, "String");

    if !vm.string_prototype {
        vm.string_prototype = allocate_object(vm);
        vm.string_prototype.prototype = vm.object_prototype;

        add_instance_method(vm, vm.string_prototype, "indexOf",     string_index_of);
        add_instance_method(vm, vm.string_prototype, "substring",   string_substring);
        add_instance_method(vm, vm.string_prototype, "toLowerCase", string_to_lower_case);
        add_instance_method(vm, vm.string_prototype, "toUpperCase", string_to_upper_case);
        add_instance_method(vm, vm.string_prototype, "charAt",      string_char_at);
        add_instance_method(vm, vm.string_prototype, "includes",    string_includes);
        add_instance_method(vm, vm.string_prototype, "repeat",      string_repeat);
        add_instance_method(vm, vm.string_prototype, "trim",        string_trim);
        add_instance_method(vm, vm.string_prototype, "split",       string_split);
        add_instance_method(vm, vm.string_prototype, "startsWith",  string_starts_with);
        add_instance_method(vm, vm.string_prototype, "endsWith",    string_ends_with);
        add_instance_method(vm, vm.string_prototype, "slice",       string_slice);
        add_instance_method(vm, vm.string_prototype, "replace",     string_replace);
        add_instance_method(vm, vm.string_prototype, "padStart",    string_pad_start);
        add_instance_method(vm, vm.string_prototype, "padEnd",      string_pad_end);
        add_instance_method(vm, vm.string_prototype, "trimStart",   string_trim_start);
        add_instance_method(vm, vm.string_prototype, "trimEnd",     string_trim_end);
        add_instance_method(vm, vm.string_prototype, "charCodeAt",   string_char_code_at);
        add_instance_method(vm, vm.string_prototype, "at",          string_at);
        add_instance_method(vm, vm.string_prototype, "concat",      string_concat);
        add_instance_method(vm, vm.string_prototype, "toString",    string_to_string);
        add_instance_method(vm, vm.string_prototype, "valueOf",     string_value_of);
    }

    if found {
        vm.current_realm.globals[index].type            = .NATIVE_FUNCTION;
        vm.current_realm.globals[index].native_function = string_constructor;

        string_object := allocate_object(vm);

        vm.current_realm.globals[index].object = string_object;

        string_object.prototype = vm.string_prototype;

        add_static_method(vm, string_object, "fromCharCode",  string_from_char_code);
        add_static_method(vm, string_object, "fromCodePoint", string_from_code_point);

        prototype_value := Value.{
            type   = .OBJECT,
            object = vm.string_prototype,
        };

        add_static_property(vm, string_object,       "prototype",   prototype_value);
        add_static_property(vm, vm.string_prototype, "constructor", vm.current_realm.globals[index]);
    }
}

string_constructor :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    string_value := "";

    if arguments.count > 0 {
        string_value = abstract_to_string(vm, arguments[0]);
        if vm.has_exception return .{};
    }

    if is_new {
        string_object := allocate_object(vm);

        string_object.kind            = .STRING_WRAPPER;
        string_object.primitive_value = .{ type = .STRING, s = string_value };
        string_object.prototype       = vm.string_prototype;

        return .{ type = .OBJECT, object = string_object };
    }

    return .{ type = .STRING, s = string_value };
}

string_index_of :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .STRING return .{ type = .NUMBER, number = -1.0 };
    if arguments.count == 0 return .{ type = .NUMBER, number = -1.0 };

    search_string := value_to_string(vm, arguments[0]);
    start_index   := 0;

    if arguments.count > 1 start_index = cast(int) value_to_number(arguments[1]);

    if start_index < 0 start_index = 0;

    if start_index >= this.s.count {
        if search_string == "" return .{ type = .NUMBER, number = cast(float64) this.s.count };
        return .{ type = .NUMBER, number = -1.0 };
    }

    substring := slice(this.s, start_index, this.s.count - start_index);
    index     := find_index_from_left(substring, search_string);

    if index == -1 return .{ type = .NUMBER, number = -1.0 };

    return .{ type = .NUMBER, number = cast(float64) (index + start_index) };
}

string_substring :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .STRING return .{ type = .UNDEFINED };
    if arguments.count == 0 return this;

    start := cast(int) value_to_number(arguments[0]);
    end   := this.s.count;

    if arguments.count > 1 end = cast(int) value_to_number(arguments[1]);

    if start < 0 start = 0;
    if end < 0   end = 0;

    if start > this.s.count start = this.s.count;
    if end > this.s.count   end = this.s.count;

    if start > end {
        temp := start;

        start = end;
        end   = temp;
    }

    result           := slice(this.s, start, end - start);
    allocated_result := copy_string(result);

    table_set(*vm.allocated_strings, allocated_result.data, .{ s = allocated_result, marked = false });

    return .{ type = .STRING, s = allocated_result };
}

string_to_lower_case :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .STRING return .{ type = .UNDEFINED };

    result := to_lower_copy(this.s);

    table_set(*vm.allocated_strings, result.data, .{ s = result, marked = false });

    return .{ type = .STRING, s = result };
}

string_to_upper_case :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .STRING return .{ type = .UNDEFINED };

    result := to_upper_copy(this.s);

    table_set(*vm.allocated_strings, result.data, .{ s = result, marked = false });

    return .{ type = .STRING, s = result };
}

string_char_at :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .STRING return .{ type = .STRING, s = "" };

    index := 0;

    if arguments.count > 0 index = cast(int) value_to_number(arguments[0]);

    if index < 0 || index >= this.s.count return .{ type = .STRING, s = "" };

    result           := slice(this.s, index, 1);
    allocated_result := copy_string(result);

    table_set(*vm.allocated_strings, allocated_result.data, .{ s = allocated_result, marked = false });

    return .{ type = .STRING, s = allocated_result };
}

string_includes :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .STRING return .{ type = .BOOLEAN, boolean = false };
    if arguments.count == 0 return .{ type = .BOOLEAN, boolean = false };

    search_string := value_to_string(vm, arguments[0]);
    index         := find_index_from_left(this.s, search_string);

    return .{ type = .BOOLEAN, boolean = index != -1 };
}

string_repeat :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .STRING return .{ type = .UNDEFINED };

    count := 0;

    if arguments.count > 0 {
        count_f := value_to_number(arguments[0]);
        if isinf(count_f) || count_f < 0 {
            throw_exception(vm, "RangeError: Invalid count value");
            return .{};
        }
        if isnan(count_f) then count_f = 0;
        count = cast(int) count_f;
    }

    if count == 0 || this.s.count == 0 {
        return .{ type = .STRING, s = "" };
    }

    builder: String_Builder;
    builder.allocator = temp;

    for 1..count append(*builder, this.s);

    result := builder_to_string(*builder);

    table_set(*vm.allocated_strings, result.data, .{ s = result, marked = false });

    return .{ type = .STRING, s = result };
}

string_trim :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .STRING return .{ type = .UNDEFINED };

    result           := trim(this.s);
    allocated_result := copy_string(result);

    table_set(*vm.allocated_strings, allocated_result.data, .{ s = allocated_result, marked = false });

    return .{ type = .STRING, s = allocated_result };
}

string_split :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .STRING return .{ type = .UNDEFINED };

    separator := "";
    if arguments.count > 0 separator = value_to_string(vm, arguments[0]);

    object := allocate_object(vm);

    object.kind      = .ARRAY;
    object.prototype = vm.array_prototype;

    if separator == "" {
        for 0..this.s.count-1 {
            char           := slice(this.s, it, 1);
            allocated := copy_string(char);

            table_set(*vm.allocated_strings, allocated.data, .{ s = allocated, marked = false });
            array_add(*object.elements,      .{ type = .STRING, s = allocated });
        }
    } else {
        parts := split(this.s, separator,, temp);

        for parts {
            allocated_part := copy_string(it);

            table_set(*vm.allocated_strings, allocated_part.data, .{ s = allocated_part, marked = false });
            array_add(*object.elements,      .{ type = .STRING, s = allocated_part });
        }
    }

    return .{ type = .ARRAY, object = object };
}

string_starts_with :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .STRING return .{ type = .BOOLEAN, boolean = false };
    if arguments.count == 0 return .{ type = .BOOLEAN, boolean = false };

    search_string := value_to_string(vm, arguments[0]);
    position      := 0;

    if arguments.count > 1 position = cast(int) value_to_number(arguments[1]);

    if position < 0            position = 0;
    if position > this.s.count return .{ type = .BOOLEAN, boolean = false };

    substring := slice(this.s, position, this.s.count - position);

    return .{ type = .BOOLEAN, boolean = starts_with(substring, search_string) };
}

string_ends_with :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .STRING return .{ type = .BOOLEAN, boolean = false };
    if arguments.count == 0 return .{ type = .BOOLEAN, boolean = false };

    search_string := value_to_string(vm, arguments[0]);
    end_position  := this.s.count;

    if arguments.count > 1 end_position = cast(int) value_to_number(arguments[1]);

    if end_position < 0            end_position = 0;
    if end_position > this.s.count end_position = this.s.count;

    substring := slice(this.s, 0, end_position);

    return .{ type = .BOOLEAN, boolean = ends_with(substring, search_string) };
}

string_slice :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .STRING return .{ type = .UNDEFINED };
    if arguments.count == 0 return this;

    start := cast(int) value_to_number(arguments[0]);

    if start < 0            start = max(0, this.s.count + start);
    if start > this.s.count start = this.s.count;

    end := this.s.count;

    if arguments.count > 1 {
        end = cast(int) value_to_number(arguments[1]);

        if end < 0            end = max(0, this.s.count + end);
        if end > this.s.count end = this.s.count;
    }

    if start >= end return .{ type = .STRING, s = "" };

    result           := slice(this.s, start, end - start);
    allocated_result := copy_string(result);

    table_set(*vm.allocated_strings, allocated_result.data, .{ s = allocated_result, marked = false });

    return .{ type = .STRING, s = allocated_result };
}

string_replace :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .STRING return .{ type = .UNDEFINED };
    if arguments.count < 2 return this;

    search_value  := value_to_string(vm, arguments[0]);
    replace_value := value_to_string(vm, arguments[1]);

    index := find_index_from_left(this.s, search_value);
    if index == -1 return this;

    builder: String_Builder;
    builder.allocator = temp;

    append(*builder, slice(this.s, 0, index));
    append(*builder, replace_value);
    append(*builder, slice(this.s, index + search_value.count, this.s.count - (index + search_value.count)));

    result := builder_to_string(*builder);

    table_set(*vm.allocated_strings, result.data, .{ s = result, marked = false });

    return .{ type = .STRING, s = result };
}

string_pad_start :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .STRING return .{ type = .UNDEFINED };
    if arguments.count == 0 return this;

    target_length := cast(int) value_to_number(arguments[0]);
    if target_length <= this.s.count return this;

    padding_string := " ";

    if arguments.count > 1 {
        padding_string = value_to_string(vm, arguments[1]);
        if padding_string == "" return this;
    }

    needed := target_length - this.s.count;

    builder: String_Builder;
    builder.allocator = temp;

    while needed > 0 {
        if needed >= padding_string.count {
            append(*builder, padding_string);
            needed -= padding_string.count;
        } else {
            append(*builder, slice(padding_string, 0, needed));
            needed = 0;
        }
    }

    append(*builder, this.s);

    result := builder_to_string(*builder);

    table_set(*vm.allocated_strings, result.data, .{ s = result, marked = false });

    return .{ type = .STRING, s = result };
}

string_pad_end :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .STRING return .{ type = .UNDEFINED };
    if arguments.count == 0 return this;

    target_length := cast(int) value_to_number(arguments[0]);
    if target_length <= this.s.count return this;

    padding_string := " ";

    if arguments.count > 1 {
        padding_string = value_to_string(vm, arguments[1]);
        if padding_string == "" return this;
    }

    needed := target_length - this.s.count;

    builder: String_Builder;
    builder.allocator = temp;

    append(*builder, this.s);

    while needed > 0 {
        if needed >= padding_string.count {
            append(*builder, padding_string);
            needed -= padding_string.count;
        } else {
            append(*builder, slice(padding_string, 0, needed));
            needed = 0;
        }
    }

    result := builder_to_string(*builder);

    table_set(*vm.allocated_strings, result.data, .{ s =result, marked = false });

    return .{ type = .STRING, s = result };
}

string_trim_start :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .STRING return .{ type = .UNDEFINED };

    result           := trim_left(this.s);
    allocated_result := copy_string(result);

    table_set(*vm.allocated_strings, allocated_result.data, .{ s = allocated_result, marked = false });

    return .{ type = .STRING, s = allocated_result };
}

string_trim_end :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .STRING return .{ type = .UNDEFINED };

    result           := trim_right(this.s);
    allocated_result := copy_string(result);

    table_set(*vm.allocated_strings, allocated_result.data, .{ s = allocated_result, marked = false });

    return .{ type = .STRING, s = allocated_result };
}

string_at :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .STRING return .{ type = .UNDEFINED };
    if arguments.count == 0 return .{ type = .UNDEFINED };

    index := cast(int) value_to_number(arguments[0]);
    if index < 0 index = this.s.count + index;

    if index < 0 || index >= this.s.count return .{ type = .UNDEFINED };

    result           := slice(this.s, index, 1);
    allocated_result := copy_string(result);

    table_set(*vm.allocated_strings, allocated_result.data, .{ s = allocated_result, marked = false});

    return .{ type = .STRING, s = allocated_result };
}

string_to_string :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.kind == .STRING_WRAPPER return this.object.primitive_value;
    if this.type == .STRING return this;

    throw_exception(vm, "TypeError: String.prototype.toString requires that 'this' be a String");
    return .{};
}

string_value_of :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.kind == .STRING_WRAPPER return this.object.primitive_value;
    if this.type == .STRING return this;

    throw_exception(vm, "TypeError: String.prototype.valueOf requires that 'this' be a String");
    return .{};
}

string_concat :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type == .UNDEFINED || this.type == .NULL {
        throw_exception(vm, "TypeError: String.prototype.concat called on null or undefined");
        return .{};
    }
    this_str := abstract_to_string(vm, this);
    if vm.has_exception return .{};

    builder: String_Builder;
    append(*builder, this_str);

    for arg: arguments {
        arg_str := abstract_to_string(vm, arg);
        if vm.has_exception {
            free_buffers(*builder);
            return .{};
        }
        append(*builder, arg_str);
    }

    res := allocate_string_from_builder(vm, *builder);
    free_buffers(*builder);
    return .{ type = .STRING, s = res };
}

string_char_code_at :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .STRING return .{ type = .NUMBER, number = not_a_number_value };
    index := 0;
    if arguments.count > 0 index = cast(int) value_to_number(arguments[0]);
    if index < 0 || index >= this.s.count return .{ type = .NUMBER, number = not_a_number_value };
    return .{ type = .NUMBER, number = cast(float64) cast(u8) this.s[index] };
}

string_from_char_code :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    builder: String_Builder;
    for arg: arguments {
        num := value_to_number(arg);
        if isnan(num) || isinf(num) then num = 0;
        code_unit := cast(u16) ((cast(int) num) & 0xFFFF);
        if code_unit < 0x80 {
            append(*builder, cast(u8) code_unit);
        } else if code_unit < 0x800 {
            append(*builder, cast(u8) (0xC0 | (code_unit >> 6)));
            append(*builder, cast(u8) (0x80 | (code_unit & 0x3F)));
        } else {
            append(*builder, cast(u8) (0xE0 | (code_unit >> 12)));
            append(*builder, cast(u8) (0x80 | ((code_unit >> 6) & 0x3F)));
            append(*builder, cast(u8) (0x80 | (code_unit & 0x3F)));
        }
    }
    res := allocate_string_from_builder(vm, *builder);
    free_buffers(*builder);
    return .{ type = .STRING, s = res };
}

string_from_code_point :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    builder: String_Builder;
    for arg: arguments {
        num := value_to_number(arg);
        if isnan(num) || isinf(num) || num < 0 || num > 0x10FFFF || (num != floor(num)) {
            throw_exception(vm, "RangeError: Invalid code point");
            free_buffers(*builder);
            return .{};
        }
        cp := cast(u32) num;
        if cp < 0x80 {
            append(*builder, cast(u8) cp);
        } else if cp < 0x800 {
            append(*builder, cast(u8) (0xC0 | (cp >> 6)));
            append(*builder, cast(u8) (0x80 | (cp & 0x3F)));
        } else if cp < 0x10000 {
            append(*builder, cast(u8) (0xE0 | (cp >> 12)));
            append(*builder, cast(u8) (0x80 | ((cp >> 6) & 0x3F)));
            append(*builder, cast(u8) (0x80 | (cp & 0x3F)));
        } else if cp <= 0x10FFFF {
            append(*builder, cast(u8) (0xF0 | (cp >> 18)));
            append(*builder, cast(u8) (0x80 | ((cp >> 12) & 0x3F)));
            append(*builder, cast(u8) (0x80 | ((cp >> 6) & 0x3F)));
            append(*builder, cast(u8) (0x80 | (cp & 0x3F)));
        }
    }
    res := allocate_string_from_builder(vm, *builder);
    free_buffers(*builder);
    return .{ type = .STRING, s = res };
}
