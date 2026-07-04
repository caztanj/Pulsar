init_vm_array :: (vm: *Vm) {
    found, array_index := get_global_index(vm, "Array");

    if found {
        array_object := allocate_object(vm);

        vm.current_realm.globals[array_index].type   = .OBJECT;
        vm.current_realm.globals[array_index].object = array_object;

        array_prototype: *Gc_Object;

        if vm.array_prototype {
            array_prototype = vm.array_prototype;
        } else {
            array_prototype           = allocate_object(vm);
            array_prototype.prototype = vm.object_prototype;

            vm.array_prototype = array_prototype;

            add_instance_method(vm, array_prototype, "at",        array_at);
            add_instance_method(vm, array_prototype, "concat",    array_concat);
            add_instance_method(vm, array_prototype, "every",     array_every);
            add_instance_method(vm, array_prototype, "fill",      array_fill);
            add_instance_method(vm, array_prototype, "filter",    array_filter);
            add_instance_method(vm, array_prototype, "find",      array_find);
            add_instance_method(vm, array_prototype, "findIndex", array_find_index);
            add_instance_method(vm, array_prototype, "flat",      array_flat);
            add_instance_method(vm, array_prototype, "flatMap",   array_flat_map);
            add_instance_method(vm, array_prototype, "forEach",   array_for_each);
            add_instance_method(vm, array_prototype, "includes",  array_includes);
            add_instance_method(vm, array_prototype, "indexOf",   array_index_of);
            add_instance_method(vm, array_prototype, "join",      array_join);
            add_instance_method(vm, array_prototype, "map",       array_map);
            add_instance_method(vm, array_prototype, "pop",       array_pop);
            add_instance_method(vm, array_prototype, "push",      array_push);
            add_instance_method(vm, array_prototype, "reduce",    array_reduce);
            add_instance_method(vm, array_prototype, "reverse",   array_reverse);
            add_instance_method(vm, array_prototype, "shift",     array_shift);
            add_instance_method(vm, array_prototype, "slice",     array_slice);
            add_instance_method(vm, array_prototype, "some",      array_some);
            add_instance_method(vm, array_prototype, "sort",      array_sort);
            add_instance_method(vm, array_prototype, "splice",    array_splice);
            add_instance_method(vm, array_prototype, "unshift",   array_unshift);
        }

        add_static_method(vm, array_object, "from",    array_from);
        add_static_method(vm, array_object, "isArray", array_is_array);
        add_static_method(vm, array_object, "of",      array_of);

        prototype_value := Value.{
            type   = .OBJECT,
            object = array_prototype,
        };

        add_static_property(vm, array_object,    "prototype",   prototype_value);
        add_static_property(vm, array_prototype, "constructor", vm.current_realm.globals[array_index]);
    }
}

array_is_array :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .BOOLEAN, boolean = false };

    argument := arguments[0];

    return .{ type = .BOOLEAN, boolean = (argument.type == .ARRAY || (argument.type == .OBJECT && argument.object.kind == .ARRAY)) };
}

array_push :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if (this.type == .ARRAY || (this.type == .OBJECT && this.object.kind == .ARRAY)) && this.object {
        for arguments {
            array_add(*this.object.elements, it);
        }

        return .{ type = .NUMBER, number = cast(float64) this.object.elements.count };
    }

    return .{ type = .NUMBER, number = 0.0 };
}

array_pop :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if (this.type == .ARRAY || (this.type == .OBJECT && this.object.kind == .ARRAY)) && this.object {
        if this.object.elements.count > 0 {
            value                      := this.object.elements[this.object.elements.count - 1];
            this.object.elements.count -= 1;

            return value;
        }
    }

    return .{ type = .UNDEFINED };
}

