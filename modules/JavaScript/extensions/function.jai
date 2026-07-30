init_vm_function :: (vm: *Vm) {
    if !vm.function_prototype {
        vm.function_prototype = allocate_object(vm);
        vm.function_prototype.prototype = vm.object_prototype;

        add_instance_method(vm, vm.function_prototype, "call", function_call);
        add_instance_method(vm, vm.function_prototype, "bind", function_bind);

        vm.async_function_prototype = allocate_object(vm);
        vm.async_function_prototype.prototype = vm.function_prototype;

        symbol_tag_val := Value.{ type = .STRING, s = "AsyncFunction" };
        set_object_property(vm, vm.async_function_prototype, "@@Symbol.toStringTag", symbol_tag_val);

        vm.generator_function_prototype = allocate_object(vm);
        vm.generator_function_prototype.prototype = vm.function_prototype;

        generator_prototype := allocate_object(vm);
        generator_prototype.prototype = vm.object_prototype;
        vm.generator_prototype = generator_prototype;
        set_object_property(vm, generator_prototype, "constructor", Value.{ type = .OBJECT, object = vm.generator_function_prototype });
        set_object_property(vm, vm.generator_function_prototype, "prototype", Value.{ type = .OBJECT, object = generator_prototype });
        set_object_property(vm, vm.generator_function_prototype, "@@Symbol.toStringTag", Value.{ type = .STRING, s = "GeneratorFunction" });

        vm.async_generator_function_prototype = allocate_object(vm);
        vm.async_generator_function_prototype.prototype = vm.function_prototype;

        async_generator_prototype := allocate_object(vm);
        async_generator_prototype.prototype = vm.object_prototype;
        vm.async_generator_prototype = async_generator_prototype;
        set_object_property(vm, async_generator_prototype, "constructor", Value.{ type = .OBJECT, object = vm.async_generator_function_prototype });
        set_object_property(vm, vm.async_generator_function_prototype, "prototype", Value.{ type = .OBJECT, object = async_generator_prototype });
        set_object_property(vm, vm.async_generator_function_prototype, "@@Symbol.toStringTag", Value.{ type = .STRING, s = "AsyncGeneratorFunction" });
    }

    vm.current_realm.async_function_prototype = vm.async_function_prototype;
    vm.current_realm.generator_function_prototype = vm.generator_function_prototype;
    vm.current_realm.async_generator_function_prototype = vm.async_generator_function_prototype;

    function_constructor_object := allocate_object(vm);
    function_constructor_object.prototype = vm.function_prototype;
    vm.function_constructor_object = function_constructor_object;

    set_object_property(vm, function_constructor_object, "prototype", Value.{ type = .OBJECT, object = vm.function_prototype });
    set_object_property(vm, function_constructor_object, "name", Value.{ type = .STRING, s = "Function" });

    found, index := get_global_index(vm, "Function");
    if found {
        vm.current_realm.globals[index] = Value.{
            type = .NATIVE_FUNCTION,
            native_function = function_constructor,
            object = function_constructor_object,
        };
        set_object_property(vm, vm.function_prototype, "constructor", vm.current_realm.globals[index]);
    }

    async_function_constructor_object := allocate_object(vm);
    async_function_constructor_object.prototype = function_constructor_object;
    vm.async_function_constructor_object = async_function_constructor_object;

    async_func_val := Value.{
        type = .NATIVE_FUNCTION,
        native_function = function_constructor,
        object = async_function_constructor_object,
    };
    set_object_property(vm, async_function_constructor_object, "prototype", Value.{ type = .OBJECT, object = vm.async_function_prototype });
    set_object_property(vm, async_function_constructor_object, "name", Value.{ type = .STRING, s = "AsyncFunction" });
    set_object_property(vm, async_function_constructor_object, "length", Value.{ type = .NUMBER, number = 1 });

    set_object_property(vm, vm.async_function_prototype, "constructor", async_func_val);

    generator_function_constructor_object := allocate_object(vm);
    generator_function_constructor_object.prototype = function_constructor_object;
    vm.generator_function_constructor_object = generator_function_constructor_object;

    gen_func_val := Value.{
        type = .NATIVE_FUNCTION,
        native_function = function_constructor,
        object = generator_function_constructor_object,
    };

    set_object_property(vm, generator_function_constructor_object, "prototype", Value.{ type = .OBJECT, object = vm.generator_function_prototype });
    set_object_property(vm, generator_function_constructor_object, "name", Value.{ type = .STRING, s = "GeneratorFunction" });
    set_object_property(vm, generator_function_constructor_object, "length", Value.{ type = .NUMBER, number = 1 });

    set_object_property(vm, vm.generator_function_prototype, "constructor", gen_func_val);

    async_generator_function_constructor_object := allocate_object(vm);
    async_generator_function_constructor_object.prototype = function_constructor_object;
    vm.async_generator_function_constructor_object = async_generator_function_constructor_object;

    async_gen_func_val := Value.{
        type = .NATIVE_FUNCTION,
        native_function = function_constructor,
        object = async_generator_function_constructor_object,
    };

    set_object_property(vm, async_generator_function_constructor_object, "prototype", Value.{ type = .OBJECT, object = vm.async_generator_function_prototype });
    set_object_property(vm, async_generator_function_constructor_object, "name", Value.{ type = .STRING, s = "AsyncGeneratorFunction" });
    set_object_property(vm, async_generator_function_constructor_object, "length", Value.{ type = .NUMBER, number = 1 });

    set_object_property(vm, vm.async_generator_function_prototype, "constructor", async_gen_func_val);
}

