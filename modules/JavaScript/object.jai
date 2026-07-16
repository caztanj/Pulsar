get_property_or_undefined :: inline (vm: *Vm, object: *Gc_Object, name: string, imm: int = -1) -> Value {
    found, result := lookup_property(vm, object, name, imm);
    if found return result;
    return .{ type = .UNDEFINED };
}

add_inline_cache :: inline (cache: *Inline_Cache, incoming_shape: *Shape, offset: s32, target_shape: *Shape = null) {
    count := cast(int)cache.count;
    if count >= PIC_SIZE return;

    for i: 0..count - 1 if cache.shapes[i] == incoming_shape return;

    cache.shapes[count]  = incoming_shape;
    cache.offsets[count] = offset;
    if target_shape cache.target_shapes[count] = target_shape;

    cache.count += 1;
}

lookup_property :: (vm: *Vm, object: *Gc_Object, name: string, imm: int = -1) -> found: bool, Value {
    is_all_digits := name.count > 0 && name[0] >= "0" && name[0] <= "9";

    if is_all_digits {
        for cast([] u8) name {
            if it < "0" || it > "9" {
                is_all_digits = false;
                break;
            }
        }
    }

    parsed_index := -1;

    if is_all_digits {
        name_copy       := name;
        parsed, success := parse_int(*name_copy);

        if success && parsed >= 0 parsed_index = parsed;
        else                      is_all_digits = false;
    }

    current := object;
    while current {
        if is_all_digits {
            if is_typed_array(current.kind) {
                len := get_typed_array_length(current);
                if parsed_index < len {
                    return true, .{ type = .NUMBER, number = get_typed_array_element(current, parsed_index) };
                }
            } else if parsed_index < current.elements.count {
                if current.elements[parsed_index].type != .UNDEFINED return true, current.elements[parsed_index];
            }
        } else {
            if name == "length" {
                if current.kind == .ARRAY return true, .{ type = .NUMBER, number = cast(float64) current.elements.count };
                if is_typed_array(current.kind) return true, .{ type = .NUMBER, number = cast(float64) get_typed_array_length(current) };
            }

            if current.shape {
                offset, found := shape_lookup_property(current.shape, name, imm);
                if found && offset < current.fields.count && current.fields[offset].type != .UNDEFINED return true, current.fields[offset];
            }
        }

        if current.kind == .GLOBAL_PROXY {
            found_global, global_idx := get_global_index(vm, name);
            if found_global && vm.current_realm.globals[global_idx].type != .UNDEFINED return true, vm.current_realm.globals[global_idx];
        }

        current = current.prototype;
    }

    return false, .{};
}

set_object_property :: (vm: *Vm, object: *Gc_Object, name: string, value: Value, imm: int = -1) {
    is_all_digits := name.count > 0 && name[0] >= "0" && name[0] <= "9";

    if is_all_digits {
        for cast([] u8) name {
            if it < "0" || it > "9" {
                is_all_digits = false;
                break;
            }
        }
    }

    if is_all_digits {
        name_copy       := name;
        parsed, success := parse_int(*name_copy);

        if success {
            if is_typed_array(object.kind) {
                len := get_typed_array_length(object);
                if parsed >= 0 && parsed < len {
                    set_typed_array_element(object, parsed, value_to_number(value));
                    return;
                }
            }

            while object.elements.count <= parsed array_add(*object.elements, .{});

            object.elements[parsed] = value;

            write_barrier(vm, object, value);

            return;
        }
    }

    if !object.shape object.shape = vm.root_shape;

    offset, found := shape_lookup_property(object.shape, name, imm);
    if !found {
        new_shape, new_offset := transition_shape(vm, object.shape, name);

        object.shape = new_shape;
        offset       = new_offset;
    }

    while object.fields.count <= offset array_add(*object.fields, .{});

    object.fields[offset] = value;

    write_barrier(vm, object, value);
}

add_instance_method :: (vm: *Vm, prototype: *Gc_Object, name: string, func: Native_Function) {
    value := Value.{
        type            = .NATIVE_FUNCTION,
        native_function = func,
    };

    set_object_property(vm, prototype, name, value);
}

add_static_method :: (vm: *Vm, object: *Gc_Object, name: string, func: Native_Function) {
    value := Value.{
        type            = .NATIVE_FUNCTION,
        native_function = func,
    };

    set_object_property(vm, object, name, value);
}

add_static_property :: (vm: *Vm, object: *Gc_Object, name: string, val: Value) {
    set_object_property(vm, object, name, val);
}

transition_shape :: (vm: *Vm, current_shape: *Shape, property_name: string) -> *Shape, int {
    next_shape_pointer := table_find_pointer(*current_shape.transitions, property_name);
    if next_shape_pointer return next_shape_pointer.*, current_shape.next_offset;

    new_shape := New(Shape);

    array_add(*vm.shapes, new_shape);

    for current_shape.property_names {
        array_add(*new_shape.property_names, it);

        old_offset := table_find_pointer(*current_shape.property_offsets, it).*;

        table_add(*new_shape.property_offsets, it, old_offset);
    }

    offset := current_shape.next_offset;

    array_add(*new_shape.property_names, property_name);
    table_add(*new_shape.property_offsets, property_name, offset);

    new_shape.next_offset = offset + 1;

    table_add(*current_shape.transitions, property_name, new_shape);

    return new_shape, offset;
}

shape_lookup_property :: inline (shape: *Shape, property_name: string, imm: int = -1) -> int, bool {
    if imm >= 0 {
        if imm >= shape.fast_offsets.count {
            old_count := shape.fast_offsets.count;

            array_resize(*shape.fast_offsets, imm + 1);

            for i: old_count..shape.fast_offsets.count - 1 shape.fast_offsets[i] = -1;
        }

        offset := shape.fast_offsets[imm];

        if offset >= 0 return offset, true;
        if offset == -2 return -1, false;

        offset_pointer := table_find_pointer(*shape.property_offsets, property_name);

        if offset_pointer {
            shape.fast_offsets[imm] = offset_pointer.*;

            return offset_pointer.*, true;
        } else {
            shape.fast_offsets[imm] = -2;

            return -1, false;
        }
    }

    offset_pointer := table_find_pointer(*shape.property_offsets, property_name);

    if offset_pointer return offset_pointer.*, true;

    return -1, false;
}