array_join :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if (this.type == .ARRAY || (this.type == .OBJECT && this.object.kind == .ARRAY)) && this.object {
        separator := ",";

        if arguments.count > 0 && arguments[0].type == .STRING separator = arguments[0].s;

        builder: String_Builder;
        builder.allocator = temp;

        for this.object.elements {
            if it_index > 0 append(*builder, separator);
            append(*builder, value_to_string(vm, it));
        }

        result := builder_to_string(*builder);
        table_set(*vm.allocated_strings, result.data, .{ s = result, marked = false });

        return .{ type = .STRING, s = result };
    }

    return .{ type = .STRING, s = "" };
}

array_shift :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if (this.type == .ARRAY || (this.type == .OBJECT && this.object.kind == .ARRAY)) && this.object {
        if this.object.elements.count > 0 {
            value := this.object.elements[0];

            array_ordered_remove_by_index(*this.object.elements, 0);

            return value;
        }
    }

    return .{ type = .UNDEFINED };
}

array_unshift :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if (this.type == .ARRAY || (this.type == .OBJECT && this.object.kind == .ARRAY)) && this.object {
        for < i: arguments.count - 1..0 array_insert_at(*this.object.elements, arguments[i], 0);

        return .{ type = .NUMBER, number = cast(float64) this.object.elements.count };
    }

    return .{ type = .NUMBER, number = 0.0 };
}

array_index_of :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if (this.type == .ARRAY || (this.type == .OBJECT && this.object.kind == .ARRAY)) && this.object {
        if arguments.count == 0 return .{ type = .NUMBER, number = -1.0 };

        search_element := arguments[0];

        from_index := 0;
        if arguments.count > 1 && arguments[1].type == .NUMBER {
            from_index = cast(int) arguments[1].number;
            if from_index < 0 from_index = max(0, this.object.elements.count + from_index);
        }

        for i: from_index..this.object.elements.count-1 {
            if values_strict_equal(this.object.elements[i], search_element) return .{ type = .NUMBER, number = cast(float64) i };
        }
    }

    return .{ type = .NUMBER, number = -1.0 };
}

array_for_each :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if (this.type == .ARRAY || (this.type == .OBJECT && this.object.kind == .ARRAY)) && this.object {
        if arguments.count == 0 return .{ type = .UNDEFINED };

        callback := arguments[0];

        if callback.type != .FUNCTION && callback.type != .NATIVE_FUNCTION return .{ type = .UNDEFINED };

        this_argument := ifx arguments.count > 1 then arguments[1] else Value.{};

        object := this.object;

        for object.elements {
            arguments: [3] Value = .[
                it,
                .{ type = .NUMBER, number = cast(float64) it_index },
                this,
            ];

            call_value(vm, this_argument, callback, arguments);

            if vm.has_exception return .{};
        }
    }

    return .{ type = .UNDEFINED };
}

array_map :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if (this.type == .ARRAY || (this.type == .OBJECT && this.object.kind == .ARRAY)) && this.object {
        if arguments.count == 0 return .{ type = .UNDEFINED };

        callback := arguments[0];

        if callback.type != .FUNCTION && callback.type != .NATIVE_FUNCTION return .{ type = .UNDEFINED };

        this_argument := ifx arguments.count > 1 then arguments[1] else Value.{};

        object := this.object;

        result_object           := allocate_object(vm);
        result_object.kind       = .ARRAY;
        result_object.prototype  = vm.array_prototype;

        for object.elements {
            arguments: [3] Value = .[
                it,
                .{ type = .NUMBER, number = cast(float64) it_index },
                this,
            ];

            result := call_value(vm, this_argument, callback, arguments);

            if vm.has_exception return .{};

            array_add(*result_object.elements, result);
        }

        return .{ type = .ARRAY, object = result_object };
    }

    return .{ type = .UNDEFINED };
}