function_constructor :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    callee_name := "";
    if vm.current_native_callee.type == .NATIVE_FUNCTION && vm.current_native_callee.object {
        found_name, name_val := lookup_property(vm, vm.current_native_callee.object, "name");
        if found_name && name_val.type == .STRING callee_name = name_val.s;
    }

    is_async_gen := (callee_name == "AsyncGeneratorFunction");
    is_async := is_async_gen || (callee_name == "AsyncFunction");
    is_gen := is_async_gen || (callee_name == "GeneratorFunction");

    body_str := "";
    params_str := "";

    if arguments.count > 0 {
        body_str = value_to_string(vm, arguments[arguments.count - 1]);
    }

    param_count := 0;
    if arguments.count > 1 {
        builder: String_Builder;
        builder.allocator = temp;
        for i: 0..arguments.count - 2 {
            if i > 0 append(*builder, ", ");
            s := value_to_string(vm, arguments[i]);
            append(*builder, s);
            parts := split(s, ",");
            defer array_free(parts);
            for parts {
                trimmed := trim(it);
                if trimmed.count > 0 param_count += 1;
            }
        }
        params_str = builder_to_string(*builder);
    }

    code_str := "";
    if is_async && is_gen {
        code_str = tprint("async function* anonymous(%) {\n%\n}", params_str, body_str);
    } else if is_async {
        code_str = tprint("async function anonymous(%) {\n%\n}", params_str, body_str);
    } else if is_gen {
        code_str = tprint("function* anonymous(%) {\n%\n}", params_str, body_str);
    } else {
        code_str = tprint("function anonymous(%) {\n%\n}", params_str, body_str);
    }

    ast: *Ast_Program;
    {
        state := get_temporary_storage_mark();
        defer set_temporary_storage_mark(state);

        has_error, error_msg, tokens := tokenize(code_str);
        if has_error {
            throw_exception(vm, tprint("SyntaxError: %", error_msg));
            return .{};
        }

        ast_temp := build_ast(code_str, tokens);
        if ast_temp.has_error {
            throw_exception(vm, tprint("SyntaxError: %", ast_temp.error_message));
            return .{};
        }

        ast = ast_temp;
    }

    new_program: Bytecode_Program;
    {
        push_allocator(context.default_allocator);
        new_program = generate_bytecode(ast);
    }

    if new_program.has_error {
        throw_exception(vm, tprint("SyntaxError: %", new_program.error_message));
        return .{};
    }

    const_map: [..] int;
    const_map.allocator = temp;
    for c: new_program.constants {
        array_add(*vm.program.constants, c);
        array_add(*const_map, vm.program.constants.count - 1);
    }

    global_map: [..] int;
    global_map.allocator = temp;
    for g: new_program.globals {
        found, idx := get_global_index(vm, g);
        if found {
            array_add(*global_map, idx);
        } else {
            array_add(*vm.program.globals, g);
            new_idx := vm.program.globals.count - 1;
            array_add(*global_map, new_idx);
            for r: vm.realms {
                if r.globals.count < vm.program.globals.count {
                    old_count := r.globals.count;
                    new_count := vm.program.globals.count;
                    new_globals: [] Value;
                    {
                        push_allocator(context.default_allocator);
                        new_globals = NewArray(new_count, Value);
                    }
                    if old_count > 0 memcpy(new_globals.data, r.globals.data, old_count * size_of(Value));
                    for i: old_count..new_count-1 {
                        is_declared := i < vm.program.declared_globals.count && vm.program.declared_globals[i];
                        new_globals[i] = ifx is_declared then Value.{ type = .UNDEFINED } else Value.{ type = .EMPTY };
                    }
                    r.globals = new_globals;
                }
            }
        }
    }

    prop_map: [..] int;
    prop_map.allocator = temp;
    for p: new_program.property_names {
        pointer := table_find_pointer(*vm.program.property_names_hash, p);
        if pointer {
            array_add(*prop_map, pointer.*);
        } else {
            array_add(*vm.program.property_names, p);
            new_idx := vm.program.property_names.count - 1;
            table_set(*vm.program.property_names_hash, p, new_idx);
            array_add(*prop_map, new_idx);
        }
    }

    func_map: [..] int;
    func_map.allocator = temp;
    target_func_idx := -1;
    for f, f_idx: new_program.functions {
        array_add(*vm.program.functions, f);
        new_f_idx := vm.program.functions.count - 1;
        array_add(*func_map, new_f_idx);
        if target_func_idx == -1 && !(f.flags & .TOP_LEVEL) {
            target_func_idx = new_f_idx;
        }
    }

    if target_func_idx == -1 && func_map.count > 0 {
        target_func_idx = func_map[0];
    }

    for f_idx: func_map {
        f := vm.program.functions[f_idx];
        for * inst: f.instructions {
            if inst.op_code == {
                case .LOAD_CONST; #through;
                case .ADD_CONST; #through;
                case .SUB_CONST;
                    if inst.imm < const_map.count inst.imm = cast(u16) const_map[inst.imm];
                case .LOAD_GLOBAL; #through;
                case .STORE_GLOBAL;
                    if inst.imm < global_map.count inst.imm = cast(u16) global_map[inst.imm];
                case .GET_FIELD; #through;
                case .SET_FIELD; #through;
                case .DELETE_PROPERTY;
                    if inst.imm < prop_map.count inst.imm = cast(u16) prop_map[inst.imm];
                case .LOAD_FUNC;
                    if inst.imm < func_map.count inst.imm = cast(u16) func_map[inst.imm];
            }
        }
    }

    loaded_func := vm.program.functions[target_func_idx];
    func_obj := allocate_object(vm);
    if is_async_gen {
        target_proto: *Gc_Object = vm.async_generator_function_prototype;
        if (this.type == .FUNCTION || this.type == .NATIVE_FUNCTION) && this.object {
            found_proto, proto_val := lookup_property(vm, this.object, "prototype");
            if found_proto && (proto_val.type == .OBJECT || proto_val.type == .ARRAY) && proto_val.object {
                target_proto = proto_val.object;
            } else {
                new_target_realm := this.object.realm;
                if new_target_realm && new_target_realm.async_generator_function_prototype {
                    target_proto = new_target_realm.async_generator_function_prototype;
                }
            }
        }
        func_obj.prototype = target_proto;
    } else if is_async {
        target_proto: *Gc_Object = vm.async_function_prototype;
        if (this.type == .FUNCTION || this.type == .NATIVE_FUNCTION) && this.object {
            found_proto, proto_val := lookup_property(vm, this.object, "prototype");
            if found_proto && (proto_val.type == .OBJECT || proto_val.type == .ARRAY) && proto_val.object {
                target_proto = proto_val.object;
            } else {
                new_target_realm := this.object.realm;
                if new_target_realm && new_target_realm.async_function_prototype {
                    target_proto = new_target_realm.async_function_prototype;
                }
            }
        }
        func_obj.prototype = target_proto;
    } else if is_gen {
        target_proto: *Gc_Object = vm.generator_function_prototype;
        if (this.type == .FUNCTION || this.type == .NATIVE_FUNCTION) && this.object {
            found_proto, proto_val := lookup_property(vm, this.object, "prototype");
            if found_proto && (proto_val.type == .OBJECT || proto_val.type == .ARRAY) && proto_val.object {
                target_proto = proto_val.object;
            } else {
                new_target_realm := this.object.realm;
                if new_target_realm && new_target_realm.generator_function_prototype {
                    target_proto = new_target_realm.generator_function_prototype;
                }
            }
        }
        func_obj.prototype = target_proto;
    } else {
        func_obj.prototype = vm.function_prototype;
    }

    if vm.current_native_callee.type == .NATIVE_FUNCTION && vm.current_native_callee.object {
        func_obj.realm = vm.current_native_callee.object.realm;
    }

    res := Value.{ type = .FUNCTION };
    res.function.function = loaded_func;
    res.function.environment = null;
    res.object = func_obj;

    set_object_property(vm, func_obj, "name", .{ type = .STRING, s = "anonymous" });
    set_object_property(vm, func_obj, "length", .{ type = .NUMBER, number = cast(float64) param_count });

    if is_async_gen {
        proto_obj := allocate_object(vm);
        found_proto, proto_val := lookup_property(vm, vm.async_generator_function_prototype, "prototype");
        if found_proto && proto_val.type == .OBJECT {
            proto_obj.prototype = proto_val.object;
        } else {
            proto_obj.prototype = vm.object_prototype;
        }
        set_object_property(vm, func_obj, "prototype", .{ type = .OBJECT, object = proto_obj });
    } else if is_gen {
        proto_obj := allocate_object(vm);
        found_proto, proto_val := lookup_property(vm, vm.generator_function_prototype, "prototype");
        if found_proto && proto_val.type == .OBJECT {
            proto_obj.prototype = proto_val.object;
        } else {
            proto_obj.prototype = vm.object_prototype;
        }
        set_object_property(vm, func_obj, "prototype", .{ type = .OBJECT, object = proto_obj });
    } else if !is_async {
        proto_obj := allocate_object(vm);
        proto_obj.prototype = vm.object_prototype;
        set_object_property(vm, func_obj, "prototype", .{ type = .OBJECT, object = proto_obj });
        set_object_property(vm, proto_obj, "constructor", res);
    }

    return res;
}

