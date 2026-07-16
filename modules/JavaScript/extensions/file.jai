init_vm_file :: (vm: *Vm) {
    found, index := get_global_index(vm, "File");

    if found {
        file_object := allocate_object(vm);

        vm.current_realm.globals[index].type   = .OBJECT;
        vm.current_realm.globals[index].object = file_object;

        add_static_method(vm, file_object, "read_entire_file", file_read_entire_file);
        add_static_method(vm, file_object, "write_entire_file", file_write_entire_file);
        add_static_method(vm, file_object, "append_to_file", file_append_to_file);
        add_static_method(vm, file_object, "delete", file_delete_file);
        add_static_method(vm, file_object, "exists", file_exists_func);
        add_static_method(vm, file_object, "is_directory", file_is_directory);
        add_static_method(vm, file_object, "list_directory", file_list_directory);
        add_static_method(vm, file_object, "copy", file_copy);
        add_static_method(vm, file_object, "move", file_move);
        add_static_method(vm, file_object, "get_size", file_get_size);
    }
}

file_read_entire_file :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool = false) -> Value {
    if !(vm.permissions & .FILESYSTEM) {
        throw_exception(vm, "Permission denied: Requires FILESYSTEM permission.");
        return .{};
    }

    if arguments.count < 1 {
        throw_exception(vm, "read_entire_file requires 1 argument");
        return .{};
    }

    path_arg := arguments[0];
    if path_arg.type != .STRING {
        throw_exception(vm, "read_entire_file requires a string argument");
        return .{};
    }

    path := path_arg.s;

    file_content, success := read_entire_file(path);
    if !success {
        throw_exception(vm, tprint("Failed to read file: %", path));
        return .{};
    }

    is_binary := false;
    if arguments.count >= 2 && arguments[1].type == .BOOLEAN {
        is_binary = arguments[1].boolean;
    }

    if is_binary {
        object := allocate_object(vm);
        object.kind = .UINT8_ARRAY;
        object.prototype = vm.uint8_array_prototype;
        object.primitive_value = .{ type = .STRING, s = file_content };
        return .{ type = .OBJECT, object = object };
    }

    result := allocate_string(vm, file_content);
    free(file_content.data);
    return .{ type = .STRING, s = result };
}

file_write_entire_file :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool = false) -> Value {
    if !(vm.permissions & .FILESYSTEM) {
        throw_exception(vm, "Permission denied: Requires FILESYSTEM permission.");
        return .{};
    }

    if arguments.count < 2 {
        throw_exception(vm, "write_entire_file requires 2 arguments");
        return .{};
    }

    if arguments[0].type != .STRING {
        throw_exception(vm, "write_entire_file path must be a string");
        return .{};
    }

    path := arguments[0].s;
    data := arguments[1];

    content: string;

    if data.type == .STRING {
        content = data.s;
    } else if data.type == .OBJECT && is_typed_array(data.object.kind) {
        content = data.object.primitive_value.s;
    } else {
        throw_exception(vm, "write_entire_file data must be a string or TypedArray");
        return .{};
    }

    success := write_entire_file(path, content);
    if !success {
        throw_exception(vm, tprint("Failed to write to file: %", path));
        return .{};
    }

    return .{ type = .BOOLEAN, boolean = true };
}

file_append_to_file :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool = false) -> Value {
    if !(vm.permissions & .FILESYSTEM) {
        throw_exception(vm, "Permission denied: Requires FILESYSTEM permission.");
        return .{};
    }

    if arguments.count < 2 {
        throw_exception(vm, "append_to_file requires 2 arguments");
        return .{};
    }

    if arguments[0].type != .STRING {
        throw_exception(vm, "append_to_file path must be a string");
        return .{};
    }

    path := arguments[0].s;
    data := arguments[1];

    content: string;

    if data.type == .STRING {
        content = data.s;
    } else if data.type == .OBJECT && is_typed_array(data.object.kind) {
        content = data.object.primitive_value.s;
    } else {
        throw_exception(vm, "append_to_file data must be a string or TypedArray");
        return .{};
    }

    file, success := file_open(path, for_writing = true, keep_existing_content = true);
    if !success {
        throw_exception(vm, tprint("Failed to open file for appending: %", path));
        return .{};
    }

    defer file_close(*file);

    length, length_success := file_length(file);
    if length_success file_set_position(file, length);

    write_success := file_write(*file, content.data, content.count);
    if !write_success {
        throw_exception(vm, tprint("Failed to write to file: %", path));
        return .{};
    }

    return .{ type = .BOOLEAN, boolean = true };
}