array_filter :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if (this.type == .ARRAY || (this.type == .OBJECT && this.object.kind == .ARRAY)) && this.object {
        if arguments.count == 0 return .{ type = .UNDEFINED };

        callback := arguments[0];

        if callback.type != .FUNCTION && callback.type != .NATIVE_FUNCTION return .{ type = .UNDEFINED };

        this_argument := ifx arguments.count > 1 then arguments[1] else Value.{};

        object := this.object;

        result_object           := allocate_object(vm);
        result_object.kind       = .ARRAY;
        result_object.prototype  = vm.array_prototype;

        for object.elements {
            arguments: [3] Value = .[
                it,
                .{ type = .NUMBER, number = cast(float64) it_index },
                this,
            ];

            result := call_value(vm, this_argument, callback, arguments);

            if vm.has_exception return .{};

            if is_truthy(result) array_add(*result_object.elements, it);
        }

        return .{ type = .ARRAY, object = result_object };
    }

    return .{ type = .UNDEFINED };
}

array_slice :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if (this.type == .ARRAY || (this.type == .OBJECT && this.object.kind == .ARRAY)) && this.object {
        object := this.object;

        start := 0;

        if arguments.count > 0 && arguments[0].type == .NUMBER {
            start = cast(int) arguments[0].number;
            if start < 0 start = max(0, object.elements.count + start);
        }

        end := object.elements.count;

        if arguments.count > 1 && arguments[1].type == .NUMBER {
            end = cast(int) arguments[1].number;
            if end < 0 end = object.elements.count + end;
        }

        start = clamp(start, 0, object.elements.count);
        end   = clamp(end, start, object.elements.count);

        result_object           := allocate_object(vm);
        result_object.kind       = .ARRAY;
        result_object.prototype  = vm.array_prototype;

        for start..end - 1 {
            array_add(*result_object.elements, object.elements[it]);
        }

        return .{ type = .ARRAY, object = result_object };
    }

    return .{ type = .UNDEFINED };
}

array_reduce :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if (this.type == .ARRAY || (this.type == .OBJECT && this.object.kind == .ARRAY)) && this.object {
        if arguments.count == 0 return .{ type = .UNDEFINED };

        callback := arguments[0];

        if callback.type != .FUNCTION && callback.type != .NATIVE_FUNCTION return .{ type = .UNDEFINED };

        object := this.object;

        if object.elements.count == 0 {
            if arguments.count >= 2 return arguments[1];
            return .{ type = .UNDEFINED };
        }

        accumulator: Value;
        start_index := 0;

        if arguments.count >= 2 {
            accumulator = arguments[1];
        } else {
            accumulator = object.elements[0];
            start_index = 1;
        }

        for start_index..object.elements.count - 1 {
            arguments: [4] Value = .[
                accumulator,
                object.elements[it],
                .{ type = .NUMBER, number = cast(float64) it },
                this,
            ];

            accumulator = call_value(vm, .{}, callback, arguments);

            if vm.has_exception return .{};
        }

        return accumulator;
    }

    return .{ type = .UNDEFINED };
}

array_every :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if (this.type == .ARRAY || (this.type == .OBJECT && this.object.kind == .ARRAY)) && this.object {
        if arguments.count == 0 return .{ type = .BOOLEAN, boolean = true };

        callback := arguments[0];

        if callback.type != .FUNCTION && callback.type != .NATIVE_FUNCTION return .{ type = .BOOLEAN, boolean = true };

        this_argument := ifx arguments.count > 1 then arguments[1] else Value.{};

        object := this.object;

        for object.elements {
            arguments: [3] Value = .[
                it,
                .{ type = .NUMBER, number = cast(float64) it_index },
                this,
            ];

            result := call_value(vm, this_argument, callback, arguments);

            if vm.has_exception return .{};

            if !is_truthy(result) return .{ type = .BOOLEAN, boolean = false };
        }
    }

    return .{ type = .BOOLEAN, boolean = true };
}