empty_function :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    return .{ type = .UNDEFINED };
}

function_call :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .FUNCTION && this.type != .NATIVE_FUNCTION {
        throw_exception(vm, "TypeError: Function.prototype.call called on non-function");
        return .{};
    }

    this_arg := Value.{};
    if arguments.count > 0 this_arg = arguments[0];

    call_args: [] Value;
    if arguments.count > 1 {
        call_args.data = arguments.data + 1;
        call_args.count = arguments.count - 1;
    }

    return call_value(vm, this_arg, this, call_args, false);
}

function_bind :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if this.type != .FUNCTION && this.type != .NATIVE_FUNCTION {
        throw_exception(vm, "TypeError: Function.prototype.bind called on non-function");
        return .{};
    }

    bound_object := allocate_object(vm);
    bound_object.prototype = vm.function_prototype;

    array_add(*bound_object.fields, this);

    this_arg := Value.{};
    if arguments.count > 0 this_arg = arguments[0];
    array_add(*bound_object.fields, this_arg);

    for i: 1..arguments.count - 1 {
        array_add(*bound_object.fields, arguments[i]);
    }

    result := Value.{
        type = .NATIVE_FUNCTION,
        native_function = bound_function_runner,
        object = bound_object,
    };

    return result;
}

bound_function_runner :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    callee := vm.current_native_callee;

    if !callee.object || callee.object.fields.count < 2 {
        throw_exception(vm, "TypeError: Invalid bound function");
        return .{};
    }

    target_func := callee.object.fields[0];
    bound_this  := callee.object.fields[1];

    final_args: [..] Value;
    for i: 2..callee.object.fields.count - 1 {
        array_add(*final_args, callee.object.fields[i]);
    }
    for arguments {
        array_add(*final_args, it);
    }

    effective_this := ifx is_new then this else bound_this;

    result := call_value(vm, effective_this, target_func, final_args, is_new);

    array_free(final_args);
    return result;
}