file_delete_file :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool = false) -> Value {
    if !(vm.permissions & .FILESYSTEM) {
        throw_exception(vm, "Permission denied: Requires FILESYSTEM permission.");
        return .{};
    }

    if arguments.count < 1 || arguments[0].type != .STRING {
        throw_exception(vm, "delete requires a string argument");
        return .{};
    }

    success := file_delete(arguments[0].s);

    return .{ type = .BOOLEAN, boolean = success };
}

file_exists_func :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool = false) -> Value {
    if !(vm.permissions & .FILESYSTEM) {
        throw_exception(vm, "Permission denied: Requires FILESYSTEM permission.");
        return .{};
    }

    if arguments.count < 1 || arguments[0].type != .STRING {
        throw_exception(vm, "exists requires a string argument");
        return .{};
    }

    success := file_exists(arguments[0].s);

    return .{ type = .BOOLEAN, boolean = success };
}

file_is_directory :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool = false) -> Value {
    if !(vm.permissions & .FILESYSTEM) {
        throw_exception(vm, "Permission denied: Requires FILESYSTEM permission.");
        return .{};
    }

    if arguments.count < 1 || arguments[0].type != .STRING {
        throw_exception(vm, "is_directory requires a string argument");
        return .{};
    }

    success := is_directory(arguments[0].s);

    return .{ type = .BOOLEAN, boolean = success };
}

file_list_directory :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool = false) -> Value {
    if !(vm.permissions & .FILESYSTEM) {
        throw_exception(vm, "Permission denied: Requires FILESYSTEM permission.");
        return .{};
    }

    if arguments.count < 1 || arguments[0].type != .STRING {
        throw_exception(vm, "list_directory requires a string argument");
        return .{};
    }

    files := file_list(arguments[0].s);

    result_object           := allocate_object(vm);
    result_object.kind       = .ARRAY;
    result_object.prototype  = vm.array_prototype;

    for files {
        alloc_str := copy_string(it);
        table_set(*vm.allocated_strings, alloc_str.data, .{ s = alloc_str, marked = false });
        array_add(*result_object.elements, .{ type = .STRING, s = alloc_str });
    }

    for files free(it);
    array_free(files);

    return .{ type = .ARRAY, object = result_object };
}

file_copy :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool = false) -> Value {
    if !(vm.permissions & .FILESYSTEM) {
        throw_exception(vm, "Permission denied: Requires FILESYSTEM permission.");
        return .{};
    }

    if arguments.count < 2 || arguments[0].type != .STRING || arguments[1].type != .STRING {
        throw_exception(vm, "copy requires 2 string arguments");
        return .{};
    }

    success := copy_file(arguments[0].s, arguments[1].s);

    return .{ type = .BOOLEAN, boolean = success };
}

file_move :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool = false) -> Value {
    if !(vm.permissions & .FILESYSTEM) {
        throw_exception(vm, "Permission denied: Requires FILESYSTEM permission.");
        return .{};
    }

    if arguments.count < 2 || arguments[0].type != .STRING || arguments[1].type != .STRING {
        throw_exception(vm, "move requires 2 string arguments");
        return .{};
    }

    success := copy_file(arguments[0].s, arguments[1].s);
    if success {
        file_delete(arguments[0].s);
    }

    return .{ type = .BOOLEAN, boolean = success };
}

file_get_size :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool = false) -> Value {
    if !(vm.permissions & .FILESYSTEM) {
        throw_exception(vm, "Permission denied: Requires FILESYSTEM permission.");
        return .{};
    }

    if arguments.count < 1 || arguments[0].type != .STRING {
        throw_exception(vm, "get_size requires a string argument");
        return .{};
    }

    file, success := file_open(arguments[0].s, for_writing = false);
    if !success {
        throw_exception(vm, tprint("Failed to open file: %", arguments[0].s));
        return .{};
    }

    defer file_close(*file);

    length, length_success := file_length(file);
    if !length_success {
        throw_exception(vm, tprint("Failed to get file length: %", arguments[0].s));
        return .{};
    }

    return .{ type = .NUMBER, number = cast(float64) length };
}