array_some :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if (this.type == .ARRAY || (this.type == .OBJECT && this.object.kind == .ARRAY)) && this.object {
        if arguments.count == 0 return .{ type = .BOOLEAN, boolean = false };

        callback := arguments[0];

        if callback.type != .FUNCTION && callback.type != .NATIVE_FUNCTION return .{ type = .BOOLEAN, boolean = false };

        this_argument := ifx arguments.count > 1 then arguments[1] else Value.{};

        object := this.object;

        for object.elements {
            arguments: [3] Value = .[
                it,
                .{ type = .NUMBER, number = cast(float64) it_index },
                this,
            ];

            result := call_value(vm, this_argument, callback, arguments);

            if vm.has_exception return .{};

            if is_truthy(result) return .{ type = .BOOLEAN, boolean = true };
        }
    }

    return .{ type = .BOOLEAN, boolean = false };
}

array_find :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if (this.type == .ARRAY || (this.type == .OBJECT && this.object.kind == .ARRAY)) && this.object {
        if arguments.count == 0 return .{ type = .UNDEFINED };

        callback := arguments[0];

        if callback.type != .FUNCTION && callback.type != .NATIVE_FUNCTION return .{ type = .UNDEFINED };

        this_argument := ifx arguments.count > 1 then arguments[1] else Value.{};

        object := this.object;

        for object.elements {
            arguments: [3] Value = .[
                it,
                .{ type = .NUMBER, number = cast(float64) it_index },
                this,
            ];

            result := call_value(vm, this_argument, callback, arguments);

            if vm.has_exception return .{};

            if is_truthy(result) return it;
        }
    }

    return .{ type = .UNDEFINED };
}

array_find_index :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if (this.type == .ARRAY || (this.type == .OBJECT && this.object.kind == .ARRAY)) && this.object {
        if arguments.count == 0 return .{ type = .NUMBER, number = -1.0 };

        callback := arguments[0];

        if callback.type != .FUNCTION && callback.type != .NATIVE_FUNCTION return .{ type = .NUMBER, number = -1.0 };

        this_argument := ifx arguments.count > 1 then arguments[1] else Value.{};

        object := this.object;

        for object.elements {
            arguments: [3] Value = .[
                it,
                .{ type = .NUMBER, number = cast(float64) it_index },
                this,
            ];

            result := call_value(vm, this_argument, callback, arguments);

            if vm.has_exception return .{};

            if is_truthy(result) return .{ type = .NUMBER, number = cast(float64) it_index };
        }
    }

    return .{ type = .NUMBER, number = -1.0 };
}

array_includes :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if (this.type == .ARRAY || (this.type == .OBJECT && this.object.kind == .ARRAY)) && this.object {
        if arguments.count == 0 return .{ type = .BOOLEAN, boolean = false };

        search_element := arguments[0];

        from_index := 0;

        if arguments.count > 1 && arguments[1].type == .NUMBER {
            from_index = cast(int) arguments[1].number;
            if from_index < 0 from_index = max(0, this.object.elements.count + from_index);
        }

        for from_index..this.object.elements.count - 1 {
            if values_strict_equal(this.object.elements[it], search_element) return .{ type = .BOOLEAN, boolean = true };
        }
    }

    return .{ type = .BOOLEAN, boolean = false };
}

array_sort :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if (this.type == .ARRAY || (this.type == .OBJECT && this.object.kind == .ARRAY)) && this.object {
        object := this.object;

        if object.elements.count <= 1 return this;

        compare_function := ifx arguments.count > 0 then arguments[0] else Value.{};

        quicksort(vm, object.elements, 0, object.elements.count - 1, compare_function);
    }

    return this;
}

quicksort :: (vm: *Vm, array: [] Value, low: int, high: int, compare_function: Value) {
    if low < high {
        p := partition(vm, array, low, high, compare_function);

        if vm.has_exception return;

        quicksort(vm, array, low, p, compare_function);

        if vm.has_exception return;

        quicksort(vm, array, p + 1, high, compare_function);
    }
}

partition :: (vm: *Vm, array: [] Value, low: int, high: int, compare_fn: Value) -> int {
    pivot := array[low + (high - low) / 2];

    i := low - 1;
    j := high + 1;

    while true {
        while true {
            i += 1;

            if compare_values_for_sort(vm, array[i], pivot, compare_fn) >= 0 break;
            if vm.has_exception return 0;
        }

        while true {
            j -= 1;
            if compare_values_for_sort(vm, array[j], pivot, compare_fn) <= 0 break;
            if vm.has_exception return 0;
        }

        if i >= j return j;

        temp := array[i];

        array[i] = array[j];
        array[j] = temp;
    }

    return 0;
}

compare_values_for_sort :: (vm: *Vm, v1: Value, v2: Value, compare_function: Value) -> int {
    if compare_function.type == .FUNCTION || compare_function.type == .NATIVE_FUNCTION {
        arguments: [2] Value = .[
            v1,
            v2,
        ];

        result := call_value(vm, .{}, compare_function, arguments);

        if vm.has_exception return 0;

        return cast(int) value_to_number(result);
    } else {
        s1 := value_to_string(vm, v1);
        s2 := value_to_string(vm, v2);

        return compare(s1, s2);
    }
}

array_reverse :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if (this.type == .ARRAY || (this.type == .OBJECT && this.object.kind == .ARRAY)) && this.object {
        object := this.object;

        for i: 0..object.elements.count / 2 - 1 {
            j := object.elements.count - 1 - i;

            temp := object.elements[i];

            object.elements[i] = object.elements[j];
            object.elements[j] = temp;
        }
    }

    return this;
}

array_concat :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    result_object           := allocate_object(vm);
    result_object.kind       = .ARRAY;
    result_object.prototype  = vm.array_prototype;

    if (this.type == .ARRAY || (this.type == .OBJECT && this.object.kind == .ARRAY)) && this.object {
        for this.object.elements array_add(*result_object.elements, it);
    } else {
        array_add(*result_object.elements, this);
    }

    for arguments {
        if (it.type == .ARRAY || (it.type == .OBJECT && it.object.kind == .ARRAY)) && it.object {
            for val: it.object.elements array_add(*result_object.elements, val);
        } else {
            array_add(*result_object.elements, it);
        }
    }

    return .{ type = .ARRAY, object = result_object };
}

array_splice :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if !(this.type == .ARRAY || (this.type == .OBJECT && this.object.kind == .ARRAY)) || !this.object return .{ type = .UNDEFINED };

    object := this.object;

    start := 0;

    if arguments.count > 0 {
        start = cast(int) value_to_number(arguments[0]);
        if   start < 0 start = max(0, object.elements.count + start);
        else           start = min(start, object.elements.count);
    }

    delete_count := object.elements.count - start;
    if arguments.count > 1 {
        delete_count = cast(int) value_to_number(arguments[1]);
        delete_count = clamp(delete_count, 0, object.elements.count - start);
    }

    removed_object           := allocate_object(vm);
    removed_object.kind       = .ARRAY;
    removed_object.prototype  = vm.array_prototype;

    for 0..delete_count - 1 array_add(*removed_object.elements, object.elements[start + it]);
    for 0..delete_count - 1 array_ordered_remove_by_index(*object.elements, start);

    if arguments.count > 2 {
        for 0..arguments.count - 3 array_insert_at(*object.elements, arguments[it + 2], start + it);
    }

    return .{ type = .ARRAY, object = removed_object };
}

array_at :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if !(this.type == .ARRAY || (this.type == .OBJECT && this.object.kind == .ARRAY)) || !this.object return .{ type = .UNDEFINED };

    object := this.object;

    if arguments.count == 0 return .{ type = .UNDEFINED };

    index := cast(int) value_to_number(arguments[0]);
    if index < 0 index = object.elements.count + index;

    if index < 0 || index >= object.elements.count return .{ type = .UNDEFINED };

    return object.elements[index];
}

array_fill :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if !(this.type == .ARRAY || (this.type == .OBJECT && this.object.kind == .ARRAY)) || !this.object {
        return this;
    }

    object := this.object;

    if arguments.count == 0 return this;

    value := arguments[0];
    start := 0;

    if arguments.count > 1 start = cast(int) value_to_number(arguments[1]);
    if start < 0           start = max(0, object.elements.count + start);
    else                   start = min(start, object.elements.count);

    end := object.elements.count;

    if arguments.count > 2 end = cast(int) value_to_number(arguments[2]);
    if                     end < 0 end = max(0, object.elements.count + end);
    else                   end = min(end, object.elements.count);

    for start..end - 1 object.elements[it] = value;

    return this;
}

array_from :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .ARRAY, object = allocate_object(vm) };

    array_like := arguments[0];

    result_object           := allocate_object(vm);
    result_object.kind       = .ARRAY;
    result_object.prototype  = vm.array_prototype;

    if array_like.type == .STRING {
        for 0..array_like.s.count - 1 {
            char           := slice(array_like.s, it, 1);
            allocated_char := copy_string(char);

            table_set(*vm.allocated_strings, allocated_char.data, .{ s = allocated_char, marked = false });
            array_add(*result_object.elements, .{ type = .STRING, s = allocated_char });
        }
    } else if (array_like.type == .OBJECT || array_like.type == .ARRAY) && array_like.object {
        found, length_value := lookup_property(vm, array_like.object, "length");

        length := 0;

        if found length = cast(int) value_to_number(length_value);

        for 0..length - 1 {
            builder: String_Builder;
            builder.allocator = temp;

            print_to_builder(*builder, "%", it);

            index_string := builder_to_string(*builder,, temp);

            found, value := lookup_property(vm, array_like.object, index_string);

            if found array_add(*result_object.elements, value);
            else     array_add(*result_object.elements, .{ type = .UNDEFINED });
        }
    }

    return .{ type = .ARRAY, object = result_object };
}

array_of :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    result_object           := allocate_object(vm);
    result_object.kind       = .ARRAY;
    result_object.prototype  = vm.array_prototype;

    for arguments array_add(*result_object.elements, it);

    return .{ type = .ARRAY, object = result_object };
}

array_flat :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if !(this.type == .ARRAY || (this.type == .OBJECT && this.object.kind == .ARRAY)) || !this.object return .{ type = .UNDEFINED };

    depth := 1;

    if arguments.count > 0 depth = cast(int) value_to_number(arguments[0]);

    result_object           := allocate_object(vm);
    result_object.kind       = .ARRAY;
    result_object.prototype  = vm.array_prototype;

    flatten(vm, result_object, this.object.elements, depth);

    return .{ type = .ARRAY, object = result_object };
}

flatten :: (vm: *Vm, target: *Gc_Object, source: [] Value, depth: int) {
    for source {
        if depth > 0 && (it.type == .ARRAY || (it.type == .OBJECT && it.object.kind == .ARRAY)) && it.object flatten(vm, target, it.object.elements, depth - 1);
        else                                                                                                 array_add(*target.elements, it);
    }
}

array_flat_map :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if !(this.type == .ARRAY || (this.type == .OBJECT && this.object.kind == .ARRAY)) || !this.object  return .{ type = .UNDEFINED };

    if arguments.count == 0 return .{ type = .UNDEFINED };

    callback := arguments[0];

    this_argument := ifx arguments.count > 1 then arguments[1] else Value.{};

    result_object           := allocate_object(vm);
    result_object.kind       = .ARRAY;
    result_object.prototype  = vm.array_prototype;

    object := this.object;

    for object.elements {
        arguments: [3] Value = .[
            it,
            .{ type = .NUMBER, number = cast(float64) it_index },
            this,
        ];

        result := call_value(vm, this_argument, callback, arguments);

        if vm.has_exception return .{};

        if (result.type == .ARRAY || (result.type == .OBJECT && result.object.kind == .ARRAY)) && result.object {
            for result.object.elements array_add(*result_object.elements, it);
        } else {
            array_add(*result_object.elements, result);
        }
    }

    return .{ type = .ARRAY, object = result_object };
}