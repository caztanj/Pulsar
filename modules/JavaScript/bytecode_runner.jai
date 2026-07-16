init :: (gc: *Gc) {
    gc.young_objects      = null;
    gc.young_object_count = 0;
    gc.old_objects        = null;
    gc.old_object_count   = 0;
    gc.young_threshold    = 4096;
    gc.old_threshold      = 32768;
    gc.environments       = null;
    gc.environment_count  = 0;
}

allocate_environment :: inline (vm: *Vm) -> *Environment {
    env: *Environment;

    if vm.gc.environment_pool {
        env                    = vm.gc.environment_pool;
        vm.gc.environment_pool = env.next;
        env.values.count       = 0;
    } else {
        env = New(Environment);
    }

    env.marked = false;

    env.next     = null;
    env.previous = null;

    return env;
}

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

allocate_object :: (vm: *Vm) -> *Gc_Object {
    if vm.gc.young_object_count >= vm.gc.young_threshold {
        if vm.gc.old_object_count >= vm.gc.old_threshold collect_garbage_major(vm);
        else                                             collect_garbage_minor(vm);
    }

    object: *Gc_Object;

    if vm.gc.object_pool {
        object            = vm.gc.object_pool;
        vm.gc.object_pool = object.next;

        if object.kind == .MAP || object.kind == .SET {
            array_free(object.map_entries);
        } else if object.kind == .PROMISE {
            array_free(object.promise_then_callbacks);
        } else if object.kind == .GENERATOR || object.kind == .ASYNC_EXECUTION {
            array_free(object.generator_registers);
        }

        object.marked                       = false;
        object.prototype                    = vm.object_prototype;
        object.fields.count                 = 0;
        object.elements.count               = 0;
        object.kind                         = .PLAIN;
        object.realm                        = null;
        object.shape                        = vm.root_shape;
        object.primitive_value              = .{};
    } else {
        object       = New(Gc_Object);
        object.shape = vm.root_shape;
    }

    object.marked            = false;
    object.is_old            = false;
    object.in_remembered_set = false;

    object.next = vm.gc.young_objects;

    vm.gc.young_objects       = object;
    vm.gc.young_object_count += 1;

    if !object.prototype object.prototype = vm.object_prototype;

    return object;
}

mark_roots :: (vm: *Vm, visited_environments: *Table(*Environment, bool), $is_minor: bool) {
    if vm.current_realm {
        for vm.current_realm.globals mark_value(vm, it, visited_environments, is_minor);
    }

    for vm.call_stack     mark_environment(vm, it, visited_environments);
    for vm.loaded_modules mark_value(vm, it.exports, visited_environments, is_minor);

    if vm.current_exports mark_object(vm, vm.current_exports, visited_environments, is_minor);
    if vm.has_exception   mark_value(vm, vm.exception, visited_environments, is_minor);

    for vm.microtask_queue {
        mark_value(vm, it.callback, visited_environments, is_minor);
        mark_value(vm, it.arg, visited_environments, is_minor);
    }

    for vm.timer_queue {
        mark_value(vm, it.callback, visited_environments, is_minor);
        for arg: it.arguments mark_value(vm, arg, visited_environments, is_minor);
    }

    for vm.builtin_prototypes mark_object(vm, it, visited_environments, is_minor);
}

mark_object :: (vm: *Vm, object: *Gc_Object, visited_environments: *Table(*Environment, bool), $is_minor: bool = false) {
    if !object || object.marked return;
    #if is_minor if object.is_old return;

    object.marked = true;

    if object.prototype mark_object(vm, object.prototype, visited_environments, is_minor);
    if object.shape object.shape.marked = true;

    for object.fields      mark_value(vm, it, visited_environments, is_minor);
    for object.elements    mark_value(vm, it, visited_environments, is_minor);

    if object.kind == .MAP || object.kind == .SET {
        for object.map_entries mark_value(vm, it, visited_environments, is_minor);
    } else if object.kind == .PROMISE {
        mark_value(vm, object.promise_result, visited_environments, is_minor);
        for object.promise_then_callbacks mark_value(vm, it, visited_environments, is_minor);
    } else if object.kind == .GENERATOR || object.kind == .ASYNC_EXECUTION {
        for object.generator_registers mark_value(vm, it, visited_environments, is_minor);
        mark_value(vm, object.async_promise, visited_environments, is_minor);
    } else {
        mark_value(vm, object.primitive_value, visited_environments, is_minor);
    }

    if object.realm {
        for object.realm.globals mark_value(vm, it, visited_environments, is_minor);
    }
}

mark_environment :: (vm: *Vm, env: *Environment, visited_environments: *Table(*Environment, bool)) {
    if !env       return;
    if env.marked return;

    env.marked = true;

    for env.values mark_value(vm, it, visited_environments);

    mark_environment(vm, env.parent, visited_environments);
}

mark_value :: (vm: *Vm, value: Value, visited_environments: *Table(*Environment, bool), $is_minor: bool = false) {
    if value.type == .GENERATOR {
        mark_object(vm, value.generator_object, visited_environments, is_minor);
    } else if value.type == .OBJECT || value.type == .ARRAY {
        mark_object(vm, value.object, visited_environments, is_minor);
    } else if value.type == .FUNCTION {
        mark_object(vm, value.object, visited_environments, is_minor);
        mark_environment(vm, value.function.environment, visited_environments);
    } else if value.type == .NATIVE_FUNCTION {
        mark_object(vm, value.object, visited_environments, is_minor);
    } else if value.type == .STRING {
        ptr := table_find_pointer(*vm.allocated_strings, value.s.data);
        if ptr ptr.marked = true;
    }
}

extract_gc_object :: inline (value: Value) -> *Gc_Object {
    if value.type == .GENERATOR                                                                                   return value.generator_object;
    if value.type == .OBJECT || value.type == .ARRAY || value.type == .FUNCTION || value.type == .NATIVE_FUNCTION return value.object;

    return null;
}

write_barrier :: inline (vm: *Vm, object: *Gc_Object, value: Value) {
    if !object || !object.is_old return;

    target := extract_gc_object(value);

    if !target || target.is_old return;

    if !object.in_remembered_set {
        object.in_remembered_set = true;

        array_add(*vm.gc.remembered_set, object);
    }
}

write_barrier_object :: inline (vm: *Vm, object: *Gc_Object, target: *Gc_Object) {
    if !object || !object.is_old return;
    if !target || target.is_old  return;

    if !object.in_remembered_set {
        object.in_remembered_set = true;

        array_add(*vm.gc.remembered_set, object);
    }
}



sweep_strings :: (vm: *Vm) {
    to_remove: [..] *u8;

    for *v, k: vm.allocated_strings {
        if !v.marked {
            free(v.s.data);
            array_add(*to_remove, k);
        } else {
            v.marked = false;
        }
    }

    for to_remove table_remove(*vm.allocated_strings, it);
    array_free(to_remove);
}

gc_array_reset :: inline (arr: *$T) {
    if arr.allocated > 64 {
        array_free(arr.*);
        arr.data      = null;
        arr.allocated = 0;
        arr.count     = 0;
    } else {
        arr.count = 0;
    }
}

sweep_environments :: (vm: *Vm, is_major := false) {
    previous_env: *Environment;

    current_env := vm.gc.environments;
    while current_env {
        if !current_env.marked {
            unreachable := current_env;
            current_env  = current_env.next;

            if previous_env previous_env.next  = current_env;
            else            vm.gc.environments = current_env;

            if current_env current_env.previous = previous_env;

            gc_array_reset(*unreachable.values);

            unreachable.next       = vm.gc.environment_pool;
            vm.gc.environment_pool = unreachable;

            vm.gc.environment_count -= 1;
        } else {
            current_env.marked   = false;
            current_env.previous = previous_env;
            if is_major current_env.is_captured = true;

            previous_env = current_env;
            current_env  = current_env.next;
        }
    }

    for vm.call_stack it.marked = false;
}

sweep_shapes :: (vm: *Vm) {
    for vm.shapes {
        if it.marked {
            for shape, name: it.transitions {
                if !shape.marked table_remove(*it.transitions, name);
            }
        }
    }

    surviving_shapes: [..] *Shape;

    for vm.shapes {
        if !it.marked {
            array_free(it.property_names);
            array_free(it.fast_offsets);
            deinit(*it.property_offsets);
            deinit(*it.transitions);
            free(it);
        } else {
            it.marked = false;
            array_add(*surviving_shapes, it);
        }
    }

    array_free(vm.shapes);

    vm.shapes = surviving_shapes;
}

collect_garbage_minor :: (vm: *Vm) {
    #if TRACE_GARBAGE_COLLECTION {
        print("Minor GC: Starting collection (young objects before: %)\n", vm.gc.young_object_count);
    }

    visited_environments: Table(*Environment, bool);

    defer deinit(*visited_environments);

    mark_roots(vm, *visited_environments, true);

    for vm.gc.remembered_set {
        if it.prototype mark_object(vm, it.prototype, *visited_environments, true);

        for it.fields      mark_value(vm, it, *visited_environments, true);
        for it.elements    mark_value(vm, it, *visited_environments, true);

        if it.kind == .MAP || it.kind == .SET {
            for it.map_entries mark_value(vm, it, *visited_environments, true);
        } else if it.kind == .PROMISE {
            mark_value(vm, it.promise_result, *visited_environments, true);
            for it.promise_then_callbacks mark_value(vm, it, *visited_environments, true);
        } else if it.kind == .GENERATOR || it.kind == .ASYNC_EXECUTION {
            for it.generator_registers mark_value(vm, it, *visited_environments, true);
            mark_value(vm, it.async_promise, *visited_environments, true);
        } else {
            mark_value(vm, it.primitive_value, *visited_environments, true);
        }

        it.in_remembered_set = false;
    }

    vm.gc.remembered_set.count = 0;

    previous: *Gc_Object;

    current := vm.gc.young_objects;
    while current {
        if !current.marked {
            unreachable := current;
            current      = current.next;

            if previous previous.next       = current;
            else        vm.gc.young_objects = current;

            gc_array_reset(*unreachable.fields);
            gc_array_reset(*unreachable.elements);

            if unreachable.kind == .MAP || unreachable.kind == .SET {
                gc_array_reset(*unreachable.map_entries);
            } else if unreachable.kind == .PROMISE {
                gc_array_reset(*unreachable.promise_then_callbacks);
            } else if unreachable.kind == .GENERATOR || unreachable.kind == .ASYNC_EXECUTION {
                gc_array_reset(*unreachable.generator_registers);
            }

            unreachable.next = vm.gc.object_pool;

            vm.gc.object_pool         = unreachable;
            vm.gc.young_object_count -= 1;
        } else {
            survivor := current;
            current   = current.next;

            if previous previous.next       = current;
            else        vm.gc.young_objects = current;

            survivor.is_old = true;
            survivor.marked = false;
            survivor.next   = vm.gc.old_objects;

            vm.gc.old_objects         = survivor;
            vm.gc.young_object_count -= 1;
            vm.gc.old_object_count   += 1;
        }
    }

    sweep_environments(vm);
}

collect_garbage_major :: (vm: *Vm) {
    #if TRACE_GARBAGE_COLLECTION {
        print("Major GC: Starting collection (old objects before: %)\n", vm.gc.old_object_count);
    }

    visited_environments: Table(*Environment, bool);

    defer deinit(*visited_environments);

    current := vm.gc.young_objects;
    while current {
        current.marked = false;
        current = current.next;
    }

    current = vm.gc.old_objects;
    while current {
        current.marked = false;
        current = current.next;
    }

    mark_roots(vm, *visited_environments, false);
    for vm.gc.remembered_set  it.in_remembered_set = false;

    vm.gc.remembered_set.count = 0;

    sweep_strings(vm);
    sweep_shapes(vm);

    sweep_list :: (vm: *Vm, list_head: **Gc_Object, list_count: *int) {
        previous: *Gc_Object;

        current := list_head.*;
        while current {
            if !current.marked {
                unreachable := current;
                current      = current.next;

                if previous previous.next = current;
                else        list_head.*   = current;

                gc_array_reset(*unreachable.fields);
                gc_array_reset(*unreachable.elements);

                if unreachable.kind == .MAP || unreachable.kind == .SET {
                    gc_array_reset(*unreachable.map_entries);
                } else if unreachable.kind == .PROMISE {
                    gc_array_reset(*unreachable.promise_then_callbacks);
                } else if unreachable.kind == .GENERATOR || unreachable.kind == .ASYNC_EXECUTION {
                    gc_array_reset(*unreachable.generator_registers);
                } else if unreachable.kind == .REGEXP {
                    Uniform.uninit(*unreachable.regexp);
                }

                unreachable.next   = vm.gc.object_pool;
                vm.gc.object_pool  = unreachable;
                list_count.*      -= 1;
            } else {
                current.marked = false;
                previous       = current;
                current        = current.next;
            }
        }
    }

    sweep_list(vm, *vm.gc.young_objects, *vm.gc.young_object_count);
    sweep_list(vm, *vm.gc.old_objects, *vm.gc.old_object_count);

    sweep_environments(vm, true);
}

run_bytecode :: (program: *Bytecode_Program, profile := false, permissions: Permission = 0, execute_main_function := true) -> *Vm {
    vm := New(Vm);

    vm.program     = program;
    vm.profile     = profile;
    vm.permissions = permissions;

    if profile vm.profiler = New(Profiler);

    vm.try_context_stack.allocator = temp;

    init(*vm.gc);

    vm.current_realm         = New(Realm);
    vm.current_realm.globals = NewArray(program.globals.count, Value);

    array_add(*vm.realms, vm.current_realm);

    vm.root_shape = New(Shape);

    array_add(*vm.shapes, vm.root_shape);

    init_common_vm_globals(vm);

    if execute_main_function {
        execute_main(vm, program);
    }

    return vm;
}

execute_main :: (vm: *Vm, program: *Bytecode_Program) -> Value {
    old_program := vm.program;
    vm.program   = program;

    defer vm.program = old_program;

    main_function: *Bytecode_Function;
    for program.functions if it.name == "main" {
        main_function = it;
        break;
    }

    global_this: Value;

    found, index := get_global_index(vm, "globalThis");
    if found {
        global_this = vm.current_realm.globals[index];
    } else {
        for vm.program.globals {
            if it == "globalThis" {
                global_this = vm.current_realm.globals[it_index];
                break;
            }
        }
    }

    result: Value;
    if main_function {
        if main_function.flags & .ASYNC {
            promise_value := promise_constructor(vm, .{}, .[], true);

            async_object                := allocate_object(vm);
            async_object.kind            = .ASYNC_EXECUTION;
            async_object.generator_func  = main_function;
            async_object.generator_pc    = 0;
            async_object.async_promise   = promise_value;

            for i: 0..main_function.locals_count - 1 array_add(*async_object.generator_registers, .{ type = .UNDEFINED });

            result = promise_value;

            execute_function(vm, main_function, this_value = global_this, generator = async_object);
        } else {
            result = execute_function(vm, main_function, this_value = global_this);
        }
    }
    if vm.current_realm.globals.count < program.globals.count {
        old_globals := vm.current_realm.globals;

        vm.current_realm.globals = NewArray(program.globals.count, Value);

        for i: 0..old_globals.count-1 vm.current_realm.globals[i] = old_globals[i];

        if old_globals.data free(old_globals.data);
    }

    init(*vm.external_events_mutex);
    init(*vm.event_loop_semaphore);

    if vm.has_exception return result;

    run_event_loop(vm);

    return result;
}

execute_function :: (vm: *Vm, function: *Bytecode_Function, call_final_arguments: [] Value = .[], this_value: Value = .{}, generator: *Gc_Object = null, parent_env: *Environment = null) -> Value {
    if vm.profile {
        return execute_function_internal(vm, function, call_final_arguments, this_value, generator, parent_env, true);
    } else {
        return execute_function_internal(vm, function, call_final_arguments, this_value, generator, parent_env, false);
    }
}

execute_function_internal :: (vm: *Vm, initial_function: *Bytecode_Function, initial_call_final_arguments: [] Value, initial_this_value: Value, initial_generator: *Gc_Object, initial_parent_env: *Environment, $profile: bool) -> Value {
    start_frame_count := vm.call_frames.count;

    function             := initial_function;
    call_final_arguments := initial_call_final_arguments;
    this_value           := initial_this_value;
    generator            := initial_generator;
    parent_env           := initial_parent_env;

    env: *Environment;

    registers:      [] Value;
    registers_data: *Value;

    try_stack: *[..] Try_Context;

    initial_try_count: s64;

    constants_data: *Value;

    instructions_pointer: *Instruction;
    instruction_count:    int;

    pc_pointer: *Instruction;
    pc_end:     *Instruction;

    globals_data: *Value;

    last_value: Value;

    needs_frame_init := true;

    while true {
        if needs_frame_init {
            env = allocate_environment(vm);

            env.parent      = parent_env;
            env.is_captured = false;

            array_add(*vm.call_stack, env);

            if (function.flags & .ARROW) && parent_env env.this_value = parent_env.this_value;
            else                                       env.this_value = this_value;

            pc := 0;

            try_stack         = *vm.try_context_stack;
            initial_try_count = try_stack.count;

            if generator {
                registers      = generator.generator_registers;
                registers_data = registers.data;
                pc             = generator.generator_pc;
            } else {
                if env.values.allocated < function.locals_count array_resize(*env.values, function.locals_count);
                else                                            env.values.count = function.locals_count;

                registers      = env.values;
                registers_data = registers.data;

                number_of_arguments_to_copy := function.arguments_count;

                if (function.flags & .REST_PARAMETER) number_of_arguments_to_copy -= 1;

                if call_final_arguments.count >= number_of_arguments_to_copy {
                    if number_of_arguments_to_copy > 0 memcpy(registers_data, call_final_arguments.data, number_of_arguments_to_copy * size_of(Value));
                } else {
                    if call_final_arguments.count > 0                           memcpy(registers_data, call_final_arguments.data, call_final_arguments.count * size_of(Value));
                    if number_of_arguments_to_copy > call_final_arguments.count memset(registers_data + call_final_arguments.count, 0, (number_of_arguments_to_copy - call_final_arguments.count) * size_of(Value));
                }

                if (function.flags & .REST_PARAMETER) {
                    rest_array      := allocate_object(vm);
                    rest_array.kind  = .ARRAY;

                    if !rest_array.prototype rest_array.prototype = vm.array_prototype;

                    for i: number_of_arguments_to_copy..call_final_arguments.count-1 {
                        array_add(*rest_array.elements, call_final_arguments[i]);
                        write_barrier(vm, rest_array, call_final_arguments[i]);
                    }

                    registers_data[number_of_arguments_to_copy] = .{ type = .ARRAY, object = rest_array };
                }

                if function.locals_count > function.arguments_count memset(registers.data + function.arguments_count, 0, (function.locals_count - function.arguments_count) * size_of(Value));
            }

            constants_data       = vm.program.constants.data;
            instructions_pointer = function.instructions.data;
            instruction_count    = function.instructions.count;

            pc_pointer = instructions_pointer + pc;
            pc_end     = instructions_pointer + instruction_count;

            globals_data = vm.current_realm.globals.data;
        }

        needs_frame_init = false;

        while !vm.has_exception && pc_pointer < pc_end {
            instruction := pc_pointer;
            pc_pointer += 1;

            #if profile {
                vm.profiler.instruction_counts[cast(int) instruction.op_code] += 1;
            }

            if #complete instruction.op_code == {
                case .LOAD_CONST;
                    registers_data[instruction.dest] = constants_data[instruction.imm];
                    last_value                       = registers_data[instruction.dest];

                case .LOAD_GLOBAL;
                    registers_data[instruction.dest] = globals_data[instruction.imm];
                    last_value                       = registers_data[instruction.dest];

                case .STORE_GLOBAL;
                    globals_data[instruction.imm] = registers_data[instruction.arg1];
                    last_value                    = globals_data[instruction.imm];

                case .LOAD_LOCAL;
                    registers_data[instruction.dest] = registers_data[instruction.imm];
                    last_value                       = registers_data[instruction.dest];

                case .STORE_LOCAL;
                    registers_data[instruction.imm] = registers_data[instruction.arg1];
                    last_value                      = registers_data[instruction.imm];

                case .LOAD_UPVALUE;
                    level   := instruction.imm >> 16;
                    index   := instruction.imm & 0xFFFF;
                    current := env;

                    if level == 1 {
                        if current current = current.parent;
                    } else if level == 2 {
                        if current current = current.parent;
                        if current current = current.parent;
                    } else {
                        for 1..level {
                            if current current = current.parent;
                        }
                    }
                    if current && index < current.values.count {
                        registers_data[instruction.dest] = current.values.data[index];
                    } else {
                        registers_data[instruction.dest] = .{ type = .UNDEFINED };
                    }

                    last_value = registers_data[instruction.dest];

                case .STORE_UPVALUE;
                    level   := instruction.imm >> 16;
                    index   := instruction.imm & 0xFFFF;
                    current := env;

                    if level == 1 {
                        if current current = current.parent;
                    } else if level == 2 {
                        if current current = current.parent;
                        if current current = current.parent;
                    } else {
                        for 1..level {
                            if current current = current.parent;
                        }
                    }

                    if current && index < current.values.count {
                        current.values.data[index] = registers_data[instruction.arg1];
                    }

                    last_value = registers_data[instruction.arg1];

                case .LOAD_THIS;
                    registers_data[instruction.dest] = env.this_value;
                    last_value                       = registers_data[instruction.dest];

                case .LOAD_FUNC;
                    registers_data[instruction.dest].type                 = .FUNCTION;
                    registers_data[instruction.dest].function.function    = vm.program.functions[instruction.imm];
                    registers_data[instruction.dest].function.environment = env;

                    current := env;
                    while current {
                        if current.is_captured break;

                        current.is_captured = true;
                        current             = current.parent;
                    }

                    function_object           := allocate_object(vm);
                    function_object.prototype  = null;

                    registers_data[instruction.dest].object = function_object;

                    loaded_function := vm.program.functions[instruction.imm];

                    if !(loaded_function.flags & .ARROW) {
                        prototype_object           := allocate_object(vm);
                        prototype_object.prototype  = vm.object_prototype;

                        prototype_value := Value.{
                            type   = .OBJECT,
                            object = prototype_object,
                        };

                        set_object_property(vm, function_object, "prototype", prototype_value);
                        set_object_property(vm, prototype_object, "constructor", registers_data[instruction.dest]);
                    }

                    last_value = registers_data[instruction.dest];

                case .ADD;
                    v1 := *registers_data[instruction.arg1];
                    v2 := *registers_data[instruction.arg2];

                    if v1.type == .NUMBER && v2.type == .NUMBER {
                        registers_data[instruction.dest].type   = .NUMBER;
                        registers_data[instruction.dest].number = v1.number + v2.number;
                    } else {
                        registers_data[instruction.dest] = values_addition(vm, v1.*, v2.*);

                        if vm.has_exception break;
                    }

                    last_value = registers_data[instruction.dest];

                case .SUB;
                    v1 := *registers_data[instruction.arg1];
                    v2 := *registers_data[instruction.arg2];

                    if v1.type == .NUMBER && v2.type == .NUMBER {
                        registers_data[instruction.dest].type = .NUMBER;
                        registers_data[instruction.dest].number = v1.number - v2.number;
                    } else {
                        registers_data[instruction.dest] = values_subtraction(v1.*, v2.*);

                        if vm.has_exception break;
                    }

                    last_value = registers_data[instruction.dest];

                case .MUL;
                    v1 := *registers_data[instruction.arg1];
                    v2 := *registers_data[instruction.arg2];

                    if v1.type == .NUMBER && v2.type == .NUMBER {
                        registers_data[instruction.dest].type = .NUMBER;
                        registers_data[instruction.dest].number = v1.number * v2.number;
                    } else {
                        registers_data[instruction.dest] = values_multiply(v1.*, v2.*);

                        if vm.has_exception break;
                    }

                    last_value = registers_data[instruction.dest];

                case .DIV;
                    v1 := *registers_data[instruction.arg1];
                    v2 := *registers_data[instruction.arg2];

                    if v1.type == .NUMBER && v2.type == .NUMBER {
                        registers_data[instruction.dest].type = .NUMBER;
                        registers_data[instruction.dest].number = v1.number / v2.number;
                    } else {
                        registers_data[instruction.dest] = values_divide(v1.*, v2.*);

                        if vm.has_exception break;
                    }

                    last_value = registers_data[instruction.dest];

                case .MOD;
                    registers_data[instruction.dest] = values_modulo(registers_data[instruction.arg1], registers_data[instruction.arg2]);
                    last_value                       = registers_data[instruction.dest];

                case .EXPONENTIATION;
                    registers_data[instruction.dest] = values_exponentiation(registers_data[instruction.arg1], registers_data[instruction.arg2]);
                    last_value                       = registers_data[instruction.dest];

                case .CALL;
                    callee          := *registers_data[instruction.arg1];
                    this_val        := ifx instruction.arg2 != 255 registers_data[instruction.arg2] else Value.{};
                    arguments_count := instruction.imm & 0xFFFF;

                    first_argument_register := instruction.imm >> 16;

                    final_arguments: [] Value;
                    final_arguments.data  = *registers_data[first_argument_register];
                    final_arguments.count = arguments_count;

                    if callee.type == .FUNCTION && !(callee.function.function.flags & .GENERATOR) && !(callee.function.function.flags & .ASYNC) {
                        frame: Call_Frame;
                        frame.function             = function;
                        frame.env                  = env;
                        frame.registers            = registers;
                        frame.registers_data       = registers_data;
                        frame.instructions_pointer = instructions_pointer;
                        frame.pc_pointer           = pc_pointer;
                        frame.pc_end               = pc_end;
                        frame.dest_register        = instruction.dest;
                        frame.initial_try_count    = initial_try_count;
                        frame.generator            = generator;

                        array_add(*vm.call_frames, frame);

                        function             = callee.function.function;
                        call_final_arguments = final_arguments;
                        this_value           = this_val;
                        parent_env           = callee.function.environment;
                        generator            = null;

                        needs_frame_init = true;
                        break;
                    }
                    else {
                        vm.current_function = function;
                        vm.current_pc       = pc_pointer;
                        registers_data[instruction.dest] = call_value(vm, this_val, callee.*, final_arguments, false);
                    }

                    if vm.has_exception break;

                    last_value = registers_data[instruction.dest];

                case .NEW_CALL;
                    callee          := registers_data[instruction.arg1];
                    this_val        := ifx instruction.arg2 != 255 registers_data[instruction.arg2] else Value.{};
                    arguments_count := instruction.imm & 0xFFFF;

                    first_argument_register := instruction.imm >> 16;

                    final_arguments: [] Value;
                    final_arguments.data  = *registers_data[first_argument_register];
                    final_arguments.count = arguments_count;

                    vm.current_function = function;
                    vm.current_pc       = pc_pointer;
                    registers_data[instruction.dest] = call_value(vm, this_val, callee, final_arguments, true);

                    run_microtasks(vm);

                    if vm.has_exception break;

                    last_value = registers_data[instruction.dest];

                case .NEW_OBJECT;
                    object := allocate_object(vm);

                    registers_data[instruction.dest].type   = .OBJECT;
                    registers_data[instruction.dest].object = object;

                    last_value = registers_data[instruction.dest];

                case .SET_FIELD;
                    object := registers_data[instruction.dest].object;

                    if object {
                        property_name := vm.program.property_names[instruction.imm];

                        if object.kind == .GLOBAL_PROXY {
                            found, global_index := get_global_index(vm, property_name);

                            if found vm.current_realm.globals[global_index] = registers_data[instruction.arg1];
                            else                                              set_object_property(vm, object, property_name, registers_data[instruction.arg1]);
                        } else {
                            pic_set_field :: (vm: *Vm, object: *Gc_Object, offset: s32, value: Value) #expand {
                                if offset < object.fields.count {
                                    object.fields.data[offset] = value;

                                    write_barrier(vm, object, value);
                                } else {
                                    while object.fields.count <= offset array_add(*object.fields, .{});

                                    object.fields.data[offset] = value;

                                    write_barrier(vm, object, value);
                                }
                            }

                            pic_hit   := false;
                            pic_count := instruction.inline_cache.count;

                            for i: 0..pic_count - 1 {
                                if instruction.inline_cache.shapes[i] == object.shape {
                                    pic_set_field(vm, object, instruction.inline_cache.offsets[i], registers_data[instruction.arg1]);
                                    if instruction.inline_cache.target_shapes[i] object.shape = instruction.inline_cache.target_shapes[i];
                                    pic_hit = true;
                                    break;
                                }
                            }

                            if !pic_hit {
                                if !object.shape object.shape = vm.root_shape;

                                incoming_shape := object.shape;

                                set_object_property(vm, object, property_name, registers_data[instruction.arg1], instruction.imm);

                                if incoming_shape {
                                    offset, shape_found := shape_lookup_property(object.shape, property_name, instruction.imm);

                                    if shape_found {
                                        add_inline_cache(*instruction.inline_cache, incoming_shape, cast(s32) offset, object.shape);
                                    }
                                }
                            }
                        }
                    }

                    last_value = registers_data[instruction.arg1];

                case .GET_FIELD;
                    value         := *registers_data[instruction.arg1];
                    property_name := vm.program.property_names[instruction.imm];

                    if (value.type == .OBJECT || value.type == .ARRAY) && value.object {
                        object := value.object;

                        pic_hit   := false;
                        pic_count := instruction.inline_cache.count;

                        for i: 0..pic_count - 1 {
                            if instruction.inline_cache.shapes[i] == object.shape {
                                offset := instruction.inline_cache.offsets[i];
                                if offset < object.fields.count registers_data[instruction.dest] = object.fields.data[offset];
                                else                            registers_data[instruction.dest] = .{ type = .UNDEFINED };
                                pic_hit = true;
                                break;
                            }
                        }

                        if !pic_hit {
                            registers_data[instruction.dest] = get_property_or_undefined(vm, object, property_name, instruction.imm);

                            if object.shape {
                                offset, shape_found := shape_lookup_property(object.shape, property_name, instruction.imm);

                                if shape_found {
                                    add_inline_cache(*instruction.inline_cache, object.shape, cast(s32) offset);
                                }
                            }
                        }
                    } else if value.type == .STRING {
                        if property_name == "length" {
                            registers_data[instruction.dest].type   = .NUMBER;
                            registers_data[instruction.dest].number = cast(float64) value.s.count;
                        } else {
                            registers_data[instruction.dest] = get_property_or_undefined(vm, vm.string_prototype, property_name, instruction.imm);
                        }
                    } else if value.type == .OBJECT || value.type == .ARRAY || value.type == .GENERATOR || value.type == .FUNCTION || value.type == .NATIVE_FUNCTION || value.type == .SYMBOL {
                        current := ifx value.type == .GENERATOR value.generator_object else value.object;

                        if current && current.kind == .GLOBAL_PROXY {
                            found, global_index := get_global_index(vm, property_name);

                            if found {
                                registers_data[instruction.dest] = vm.current_realm.globals[global_index];
                                if property_name == "globalThis" && registers_data[instruction.dest].type == .OBJECT {
                                    registers_data[instruction.dest].object.kind = .GLOBAL_PROXY;
                                }
                            } else {
                                registers_data[instruction.dest] = .{ type = .UNDEFINED };
                            }
                        } else if current {
                            registers_data[instruction.dest] = get_property_or_undefined(vm, current, property_name, instruction.imm);
                        } else {
                            registers_data[instruction.dest] = .{ type = .UNDEFINED };
                        }
                    } else if value.type == .NUMBER {
                        registers_data[instruction.dest] = get_property_or_undefined(vm, vm.number_prototype, property_name, instruction.imm);
                    } else if value.type == .BOOLEAN {
                        registers_data[instruction.dest] = get_property_or_undefined(vm, vm.boolean_prototype, property_name, instruction.imm);
                    } else {
                        registers_data[instruction.dest] = .{ type = .UNDEFINED };
                    }

                    last_value = registers_data[instruction.dest];

                case .NEW_ARRAY;
                    object           := allocate_object(vm);
                    object.kind       = .ARRAY;
                    object.prototype  = vm.array_prototype;

                    if instruction.imm > 0 array_resize(*object.elements, instruction.imm);

                    registers_data[instruction.dest].type   = .ARRAY;
                    registers_data[instruction.dest].object = object;

                    last_value = registers_data[instruction.dest];

                case .ARRAY_GET;
                    value    := *registers_data[instruction.arg1];
                    property := *registers_data[instruction.arg2];

                    if value.type == .OBJECT || value.type == .ARRAY || value.type == .SYMBOL || value.type == .FUNCTION || value.type == .NATIVE_FUNCTION || value.type == .GENERATOR {
                        object := value.object;

                        if property.type == .NUMBER {
                            index  := cast(int) property.number;
                            if object {
                                if is_typed_array(object.kind) {
                                    len := get_typed_array_length(object);
                                    if index >= 0 && index < len {
                                        registers_data[instruction.dest] = .{ type = .NUMBER, number = get_typed_array_element(object, index) };
                                    } else {
                                        registers_data[instruction.dest] = .{ type = .UNDEFINED };
                                    }
                                } else {
                                    if index >= 0 && index < object.elements.count registers_data[instruction.dest] = object.elements[index];
                                    else                                             registers_data[instruction.dest] = .{ type = .UNDEFINED };
                                }
                            } else {
                                registers_data[instruction.dest] = .{ type = .UNDEFINED };
                            }
                        } else if property.type == .STRING {
                            registers_data[instruction.dest] = get_property_or_undefined(vm, object, property.s);
                        } else {
                            registers_data[instruction.dest] = .{ type = .UNDEFINED };
                        }
                    } else if value.type == .STRING {
                        if property.type == .NUMBER {
                            index := cast(int) property.number;

                            if index >= 0 && index < value.s.count {
                                registers_data[instruction.dest].type = .STRING;
                                registers_data[instruction.dest].s  = slice(value.s, index, 1);
                            } else {
                                registers_data[instruction.dest] = .{ type = .UNDEFINED };
                            }
                        } else if property.type == .STRING {
                            if property.s == "length" {
                                registers_data[instruction.dest].type   = .NUMBER;
                                registers_data[instruction.dest].number = cast(float64) value.s.count;
                            } else {
                                registers_data[instruction.dest] = get_property_or_undefined(vm, vm.string_prototype, property.s);
                            }
                        } else {
                            registers_data[instruction.dest] = .{ type = .UNDEFINED };
                        }
                    } else {
                        registers_data[instruction.dest] = .{ type = .UNDEFINED };
                    }

                    if vm.has_exception break;

                    last_value = registers_data[instruction.dest];

                case .ARRAY_SET;
                    object := registers_data[instruction.arg1].object;
                    index  := instruction.imm;

                    if object {
                        while object.elements.count <= index array_add(*object.elements, .{});

                        object.elements[index] = registers_data[instruction.arg2];

                        write_barrier(vm, object, registers_data[instruction.arg2]);
                    }

                    last_value = registers_data[instruction.arg2];

                case .COMPUTED_SET;
                    object   := registers_data[instruction.dest].object;
                    property := *registers_data[instruction.arg1];
                    value    := registers_data[instruction.arg2];

                    if object {
                        if property.type == .STRING {
                            set_object_property(vm, object, property.s, value);
                        } else if property.type == .NUMBER {
                            index := cast(int) property.number;

                            if index >= 0 {
                                if is_typed_array(object.kind) {
                                    len := get_typed_array_length(object);
                                    if index < len {
                                        set_typed_array_element(object, index, value_to_number(value));
                                    }
                                } else {
                                    while object.elements.count <= index array_add(*object.elements, .{});

                                    object.elements[index] = value;

                                    write_barrier(vm, object, value);
                                }
                            }
                        }
                    }

                    last_value = value;

                case .RETURN;
                    if generator {
                        if generator.kind == .ASYNC_EXECUTION promise_resolve_inner(vm, generator.async_promise, registers_data[instruction.arg1]);

                        generator.generator_closed = true;
                    }

                    ret_val := registers_data[instruction.arg1];

                    vm.call_stack.count -= 1;
                    if env.is_captured {
                        env.next = vm.gc.environments;
                        if vm.gc.environments vm.gc.environments.previous = env;
                        env.previous = null;
                        vm.gc.environments       = env;
                        vm.gc.environment_count += 1;
                    } else {
                        env.next               = vm.gc.environment_pool;
                        vm.gc.environment_pool = env;
                    }

                    if vm.call_frames.count == start_frame_count {
                        return ret_val;
                    } else {
                        vm.call_frames.count -= 1;
                        frame := *vm.call_frames.data[vm.call_frames.count];

                        function             = frame.function;
                        env                  = frame.env;
                        registers            = frame.registers;
                        registers_data       = frame.registers_data;
                        try_stack            = *vm.try_context_stack;
                        initial_try_count    = frame.initial_try_count;
                        constants_data       = vm.program.constants.data;
                        instructions_pointer = frame.instructions_pointer;
                        pc_pointer           = frame.pc_pointer;
                        pc_end               = frame.pc_end;
                        globals_data         = vm.current_realm.globals.data;
                        generator            = frame.generator;

                        registers_data[frame.dest_register] = ret_val;
                        last_value = ret_val;
                        needs_frame_init = false;

                        break;
                    }

                case .EQUAL;
                    v1 := *registers_data[instruction.arg1];
                    v2 := *registers_data[instruction.arg2];

                    registers_data[instruction.dest].type = .BOOLEAN;

                    if v1.type == .NUMBER && v2.type == .NUMBER registers_data[instruction.dest].boolean = v1.number == v2.number;
                    else                                        registers_data[instruction.dest].boolean = values_equal(v1.*, v2.*);

                    last_value = registers_data[instruction.dest];

                case .NOT_EQUAL;
                    v1 := *registers_data[instruction.arg1];
                    v2 := *registers_data[instruction.arg2];

                    registers_data[instruction.dest].type = .BOOLEAN;

                    if v1.type == .NUMBER && v2.type == .NUMBER registers_data[instruction.dest].boolean = v1.number != v2.number;
                    else                                        registers_data[instruction.dest].boolean = !values_equal(v1.*, v2.*);

                    last_value = registers_data[instruction.dest];

                case .LESS_THAN;
                    v1 := *registers_data[instruction.arg1];
                    v2 := *registers_data[instruction.arg2];

                    registers_data[instruction.dest].type = .BOOLEAN;

                    if v1.type == .NUMBER && v2.type == .NUMBER registers_data[instruction.dest].boolean = v1.number < v2.number;
                    else                                        registers_data[instruction.dest].boolean = values_less_than(v1.*, v2.*);

                    last_value = registers_data[instruction.dest];

                case .GREATER_THAN;
                    v1 := *registers_data[instruction.arg1];
                    v2 := *registers_data[instruction.arg2];

                    registers_data[instruction.dest].type = .BOOLEAN;

                    if v1.type == .NUMBER && v2.type == .NUMBER registers_data[instruction.dest].boolean = v1.number > v2.number;
                    else                                        registers_data[instruction.dest].boolean = values_greater_than(v1.*, v2.*);

                    last_value = registers_data[instruction.dest];

                case .LESS_THAN_EQUAL;
                    v1 := *registers_data[instruction.arg1];
                    v2 := *registers_data[instruction.arg2];

                    registers_data[instruction.dest].type = .BOOLEAN;

                    if v1.type == .NUMBER && v2.type == .NUMBER registers_data[instruction.dest].boolean = v1.number <= v2.number;
                    else                                        registers_data[instruction.dest].boolean = values_less_than_equal(v1.*, v2.*);

                    last_value = registers_data[instruction.dest];

                case .GREATER_THAN_EQUAL;
                    v1 := *registers_data[instruction.arg1];
                    v2 := *registers_data[instruction.arg2];

                    registers_data[instruction.dest].type = .BOOLEAN;

                    if v1.type == .NUMBER && v2.type == .NUMBER registers_data[instruction.dest].boolean = v1.number >= v2.number;
                    else                                        registers_data[instruction.dest].boolean = values_greater_than_equal(v1.*, v2.*);

                    last_value = registers_data[instruction.dest];

                case .STRICT_EQUAL;
                    v1 := *registers_data[instruction.arg1];
                    v2 := *registers_data[instruction.arg2];

                    registers_data[instruction.dest].type = .BOOLEAN;

                    if v1.type == .NUMBER && v2.type == .NUMBER registers_data[instruction.dest].boolean = v1.number == v2.number;
                    else                                        registers_data[instruction.dest].boolean = values_strict_equal(v1.*, v2.*);

                    last_value = registers_data[instruction.dest];

                case .STRICT_NOT_EQUAL;
                    v1 := *registers_data[instruction.arg1];
                    v2 := *registers_data[instruction.arg2];

                    registers_data[instruction.dest].type = .BOOLEAN;

                    if v1.type == .NUMBER && v2.type == .NUMBER registers_data[instruction.dest].boolean = v1.number != v2.number;
                    else                                        registers_data[instruction.dest].boolean = !values_strict_equal(v1.*, v2.*);

                    last_value = registers_data[instruction.dest];

                case .INSTANCEOF;
                    left  := *registers_data[instruction.arg1];
                    right := *registers_data[instruction.arg2];

                    registers_data[instruction.dest].type    = .BOOLEAN;
                    registers_data[instruction.dest].boolean = false;

                    if (right.type == .OBJECT || right.type == .FUNCTION || right.type == .NATIVE_FUNCTION) && right.object {
                        found, target_protototype_value := lookup_property(vm, right.object, "prototype");

                        if found && (target_protototype_value.type == .OBJECT || target_protototype_value.type == .ARRAY) && target_protototype_value.object {
                            target_prototype := target_protototype_value.object;

                            current := ifx (left.type == .OBJECT || left.type == .ARRAY || left.type == .FUNCTION) left.object else null;

                            while current {
                                current = current.prototype;

                                if current == target_prototype {
                                    registers_data[instruction.dest].boolean = true;
                                    break;
                                }
                            }
                        }
                    }

                    last_value = registers_data[instruction.dest];

                case .IN;
                    left  := *registers_data[instruction.arg1];
                    right := *registers_data[instruction.arg2];

                    registers_data[instruction.dest].type    = .BOOLEAN;
                    registers_data[instruction.dest].boolean = false;

                    if (right.type == .OBJECT || right.type == .ARRAY) && right.object {
                        if right.type == .ARRAY && left.type == .NUMBER {
                            index := cast(int) left.number;

                            if index >= 0 && index < right.object.fields.count registers_data[instruction.dest].boolean = right.object.fields[index].type != .UNDEFINED;
                        } else {
                            name := value_to_string(vm, left.*);

                            if right.type == .ARRAY {
                                found, _                                 := lookup_property(vm, right.object, name);
                                registers_data[instruction.dest].boolean  = found;
                            } else {
                                found, _                                 := lookup_property(vm, right.object, name);
                                registers_data[instruction.dest].boolean  = found;
                            }
                        }
                    }

                    last_value = registers_data[instruction.dest];

                case .BITWISE_AND;
                    registers_data[instruction.dest] = values_bitwise_and(registers_data[instruction.arg1], registers_data[instruction.arg2]);
                    last_value                       = registers_data[instruction.dest];

                case .BITWISE_OR;
                    registers_data[instruction.dest] = values_bitwise_or(registers_data[instruction.arg1], registers_data[instruction.arg2]);
                    last_value                       = registers_data[instruction.dest];

                case .BITWISE_XOR;
                    registers_data[instruction.dest] = values_bitwise_xor(registers_data[instruction.arg1], registers_data[instruction.arg2]);
                    last_value                       = registers_data[instruction.dest];

                case .JUMP;
                    pc_pointer = instructions_pointer + instruction.imm;

                case .JUMP_IF_FALSE;
                    value  := *registers_data[instruction.arg1];
                    truthy := false;

                    if      value.type == .BOOLEAN truthy = value.boolean;
                    else if value.type == .NUMBER  truthy = value.number != 0 && value.number == value.number;
                    else                           truthy = is_truthy(value.*);

                    if !truthy pc_pointer = instructions_pointer + instruction.imm;

                case .JUMP_IF_TRUE;
                    value  := *registers_data[instruction.arg1];
                    truthy := false;

                    if      value.type == .BOOLEAN truthy = value.boolean;
                    else if value.type == .NUMBER  truthy = value.number != 0 && value.number == value.number;
                    else                           truthy = is_truthy(value.*);

                    if truthy pc_pointer = instructions_pointer + instruction.imm;

                case .JUMP_IF_NOT_NULLISH;
                    value := *registers_data[instruction.arg1];

                    if value.type != .UNDEFINED && value.type != .NULL pc_pointer = instructions_pointer + instruction.imm;

                case .MOVE;
                    registers_data[instruction.dest] = registers_data[instruction.arg1];
                    last_value = registers_data[instruction.dest];

                case .LOGICAL_NOT;
                    registers_data[instruction.dest].type    = .BOOLEAN;
                    registers_data[instruction.dest].boolean = !is_truthy(registers_data[instruction.arg1]);

                    last_value = registers_data[instruction.dest];

                case .UNARY_MINUS;
                    value := *registers_data[instruction.arg1];

                    registers_data[instruction.dest].type   = .NUMBER;
                    registers_data[instruction.dest].number = -value_to_number(value.*);

                    last_value = registers_data[instruction.dest];

                case .SET_PROTOTYPE;
                    target    := *registers_data[instruction.dest];
                    prototype := *registers_data[instruction.arg1];

                    if target.object {
                        if prototype.object {
                            target.object.prototype = prototype.object;
                            write_barrier_object(vm, target.object, prototype.object);
                        } else if prototype.type == .NULL {
                            target.object.prototype = null;
                        }
                    }

                    last_value = target.*;

                case .SUPER_CALL;
                    print("Error: super is not implemented yet.\n");
                    return .{ type = .UNDEFINED };

                case .ADD_CONST;
                    v1 := *registers_data[instruction.arg1];
                    v2 := *constants_data[instruction.imm];

                    if v1.type == .NUMBER && v2.type == .NUMBER {
                        registers_data[instruction.dest].type   = .NUMBER;
                        registers_data[instruction.dest].number = v1.number + v2.number;
                    } else {
                        registers_data[instruction.dest] = values_addition(vm, v1.*, v2.*);

                        if vm.has_exception break;
                    }

                    last_value = registers_data[instruction.dest];

                case .SUB_CONST;
                    v1 := *registers_data[instruction.arg1];
                    v2 := *constants_data[instruction.imm];

                    if v1.type == .NUMBER && v2.type == .NUMBER {
                        registers_data[instruction.dest].type   = .NUMBER;
                        registers_data[instruction.dest].number = v1.number - v2.number;
                    } else {
                        registers_data[instruction.dest] = values_subtraction(v1.*, v2.*);

                        if vm.has_exception break;
                    }

                    last_value = registers_data[instruction.dest];

                case .ADD_REG_REG;
                    v1 := *registers_data[instruction.arg1];
                    v2 := *registers_data[instruction.arg2];

                    if v1.type == .NUMBER && v2.type == .NUMBER {
                        registers_data[instruction.dest].type   = .NUMBER;
                        registers_data[instruction.dest].number = v1.number + v2.number;
                    } else {
                        registers_data[instruction.dest] = values_addition(vm, v1.*, v2.*);

                        if vm.has_exception break;
                    }

                    last_value = registers_data[instruction.dest];

                case .JUMP_IF_LESS_THAN;
                    v1 := *registers_data[instruction.arg1];
                    v2 := *registers_data[instruction.arg2];

                    jump := false;

                    if v1.type == .NUMBER && v2.type == .NUMBER jump = v1.number < v2.number;
                    else                                        jump = values_less_than(v1.*, v2.*);

                    if jump pc_pointer = instructions_pointer + instruction.imm;

                case .INC_LOCAL;
                    v := *registers_data[instruction.imm];

                    if v.type == .NUMBER {
                        v.number += 1;
                    } else {
                        one := Value.{ type = .NUMBER, number = 1 };

                        registers_data[instruction.imm] = values_addition(vm, v.*, one);
                    }

                    last_value = registers_data[instruction.imm];

                case .DEC_LOCAL;
                    v := *registers_data[instruction.imm];

                    if v.type == .NUMBER {
                        v.number -= 1;
                    } else {
                        one := Value.{ type = .NUMBER, number = 1 };

                        registers_data[instruction.imm] = values_subtraction(v.*, one);
                    }

                    last_value = registers_data[instruction.imm];

                case .ADD_LOCAL_LOCAL;
                    v1 := *registers_data[instruction.dest];
                    v2 := *registers_data[instruction.arg1];

                    if v1.type == .NUMBER && v2.type == .NUMBER v1.number += v2.number;
                    else                                        registers_data[instruction.dest] = values_addition(vm, v1.*, v2.*);

                    last_value = registers_data[instruction.dest];

                case .SUB_LOCAL_LOCAL;
                    v1 := *registers_data[instruction.dest];
                    v2 := *registers_data[instruction.arg1];

                    if v1.type == .NUMBER && v2.type == .NUMBER v1.number -= v2.number;
                    else                                        registers_data[instruction.dest] = values_subtraction(v1.*, v2.*);

                    last_value = registers_data[instruction.dest];

                case .JUMP_IF_LOCAL_LESS_THAN_CONST;
                    v1 := *registers_data[instruction.dest];
                    v2 := *constants_data[instruction.arg1];

                    jump := false;

                    if v1.type == .NUMBER && v2.type == .NUMBER jump = v1.number < v2.number;
                    else                                        jump = values_less_than(v1.*, v2.*);

                    if jump pc_pointer = instructions_pointer + instruction.imm;

                case .TYPEOF;
                    type_name := "undefined";
                    value     := *registers_data[instruction.arg1];

                    if #complete value.type == {
                        case .UNDEFINED;       type_name = "undefined";
                        case .NULL;            type_name = "object";
                        case .NUMBER;          type_name = "number";
                        case .BOOLEAN;         type_name = "boolean";
                        case .STRING;          type_name = "string";
                        case .FUNCTION;        type_name = "function";
                        case .NATIVE_FUNCTION; type_name = "function";
                        case .OBJECT;          type_name = "object";
                        case .ARRAY;           type_name = "object";
                        case .GENERATOR;       type_name = "object";
                        case .SYMBOL;          type_name = "symbol";
                    }

                    registers_data[instruction.dest].type = .STRING;
                    registers_data[instruction.dest].s    = type_name;

                    last_value = registers_data[instruction.dest];

                case .THROW;
                    throw_exception(vm, registers_data[instruction.arg1]);

                    if generator && generator.kind == .ASYNC_EXECUTION {
                        promise_reject_inner(vm, generator.async_promise, registers_data[instruction.arg1]);
                        vm.has_exception = false;
                    }

                    if vm.has_exception break;

                    continue;

                case .YIELD;
                    if generator {
                        generator.generator_pc = cast(int)(pc_pointer - instructions_pointer);
                        return registers_data[instruction.arg1];
                    }

                    return .{};

                case .AWAIT;
                    awaited_value := *registers_data[instruction.arg1];

                    awaited_promise: Value;

                    if awaited_value.type == .OBJECT && awaited_value.object.kind == .PROMISE {
                        awaited_promise = awaited_value.*;
                    } else {
                        awaited_promise = promise_constructor(vm, .{}, .[], true);
                        promise_resolve_inner(vm, awaited_promise, awaited_value.*);
                    }

                    if generator && generator.kind == .ASYNC_EXECUTION {
                        generator.generator_pc = cast(int)(pc_pointer - instructions_pointer);

                        resumer_object := allocate_object(vm);

                        while resumer_object.fields.count <= 2 array_add(*resumer_object.fields, .{});

                        resumer_object.fields[0] = .{ type = .OBJECT, object = generator };

                        write_barrier_object(vm, resumer_object, generator);

                        resumer_object.fields[1] = .{ type = .NUMBER, number = cast(float64) instruction.dest };

                        resumer_value := Value.{
                            type            = .NATIVE_FUNCTION,
                            native_function = async_resumer,
                            object          = resumer_object,
                        };

                        promise_then(vm, awaited_promise, .[resumer_value], false);

                        return .{};
                    }

                    return .{};

                case .IMPORT;
                    source_path := vm.program.constants[instruction.imm].s;

                    found := false;
                    for vm.loaded_modules if it.path == source_path {
                        registers_data[instruction.dest] = it.exports;
                        found                            = true;

                        break;
                    }

                    if !found {
                        content, success := read_entire_file(source_path);

                        if !success {
                            throw_exception(vm, sprint("Could not load module: %", source_path));
                        } else {
                            defer free(content);

                            module_function: *Bytecode_Function;
                            {
                                push_allocator(temp);

                                error, error_message, tokens := tokenize(content);

                                if error {
                                    throw_exception(vm, copy_string(error_message));

                                    return .{};
                                }

                                ast := build_ast(content, tokens);

                                if ast.has_error {
                                    throw_exception(vm, copy_string(ast.error_message));

                                    return .{};
                                }

                                {
                                    push_allocator(vm.program.functions.allocator);
                                    module_function = generate_module_bytecode(ast, vm.program, source_path);
                                }

                                if vm.program.has_error {
                                    throw_exception(vm, copy_string(vm.program.error_message));

                                    return .{};
                                }
                            }

                            old_realm := vm.current_realm;

                            vm.current_realm         = New(Realm);
                            vm.current_realm.globals = NewArray(vm.program.globals.count, Value);

                            array_add(*vm.realms, vm.current_realm);

                            init_common_vm_globals(vm);

                            old_exports := vm.current_exports;

                            vm.current_exports = allocate_object(vm);

                            execute_function(vm, module_function);

                            module_exports := Value.{
                                type   = .OBJECT,
                                object = vm.current_exports,
                            };

                            entry := Module_Entry.{
                                path    = copy_string(source_path),
                                exports = module_exports,
                            };

                            array_add(*vm.loaded_modules, entry);

                            registers_data[instruction.dest] = module_exports;

                            vm.current_exports = old_exports;
                            vm.current_realm   = old_realm;

                            globals_data = vm.current_realm.globals.data;
                        }
                    }

                    if vm.has_exception break;

                    last_value = registers_data[instruction.dest];

                case .DYNAMIC_IMPORT;
                    source_path_value := *registers_data[instruction.arg1];
                    if source_path_value.type != .STRING {
                        throw_exception(vm, "Dynamic import requires a string argument.");
                        break;
                    }
                    source_path := source_path_value.s;

                    import_promise := promise_constructor(vm, .{}, .[], true);
                    registers_data[instruction.dest] = import_promise;

                    found := false;
                    for vm.loaded_modules if it.path == source_path {
                        promise_resolve_inner(vm, import_promise, it.exports);
                        found = true;
                        break;
                    }

                    if !found {
                        content, success := read_entire_file(source_path);

                        if !success {
                            promise_reject_inner(vm, import_promise, .{ type = .STRING, s = copy_string(sprint("Could not load module: %", source_path)) });
                        } else {
                            defer free(content);

                            module_function: *Bytecode_Function;
                            {
                                push_allocator(temp);
                                error, error_message, tokens := tokenize(content);
                                if error {
                                    promise_reject_inner(vm, import_promise, .{ type = .STRING, s = copy_string(error_message) });
                                    continue;
                                }

                                ast := build_ast(content, tokens);
                                if ast.has_error {
                                    promise_reject_inner(vm, import_promise, .{ type = .STRING, s = copy_string(ast.error_message) });
                                    continue;
                                }

                                {
                                    push_allocator(vm.program.functions.allocator);
                                    module_function = generate_module_bytecode(ast, vm.program, source_path);
                                }

                                if vm.program.has_error {
                                    promise_reject_inner(vm, import_promise, .{ type = .STRING, s = copy_string(vm.program.error_message) });
                                    continue;
                                }
                            }

                            old_realm := vm.current_realm;
                            vm.current_realm         = New(Realm);
                            vm.current_realm.globals = NewArray(vm.program.globals.count, Value);
                            array_add(*vm.realms, vm.current_realm);
                            init_common_vm_globals(vm);

                            old_exports := vm.current_exports;
                            vm.current_exports = allocate_object(vm);

                            module_result := execute_function(vm, module_function);

                            module_exports := Value.{
                                type   = .OBJECT,
                                object = vm.current_exports,
                            };

                            entry := Module_Entry.{
                                path    = copy_string(source_path),
                                exports = module_exports,

                            };
                            array_add(*vm.loaded_modules, entry);

                            promise_resolve_inner(vm, import_promise, module_exports);

                            vm.current_exports = old_exports;
                            vm.current_realm   = old_realm;

                            globals_data = vm.current_realm.globals.data;
                        }
                    }

                    if vm.has_exception break;

                    last_value = registers_data[instruction.dest];

                case .EXPORT;
                    if !vm.current_exports vm.current_exports = allocate_object(vm);

                    if instruction.imm == -2 {
                        other_module := *registers_data[instruction.arg1];

                        if other_module.type == .OBJECT {
                            object := other_module.object;

                            if object.shape {
                                for object.shape.property_names {
                                    if it == "default" continue;

                                    offset_pointer := table_find_pointer(*object.shape.property_offsets, it);

                                    if offset_pointer && offset_pointer.* < object.fields.count {
                                        value := object.fields[offset_pointer.*];

                                        if value.type != .UNDEFINED set_object_property(vm, vm.current_exports, it, value);
                                    }
                                }
                            }
                        }
                    } else {
                        property_name: string;

                        if instruction.imm == -1 property_name = "default";
                        else                     property_name = vm.program.property_names[instruction.imm];

                        set_object_property(vm, vm.current_exports, property_name, registers_data[instruction.arg1]);
                    }

                    last_value = registers_data[instruction.arg1];

                case .TRY_CONTEXT;
                    ctx := Try_Context.{
                        catch_pc  = cast(int) instruction.imm,
                        catch_reg = instruction.arg1,
                    };

                    array_add(try_stack, ctx);

                case .POP_TRY_CONTEXT;
                    if try_stack.count > initial_try_count try_stack.count -= 1;

                case .GET_KEYS;
                    argument := registers_data[instruction.arg1];

                    result := allocate_object(vm);
                    result.kind      = .ARRAY;
                    result.prototype = vm.array_prototype;

                    if argument.type == .OBJECT || argument.type == .ARRAY || argument.type == .STRING {
                        seen_keys: Table(string, bool);
                        seen_keys.allocator = temp;

                        if argument.type == .STRING {
                            for 0..argument.s.count-1 {
                                key := copy_string(tprint("%", it));
                                value := Value.{ type = .STRING, s = key };
                                array_add(*result.elements, value);
                                table_add(*seen_keys, key, true);
                            }
                        }

                        if argument.type == .OBJECT || argument.type == .ARRAY {
                            object := argument.object;
                            while object {
                                for object.elements {
                                    if it.type == .UNDEFINED continue;
                                    key := copy_string(tprint("%", it_index));
                                    if !table_contains(*seen_keys, key) {
                                        value := Value.{ type = .STRING, s = key };
                                        array_add(*result.elements, value);
                                        table_add(*seen_keys, key, true);
                                    }
                                }

                                if object.shape {
                                    for object.shape.property_names {
                                        offset_pointer := table_find_pointer(*object.shape.property_offsets, it);

                                        if !offset_pointer || offset_pointer.* >= object.fields.count continue;
                                        if object.fields[offset_pointer.*].type == .UNDEFINED         continue;

                                        if !table_contains(*seen_keys, it) {
                                            value := Value.{ type = .STRING, s = it };
                                            array_add(*result.elements, value);
                                            table_add(*seen_keys, it, true);
                                        }
                                    }
                                }

                                object = object.prototype;
                            }
                        }
                    }

                    registers_data[instruction.dest] = .{ type = .OBJECT, object = result };

                case .ITERATOR_NEXT;
                    iterable := *registers_data[instruction.arg1];

                    if (iterable.type == .ARRAY || (iterable.type == .OBJECT && iterable.object.kind == .ARRAY)) && iterable.object {
                        object := iterable.object;
                        index  := 0;

                        if object.primitive_value.type == .NUMBER index = cast(int) object.primitive_value.number;

                        if index < object.elements.count {
                            registers_data[instruction.dest] = object.elements[index];
                            object.primitive_value = .{ type = .NUMBER, number = cast(float64) (index + 1) };
                        } else {
                            pc_pointer = instructions_pointer + instruction.imm;
                        }
                    } else {
                        pc_pointer = instructions_pointer + instruction.imm;
                    }

                    last_value = registers_data[instruction.dest];

                case .ITERATOR_CLOSE;
                    iterable := *registers_data[instruction.arg1];

                    if (iterable.type == .ARRAY || (iterable.type == .OBJECT && iterable.object.kind == .ARRAY)) && iterable.object {
                        iterable.object.primitive_value = .{ type = .NUMBER, number = 0.0 };
                    }

                case .ARRAY_APPEND;
                    array_value := *registers_data[instruction.arg1];
                    iterable    := *registers_data[instruction.arg2];

                    if (array_value.type == .ARRAY || (array_value.type == .OBJECT && array_value.object.kind == .ARRAY)) && array_value.object {
                        object := array_value.object;

                        if (iterable.type == .ARRAY || (iterable.type == .OBJECT && iterable.object.kind == .ARRAY)) && iterable.object {
                            for iterable.object.elements {
                                if it.type != .UNDEFINED {
                                    array_add(*object.elements, it);
                                    write_barrier(vm, object, it);
                                }
                            }
                        } else if iterable.type == .STRING {
                            for i: 0..iterable.s.count - 1 {
                                value := Value.{
                                    type = .STRING,
                                    s    = slice(iterable.s, i, 1),
                                };

                                array_add(*object.elements, value);
                                write_barrier(vm, object, value);
                            }
                        }
                    }

                case .OBJECT_SPREAD;
                    destination_object := registers_data[instruction.dest].object;
                    source_value       := *registers_data[instruction.arg1];

                    if destination_object && (source_value.type == .OBJECT || source_value.type == .ARRAY) && source_value.object {
                        source_object := source_value.object;

                        if source_object.shape {
                            for source_object.shape.property_names {
                                offset_pointer := table_find_pointer(*source_object.shape.property_offsets, it);

                                if offset_pointer && offset_pointer.* < source_object.fields.count {
                                    if source_object.fields[offset_pointer.*].type != .UNDEFINED {
                                        set_object_property(vm, destination_object, it, source_object.fields[offset_pointer.*]);
                                    }
                                }
                            }
                        }

                        for source_object.elements {
                            if it.type != .UNDEFINED {
                                key_string := tprint("%", it_index);
                                set_object_property(vm, destination_object, key_string, it);
                            }
                        }
                    }

                case .ARRAY_PUSH;
                    array_value := *registers_data[instruction.arg1];

                    if (array_value.type == .ARRAY || (array_value.type == .OBJECT && array_value.object.kind == .ARRAY)) && array_value.object {
                        array_add(*array_value.object.elements, registers_data[instruction.arg2]);
                        write_barrier(vm, array_value.object, registers_data[instruction.arg2]);
                    }

                case .NEW_CALL_APPLY;
                    callee          := registers_data[instruction.arg1];
                    arguments_array := *registers_data[instruction.arg2];

                    if arguments_array.type == .ARRAY && arguments_array.object {
                        vm.current_function = function;
                        vm.current_pc       = pc_pointer;
                        result := call_value(vm, .{}, callee, arguments_array.object.elements, true);

                        registers_data[instruction.dest] = result;

                        last_value = result;
                    }

                case .CALL_APPLY;
                    callee          := registers_data[instruction.arg1];
                    this_value      := ifx instruction.arg2 == 255 Value.{} else registers_data[instruction.arg2];
                    arguments_array := *registers_data[instruction.imm];

                    if arguments_array.type == .ARRAY && arguments_array.object {
                        vm.current_function = function;
                        vm.current_pc       = pc_pointer;
                        result := call_value(vm, this_value, callee, arguments_array.object.elements, false);

                        registers_data[instruction.dest] = result;

                        last_value = result;
                    }

                case .ARRAY_SLICE;
                    destination_register := instruction.dest;
                    source_value         := *registers_data[instruction.arg1];
                    start_index          := instruction.imm;

                    if (source_value.type == .ARRAY || (source_value.type == .OBJECT && source_value.object.kind == .ARRAY)) && source_value.object {
                        source_object := source_value.object;

                        new_object      := allocate_object(vm);
                        new_object.kind  = .ARRAY;

                        if start_index < source_object.elements.count {
                            for start_index..source_object.elements.count - 1 {
                                array_add(*new_object.elements, source_object.elements[it]);
                                write_barrier(vm, new_object, source_object.elements[it]);
                            }
                        }

                        registers_data[destination_register].type   = .ARRAY;
                        registers_data[destination_register].object = new_object;
                    } else {
                        registers_data[destination_register].type        = .ARRAY;
                        registers_data[destination_register].object      = allocate_object(vm);
                        registers_data[destination_register].object.kind = .ARRAY;
                    }
            }
        }

        if needs_frame_init continue;

        if vm.has_exception {
            if !vm.has_stack_trace {
                generate_stack_trace(vm, function, pc_pointer);
                vm.has_stack_trace = true;
            }

            if try_stack.count > initial_try_count {
                ctx := try_stack.data[try_stack.count - 1];
                try_stack.count -= 1;
                pc_pointer = instructions_pointer + ctx.catch_pc;
                if ctx.catch_reg != 255 registers_data[ctx.catch_reg] = vm.exception;
                vm.has_exception = false;
                vm.has_stack_trace = false;
                if vm.stack_trace.data {
                    free(vm.stack_trace.data);
                    vm.stack_trace = "";
                }
                vm.exception     = .{};
                continue;
            } else {
                vm.call_stack.count -= 1;
                if env.is_captured {
                    env.next = vm.gc.environments;
                    if vm.gc.environments vm.gc.environments.previous = env;
                    env.previous = null;
                    vm.gc.environments       = env;
                    vm.gc.environment_count += 1;
                } else {
                    env.next               = vm.gc.environment_pool;
                    vm.gc.environment_pool = env;
                }

                if vm.call_frames.count == start_frame_count {
                    return .{};
                } else {
                    vm.call_frames.count -= 1;
                    frame := *vm.call_frames.data[vm.call_frames.count];

                    function             = frame.function;
                    env                  = frame.env;
                    registers            = frame.registers;
                    registers_data       = frame.registers_data;
                    try_stack            = *vm.try_context_stack;
                    initial_try_count    = frame.initial_try_count;
                    constants_data       = vm.program.constants.data;
                    instructions_pointer = frame.instructions_pointer;
                    pc_pointer           = frame.pc_pointer;
                    pc_end               = frame.pc_end;
                    globals_data         = vm.current_realm.globals.data;
                    generator            = frame.generator;

                    needs_frame_init = false;
                    continue;
                }
            }
        } else if pc_pointer >= pc_end {
            if generator generator.generator_closed = true;

            vm.call_stack.count -= 1;
            if env.is_captured {
                env.next = vm.gc.environments;
                if vm.gc.environments vm.gc.environments.previous = env;
                env.previous = null;
                vm.gc.environments       = env;
                vm.gc.environment_count += 1;
            } else {
                env.next               = vm.gc.environment_pool;
                vm.gc.environment_pool = env;
            }

            if vm.call_frames.count == start_frame_count {
                return last_value;
            } else {
                vm.call_frames.count -= 1;
                frame := *vm.call_frames.data[vm.call_frames.count];

                function             = frame.function;
                env                  = frame.env;
                registers            = frame.registers;
                registers_data       = frame.registers_data;
                try_stack            = *vm.try_context_stack;
                initial_try_count    = frame.initial_try_count;
                constants_data       = vm.program.constants.data;
                instructions_pointer = frame.instructions_pointer;
                pc_pointer           = frame.pc_pointer;
                pc_end               = frame.pc_end;
                globals_data         = vm.current_realm.globals.data;
                generator            = frame.generator;

                registers_data[frame.dest_register] = last_value;
                needs_frame_init = false;
                continue;
            }
        }
    }

    return last_value;
}

run_microtasks :: (vm: *Vm) {
    while vm.microtask_queue.count > 0 {
        task := vm.microtask_queue[0];

        array_ordered_remove_by_index(*vm.microtask_queue, 0);

        final_arguments: [1] Value;
        final_arguments[0] = task.arg;

        call_value(vm, .{}, task.callback, final_arguments);
    }
}

run_event_loop :: (vm: *Vm) {
    while vm.timer_queue.count > 0 || vm.microtask_queue.count > 0 || vm.active_background_tasks > 0 {
        if vm.microtask_queue.count > 0 {
            run_microtasks(vm);
            continue;
        }

        lock(*vm.external_events_mutex);

        events_to_process: [..] External_Event;
        events_to_process.allocator = temp;

        for vm.external_events array_add(*events_to_process, it);

        vm.external_events.count = 0;

        unlock(*vm.external_events_mutex);

        did_external := events_to_process.count > 0;

        for event: events_to_process {
            event.handler(vm, event.data);
        }

        if did_external continue;

        now              := seconds_since_init();
        next_timer_index := -1;
        next_timer_time  := 100000000.0;

        for vm.timer_queue {
            if it.trigger_time < next_timer_time {
                next_timer_time = it.trigger_time;
                next_timer_index = it_index;
            }
        }

        if next_timer_index != -1 {
            if next_timer_time > now {
                sleep_time := cast(s32) ((next_timer_time - now) * 1000);
                wait_for(*vm.event_loop_semaphore, sleep_time);
                now = seconds_since_init();
            }

            if next_timer_time <= now {
                timer := vm.timer_queue[next_timer_index];

                if !timer.is_interval {
                    array_free(timer.arguments);
                    array_unordered_remove_by_index(*vm.timer_queue, next_timer_index);
                } else {
                    vm.timer_queue[next_timer_index].trigger_time = now + timer.interval_ms / 1000.0;
                }

                call_value(vm, .{}, timer.callback, timer.arguments);
            }
        } else if vm.active_background_tasks > 0 {
            wait_for(*vm.event_loop_semaphore, -1);
        }

        reset_temporary_storage();
    }
}

call_value :: inline (vm: *Vm, this: Value, callee: Value, arguments: [] Value, is_new: bool = false) -> Value {
    arguments_copy: [256] Value;

    count := min(arguments.count, 256);

    for i: 0..count - 1 arguments_copy[i] = arguments[i];

    final_arguments: [] Value;
    final_arguments.data  = arguments_copy.data;
    final_arguments.count = count;

    if callee.type == .FUNCTION {
        if (callee.function.function.flags & .GENERATOR) {
            generator_object                := allocate_object(vm);
            generator_object.kind            = .GENERATOR;
            generator_object.generator_func  = callee.function.function;
            generator_object.generator_pc    = 0;

            for i: 0..callee.function.function.locals_count - 1 array_add(*generator_object.generator_registers, .{ type = .UNDEFINED });

            for i: 0..final_arguments.count - 1 {
                if i < generator_object.generator_registers.count generator_object.generator_registers[i] = final_arguments[i];
            }

            next_value := Value.{
                type            = .NATIVE_FUNCTION,
                native_function = generator_next,
            };

            set_object_property(vm, generator_object, "next", next_value);

            return .{ type = .GENERATOR, generator_object = generator_object };
        }

        if (callee.function.function.flags & .ASYNC) {
            promise_value := promise_constructor(vm, .{}, .[], true);

            async_object                := allocate_object(vm);
            async_object.kind            = .ASYNC_EXECUTION;
            async_object.generator_func  = callee.function.function;
            async_object.generator_pc    = 0;
            async_object.async_promise   = promise_value;

            for i: 0..callee.function.function.locals_count - 1 array_add(*async_object.generator_registers, .{ type = .UNDEFINED });

            for i: 0..final_arguments.count - 1 {
                if i < async_object.generator_registers.count async_object.generator_registers[i] = final_arguments[i];
            }

            execute_function(vm, callee.function.function, .[], .{}, async_object);

            return promise_value;
        }

        effective_this := this;

        if is_new {
            object := allocate_object(vm);

            if callee.object {
                found, prototype_value := lookup_property(vm, callee.object, "prototype");

                if found && (prototype_value.type == .OBJECT || prototype_value.type == .ARRAY) {
                    object.prototype = prototype_value.object;
                    write_barrier_object(vm, object, prototype_value.object);
                }
            }

            effective_this.type   = .OBJECT;
            effective_this.object = object;
        }

        result := execute_function(vm, callee.function.function, final_arguments, effective_this, null, callee.function.environment);

        if is_new {
            if result.type == .OBJECT || result.type == .ARRAY return result;
            return effective_this;
        }

        return result;
    } else if callee.type == .NATIVE_FUNCTION {
        effective_this := this;

        if effective_this.type == .UNDEFINED {
            if is_new {
                object := allocate_object(vm);

                if callee.object {
                    found, prototype_value := lookup_property(vm, callee.object, "prototype");

                    if found && (prototype_value.type == .OBJECT || prototype_value.type == .ARRAY) {
                        object.prototype = prototype_value.object;
                        write_barrier_object(vm, object, prototype_value.object);
                    }
                }

                effective_this.type   = .OBJECT;
                effective_this.object = object;
            } else {
                effective_this = callee;
            }
        }

        result := callee.native_function(vm, effective_this, final_arguments, is_new);

        if is_new {
            if result.type == .OBJECT || result.type == .ARRAY return result;
            return effective_this;
        }

        return result;
    }

    return .{};
}


get_global_index :: (vm: *Vm, name: string) -> found: bool, index: int {
    for vm.program.globals {
        if it == name return true, it_index;
    }

    return false, 0;
}

init_common_vm_globals :: (vm: *Vm) {
    init_vm_core(vm);
    init_vm_object(vm);
    init_vm_boolean(vm);
    init_vm_math(vm);
    init_vm_number(vm);
    init_vm_array(vm);
    init_vm_string(vm);
    init_vm_promise(vm);
    init_vm_json(vm);
    init_vm_map(vm);
    init_vm_set(vm);
    init_vm_date(vm);
    init_vm_file(vm);
    init_vm_print(vm);
    init_vm_console(vm);
    init_vm_http(vm);
    init_vm_router(vm);
    init_vm_fetch(vm);
    init_vm_global_this(vm);
    init_vm_typed_arrays(vm);
    init_vm_timer(vm);
    init_vm_error(vm);
    init_vm_regexp(vm);
    init_vm_symbol(vm);
}

init_vm_core :: (vm: *Vm) {
    found, true_index := get_global_index(vm, "true");

    if found {
        vm.current_realm.globals[true_index].type    = .BOOLEAN;
        vm.current_realm.globals[true_index].boolean = true;
    }

    false_index: int;
    found, false_index = get_global_index(vm, "false");

    if found {
        vm.current_realm.globals[false_index].type    = .BOOLEAN;
        vm.current_realm.globals[false_index].boolean = false;
    }

    undefined_index: int;
    found, undefined_index = get_global_index(vm, "undefined");

    if found {
        vm.current_realm.globals[undefined_index].type = .UNDEFINED;
    }

    null_index: int;
    found, null_index = get_global_index(vm, "null");

    if found {
        vm.current_realm.globals[null_index].type = .NULL;
    }

    realm_index: int;
    found, realm_index = get_global_index(vm, "Realm");

    if found {
        vm.current_realm.globals[realm_index].type            = .NATIVE_FUNCTION;
        vm.current_realm.globals[realm_index].native_function = realm_constructor;
    }
}

realm_constructor :: (vm: *Vm, this: Value, final_arguments: [] Value, is_new: bool) -> Value {
    realm_object           := allocate_object(vm);
    realm_object.prototype  = null;

    realm         := New(Realm);
    realm.globals  = NewArray(vm.program.globals.count, Value);

    array_add(*vm.realms, realm);

    old_realm := vm.current_realm;

    vm.current_realm = realm;

    init_common_vm_globals(vm);

    vm.current_realm = old_realm;

    realm_object.realm = realm;

    import_value := Value.{
        type            = .NATIVE_FUNCTION,
        native_function = realm_import,
    };

    set_object_property(vm, realm_object, "import", import_value);

    run_value := Value.{
        type            = .NATIVE_FUNCTION,
        native_function = realm_run,
    };

    set_object_property(vm, realm_object, "run", run_value);

    return .{ type = .OBJECT, object = realm_object };
}

realm_run :: (vm: *Vm, this: Value, final_arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.realm && final_arguments.count > 0 {
        callee := final_arguments[0];

        if callee.type == .FUNCTION {
            old_realm        := vm.current_realm;
            vm.current_realm  = this.object.realm;

            function_arguments: [] Value;
            if final_arguments.count > 1 {
                view       := final_arguments;
                view.data  += 1;
                view.count -= 1;

                function_arguments = view;
            }

            result := call_value(vm, .{}, callee, function_arguments);

            vm.current_realm = old_realm;

            return result;
        }
    }

    return .{ type = .UNDEFINED };
}

realm_import :: (vm: *Vm, this: Value, final_arguments: [] Value, is_new: bool) -> Value {
    if this.type == .OBJECT && this.object.realm && final_arguments.count > 0 {
        name_value := final_arguments[0];

        if name_value.type == .STRING {
            name := name_value.s;

            found, index := get_global_index(vm, name);;
            if found return this.object.realm.globals[index];
        }
    }

    return .{ type = .UNDEFINED };
}

generator_next :: (vm: *Vm, this: Value, final_arguments: [] Value, is_new: bool) -> Value {
    generator_object: *Gc_Object;

    if      this.type == .GENERATOR                                generator_object = this.generator_object;
    else if this.type == .OBJECT && this.object.kind == .GENERATOR generator_object = this.object;

    if !generator_object || generator_object.generator_closed {
        result := allocate_object(vm);

        set_object_property(vm, result, "value", .{ type = .UNDEFINED });
        set_object_property(vm, result, "done", .{ type = .BOOLEAN, boolean = true });

        return .{ type = .OBJECT, object = result };
    }

    function_result := execute_function(vm, generator_object.generator_func, .[], .{}, generator_object);
    is_done         := generator_object.generator_closed;
    result          := allocate_object(vm);

    set_object_property(vm, result, "value", function_result);
    set_object_property(vm, result, "done", .{ type = .BOOLEAN, boolean = is_done });

    return .{ type = .OBJECT, object = result };
}

value_to_number :: inline (value: Value) -> float64 {
    if value.type == {
        case .NUMBER;    return value.number;
        case .BOOLEAN;   return ifx value.boolean 1.0 else 0.0;
        case .STRING;    return string_to_float64(value.s);
        case .NULL;      return 0;
        case .UNDEFINED; return not_a_number_value;
        case .OBJECT;
            if value.object.primitive_value.type == .NUMBER return value.object.primitive_value.number;
    }

    return not_a_number_value;
}

value_to_string :: (vm: *Vm, value: Value) -> string {
    if #complete value.type == {
        case .UNDEFINED; return "undefined";
        case .NULL;      return "null";
        case .STRING;    return value.s;
        case .NUMBER;    return tprint("%", value.number);
        case .BOOLEAN;   return ifx value.boolean "true" else "false";
        case .SYMBOL;
            if value.symbol_object.primitive_value.type == .STRING {
                return tprint("Symbol(%)", value.symbol_object.primitive_value.s);
            } else {
                return "Symbol()";
            }

        case .OBJECT;
            if value.object.kind == .PROMISE         return "[object Promise]";
            if value.object.kind == .BOOLEAN_WRAPPER return ifx value.object.primitive_value.boolean "true" else "false";
            if value.object.kind == .GENERATOR       return "[object Generator]";

            return "[object Object]";

        case .ARRAY;           return "[object Array]";
        case .FUNCTION;        return "[object Function]";
        case .NATIVE_FUNCTION; return "[object NativeFunction]";
        case .GENERATOR;       return "[object Generator]";
    }
}

allocate_string :: (vm: *Vm, s: string) -> string {
    if !s return "";

    if vm.allocated_strings.count > 10000 {
        collect_garbage_major(vm);
    }

    result := copy_string(s);
    table_set(*vm.allocated_strings, result.data, .{ s = result, marked = false });

    return result;
}

values_addition :: (vm: *Vm, a: Value, b: Value) -> Value {
    if a.type == .NUMBER && b.type == .NUMBER {
        return .{ type = .NUMBER, number = a.number + b.number };
    }

    if a.type == .STRING || b.type == .STRING {
        if vm.allocated_strings.count > 10000 {
            collect_garbage_major(vm);
        }

        string_a := value_to_string(vm, a);
        string_b := value_to_string(vm, b);

        if string_a.count == 0 return .{ type = .STRING, s = string_b };
        if string_b.count == 0 return .{ type = .STRING, s = string_a };

        count := string_a.count + string_b.count;

        result := string.{
            data  = alloc(count),
            count = count,
        };

        memcpy(result.data, string_a.data, string_a.count);
        memcpy(result.data + string_a.count, string_b.data, string_b.count);

        table_set(*vm.allocated_strings, result.data, .{ s = result, marked = false });

        return .{ type = .STRING, s = result };
    }

    throw_exception(vm, sprint("Error: Unhandled types in values_addition: % and %\n", a.type, b.type));

    return .{};
}

values_subtraction :: (a: Value, b: Value) -> Value {
    return .{ type = .NUMBER, number = value_to_number(a) - value_to_number(b) };
}

values_multiply :: (a: Value, b: Value) -> Value {
    return .{ type = .NUMBER, number = value_to_number(a) * value_to_number(b) };
}

values_exponentiation :: (a: Value, b: Value) -> Value {
    return .{ type = .NUMBER, number = pow(value_to_number(a), value_to_number(b)) };
}

values_divide :: (a: Value, b: Value) -> Value {
    return .{ type = .NUMBER, number = value_to_number(a) / value_to_number(b) };
}

values_modulo :: inline (a: Value, b: Value) -> Value {
    return .{ type = .NUMBER, number = fmod_cycling(value_to_number(a), value_to_number(b)) };
}

values_bitwise_and :: (a: Value, b: Value) -> Value {
    value_a := cast(s32) value_to_number(a);
    value_b := cast(s32) value_to_number(b);

    return .{ type = .NUMBER, number = cast(float64) (value_a & value_b) };
}

values_bitwise_or :: (a: Value, b: Value) -> Value {
    value_a := cast(s32) value_to_number(a);
    value_b := cast(s32) value_to_number(b);

    return .{ type = .NUMBER, number = cast(float64) (value_a | value_b) };
}

values_bitwise_xor :: (a: Value, b: Value) -> Value {
    value_a := cast(s32) value_to_number(a);
    value_b := cast(s32) value_to_number(b);

    return .{ type = .NUMBER, number = cast(float64) (value_a ^ value_b) };
}

values_less_than :: (a: Value, b: Value) -> bool {
    return value_to_number(a) < value_to_number(b);
}

values_greater_than :: (a: Value, b: Value) -> bool {
    return value_to_number(a) > value_to_number(b);
}

values_less_than_equal :: (a: Value, b: Value) -> bool {
    return value_to_number(a) <= value_to_number(b);
}

values_greater_than_equal :: (a: Value, b: Value) -> bool {
    return value_to_number(a) >= value_to_number(b);
}

values_equal :: (a: Value, b: Value) -> bool {
    if a.type == b.type return values_strict_equal(a, b);

    return false;
}

values_strict_equal :: (a: Value, b: Value) -> bool {
    if a.type != b.type return false;

    if #complete a.type == {
        case .UNDEFINED;       return true;
        case .NULL;            return true;
        case .NUMBER;          return a.number               == b.number;
        case .BOOLEAN;         return a.boolean              == b.boolean;
        case .OBJECT;          return a.object               == b.object;
        case .ARRAY;           return a.object               == b.object;
        case .FUNCTION;        return a.function.function    == b.function.function;
        case .NATIVE_FUNCTION; return a.native_function      == b.native_function;
        case .STRING;          return a.s                    == b.s;
        case .GENERATOR;       return a.generator_object     == b.generator_object;
        case .SYMBOL;          return a.symbol_object        == b.symbol_object;
    }

    return false;
}

is_truthy :: (value: Value) -> bool {
    if #complete value.type == {
        case .UNDEFINED;       return false;
        case .NULL;            return false;
        case .NUMBER;          return value.number != 0 && value.number == value.number;
        case .OBJECT;          return value.object != null;
        case .ARRAY;           return value.object != null;
        case .BOOLEAN;         return value.boolean;
        case .FUNCTION;        return true;
        case .NATIVE_FUNCTION; return true;
        case .STRING;          return value.s.count > 0;
        case .GENERATOR;       return true;
        case .SYMBOL;          return true;
    }

    return false;
}

promise_resolve_inner :: (vm: *Vm, promise_value: Value, result: Value) {
    if promise_value.type == .OBJECT && promise_value.object.kind == .PROMISE {
        promise_object := promise_value.object;

        if promise_object.promise_status == .PENDING {
            promise_object.promise_status = .FULFILLED;
            promise_object.promise_result = result;

            write_barrier(vm, promise_object, result);

            for promise_object.promise_then_callbacks {
                task := Microtask.{
                    callback = it,
                    arg      = result,
                };

                array_add(*vm.microtask_queue, task);
            }

            array_reset(*promise_object.promise_then_callbacks);
        }
    }
}

promise_reject_inner :: (vm: *Vm, promise_value: Value, reason: Value) {
    if promise_value.type == .OBJECT && promise_value.object.kind == .PROMISE {
        promise_object := promise_value.object;

        if promise_object.promise_status == .PENDING {
            promise_object.promise_status = .REJECTED;
            promise_object.promise_result = reason;

            write_barrier(vm, promise_object, reason);
        }
    }
}

async_resumer :: (vm: *Vm, this: Value, final_arguments: [] Value, is_new: bool) -> Value {
    if this.type == .NATIVE_FUNCTION && this.object {
        async_object         := this.object.fields[0].object;
        destination_register := cast(int) this.object.fields[1].number;
        resolved_val         := ifx final_arguments.count > 0 final_arguments[0] else Value.{};

        async_object.generator_registers[destination_register] = resolved_val;

        execute_function(vm, async_object.generator_func, .[], .{}, async_object);
    }

    return .{};
}

deinit :: (vm: *Vm) {
    if !vm return;

    vm.current_realm = null;

    array_free(vm.microtask_queue);

    for vm.timer_queue array_free(it.arguments);
    array_free(vm.timer_queue);

    destroy(*vm.external_events_mutex);
    destroy(*vm.event_loop_semaphore);

    for * vm.builtin_prototypes it.* = null;
    for   vm.loaded_modules     free(it.path);

    array_free(vm.loaded_modules);

    vm.current_exports = null;
    vm.has_exception   = false;

    for vm.shapes {
        array_free(it.property_names);
        array_free(it.fast_offsets);

        deinit(*it.property_offsets);
        deinit(*it.transitions);

        free(it);
    }

    array_free(vm.shapes);

    free_gc_list :: (list_head: *Gc_Object) {
        current_object := list_head;

        while current_object {
            next := current_object.next;

            array_free(current_object.fields);
            array_free(current_object.elements);

            if current_object.kind == .MAP || current_object.kind == .SET {
                array_free(current_object.map_entries);
            } else if current_object.kind == .PROMISE {
                array_free(current_object.promise_then_callbacks);
            } else if current_object.kind == .GENERATOR || current_object.kind == .ASYNC_EXECUTION {
                array_free(current_object.generator_registers);
            } else if is_typed_array(current_object.kind) {
                if current_object.primitive_value.s.data free(current_object.primitive_value.s.data);
            }

            free(current_object);

            current_object = next;
        }
    }

    free_gc_list(vm.gc.young_objects);
    free_gc_list(vm.gc.old_objects);

    vm.gc.young_objects = null;
    vm.gc.old_objects = null;

    array_free(vm.gc.remembered_set);

    current_pooled_object := vm.gc.object_pool;
    while current_pooled_object {
        next := current_pooled_object.next;

        array_free(current_pooled_object.fields);
        array_free(current_pooled_object.elements);

        if current_pooled_object.kind == .MAP || current_pooled_object.kind == .SET {
            array_free(current_pooled_object.map_entries);
        } else if current_pooled_object.kind == .PROMISE {
            array_free(current_pooled_object.promise_then_callbacks);
        } else if current_pooled_object.kind == .GENERATOR || current_pooled_object.kind == .ASYNC_EXECUTION {
            array_free(current_pooled_object.generator_registers);
        }

        free(current_pooled_object);

        current_pooled_object = next;
    }

    vm.gc.object_pool = null;

    current_env := vm.gc.environments;
    while current_env {
        next := current_env.next;

        array_free(current_env.values);

        free(current_env);

        current_env = next;
    }

    vm.gc.environments = null;

    current_pooled := vm.gc.environment_pool;
    while current_pooled {
        next := current_pooled.next;

        array_free(current_pooled.values);

        free(current_pooled);

        current_pooled = next;
    }

    vm.gc.environment_pool = null;

    for vm.realms {
        if it.globals.data free(it.globals.data);

        free(it);
    }

    array_free(vm.realms);

    for v, k: vm.allocated_strings free(v.s.data);
    deinit(*vm.allocated_strings);

    if vm.profiler free(vm.profiler);

    array_free(vm.try_context_stack);
    array_free(vm.call_stack);

    free(vm);
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

generate_stack_trace :: (vm: *Vm, current_function: *Bytecode_Function, current_pc: *Instruction) {
    builder: String_Builder;
    init_string_builder(*builder);

    append_stack_frame(vm, *builder, current_function, current_pc);

    for i: 0 .. vm.call_frames.count - 1 {
        index := vm.call_frames.count - 1 - i;
        frame := vm.call_frames[index];
        append_stack_frame(vm, *builder, frame.function, frame.pc_pointer);
    }

    vm.stack_trace = builder_to_string(*builder);
}

get_stack_trace_string :: (vm: *Vm) -> string {
    builder: String_Builder;
    init_string_builder(*builder);

    if vm.current_function {
        append_stack_frame(vm, *builder, vm.current_function, vm.current_pc);
    }

    for i: 0 .. vm.call_frames.count - 1 {
        index := vm.call_frames.count - 1 - i;
        frame := vm.call_frames[index];
        append_stack_frame(vm, *builder, frame.function, frame.pc_pointer);
    }

    return builder_to_string(*builder);
}

append_stack_frame :: (vm: *Vm, builder: *String_Builder, function: *Bytecode_Function, pc: *Instruction) {
    name := function.name;
    if !name name = "<anonymous>";

    line: u32 = 0;
    if pc {
        instruction := pc - 1;
        line = instruction.line;
    }

    print_to_builder(builder, "    at % (line %)\n", name, line);
}

throw_exception :: (vm: *Vm, value: Value) {
    vm.exception = value;
    vm.has_exception = true;
}

throw_exception :: (vm: *Vm, message: string) {
    stack_trace := get_stack_trace_string(vm);

    error_object := allocate_object(vm);
    error_object.prototype = vm.error_prototype;

    message_value := Value.{ type = .STRING, s = message };
    set_object_property(vm, error_object, "message", message_value);

    stack_value := Value.{ type = .STRING, s = stack_trace };
    set_object_property(vm, error_object, "stack", stack_value);

    vm.exception = .{ type = .OBJECT, object = error_object };
    vm.has_exception = true;
    vm.has_stack_trace = true;
    vm.stack_trace = stack_trace;
}

is_typed_array :: inline (kind: Gc_Object_Kind) -> bool {
    return kind == .UINT8_ARRAY || kind == .INT8_ARRAY || kind == .UINT16_ARRAY || kind == .INT16_ARRAY ||
           kind == .UINT32_ARRAY || kind == .INT32_ARRAY || kind == .FLOAT32_ARRAY || kind == .FLOAT64_ARRAY ||
           kind == .UINT8_CLAMPED_ARRAY;
}

get_typed_array_length :: inline (object: *Gc_Object) -> int {
    length := object.primitive_value.s.count;
    if object.kind == .UINT16_ARRAY || object.kind == .INT16_ARRAY return length / 2;
    if object.kind == .UINT32_ARRAY || object.kind == .INT32_ARRAY || object.kind == .FLOAT32_ARRAY return length / 4;
    if object.kind == .FLOAT64_ARRAY return length / 8;
    return length;
}

get_typed_array_element :: inline (object: *Gc_Object, index: int) -> float64 {
    if object.kind == {
        case .UINT8_ARRAY;         return cast(float64) object.primitive_value.s[index];
        case .INT8_ARRAY;          return cast(float64) (cast(*s8) object.primitive_value.s.data)[index];
        case .UINT8_CLAMPED_ARRAY; return cast(float64) object.primitive_value.s[index];
        case .UINT16_ARRAY;        return cast(float64) (cast(*u16) object.primitive_value.s.data)[index];
        case .INT16_ARRAY;         return cast(float64) (cast(*s16) object.primitive_value.s.data)[index];
        case .UINT32_ARRAY;        return cast(float64) (cast(*u32) object.primitive_value.s.data)[index];
        case .INT32_ARRAY;         return cast(float64) (cast(*s32) object.primitive_value.s.data)[index];
        case .FLOAT32_ARRAY;       return cast(float64) (cast(*float32) object.primitive_value.s.data)[index];
        case .FLOAT64_ARRAY;       return cast(float64) (cast(*float64) object.primitive_value.s.data)[index];
    }
    return 0.0;
}

set_typed_array_element :: inline (object: *Gc_Object, index: int, val: float64) {
    if object.kind == {
        case .UINT8_ARRAY;         object.primitive_value.s[index] = cast(u8) val;
        case .INT8_ARRAY;          (cast(*s8) object.primitive_value.s.data)[index] = cast(s8) val;
        case .UINT8_CLAMPED_ARRAY; object.primitive_value.s[index] = cast(u8) max(cast(float64) 0.0, min(cast(float64) 255.0, val));
        case .UINT16_ARRAY;        (cast(*u16) object.primitive_value.s.data)[index] = cast(u16) val;
        case .INT16_ARRAY;         (cast(*s16) object.primitive_value.s.data)[index] = cast(s16) val;
        case .UINT32_ARRAY;        (cast(*u32) object.primitive_value.s.data)[index] = cast(u32) val;
        case .INT32_ARRAY;         (cast(*s32) object.primitive_value.s.data)[index] = cast(s32) val;
        case .FLOAT32_ARRAY;       (cast(*float32) object.primitive_value.s.data)[index] = cast(float32) val;
        case .FLOAT64_ARRAY;       (cast(*float64) object.primitive_value.s.data)[index] = cast(float64) val;
    }
}

Microtask :: struct {
    callback: Value;
    arg:      Value;
}

Realm :: struct {
    globals: [] Value;
}

Module_Entry :: struct {
    path:    string;
    exports: Value;
}

Call_Frame :: struct {
    function:             *Bytecode_Function;
    env:                  *Environment;
    registers:            [] Value;
    registers_data:       *Value;
    instructions_pointer: *Instruction;
    pc_pointer:           *Instruction;
    pc_end:               *Instruction;
    dest_register:        u8;
    initial_try_count:    s64;
    generator:            *Gc_Object;
}

Timer :: struct {
    id: int;
    callback: Value;
    arguments: [..] Value;
    trigger_time: float64;
    is_interval: bool;
    interval_ms: float64;
}

External_Event :: struct {
    data: *void;
    handler: (vm: *Vm, data: *void);
}

Allocated_String :: struct {
    s: string;
    marked: bool;
}

Vm :: struct {
    gc: Gc;

    permissions: Permission;

    current_realm: *Realm;
    realms:        [..] *Realm;

    shapes:        [..] *Shape;
    root_shape:    *Shape;

    union {
        builtin_prototypes: [18] *Gc_Object;
        struct {
            object_prototype:  *Gc_Object;
            number_prototype:  *Gc_Object;
            array_prototype:   *Gc_Object;
            string_prototype:  *Gc_Object;
            boolean_prototype: *Gc_Object;
            date_prototype:    *Gc_Object;
            uint8_array_prototype: *Gc_Object;
            int8_array_prototype: *Gc_Object;
            uint16_array_prototype: *Gc_Object;
            int16_array_prototype: *Gc_Object;
            uint32_array_prototype: *Gc_Object;
            int32_array_prototype: *Gc_Object;
            float32_array_prototype: *Gc_Object;
            float64_array_prototype: *Gc_Object;
            uint8_clamped_array_prototype: *Gc_Object;
            error_prototype:   *Gc_Object;
            regexp_prototype:  *Gc_Object;
            symbol_prototype:  *Gc_Object;
        };
    };

    program:         *Bytecode_Program;
    microtask_queue: [..] Microtask;
    timer_queue:     [..] Timer;
    timer_id_counter: int;

    active_background_tasks: int;

    external_events_mutex: Mutex;
    external_events:       [..] External_Event;

    event_loop_semaphore: Semaphore;

    exception:     Value;
    has_exception: bool;

    has_stack_trace: bool;
    stack_trace: string;

    allocated_strings: Table(*u8, Allocated_String);

    loaded_modules:  [..] Module_Entry;
    current_exports: *Gc_Object;

    profile: bool;
    profiler: *Profiler;

    try_context_stack: [..] Try_Context;
    call_stack:        [..] *Environment;
    call_frames:        [..] Call_Frame;

    current_function: *Bytecode_Function;
    current_pc:       *Instruction;
}

Profiler :: struct {
    instruction_counts: [256] int;
}

Environment :: struct {
    marked: bool;

    next:     *Environment;
    previous: *Environment;
    parent:   *Environment;

    values: [..] Value;

    this_value: Value;

    is_captured: bool;
}

Try_Context :: struct {
    catch_pc:  int;
    catch_reg: u8;
}

Promise_Status :: enum {
    PENDING;
    FULFILLED;
    REJECTED;
}

Gc_Object_Kind :: enum u8 {
    PLAIN;
    ARRAY;
    PROMISE;
    BOOLEAN_WRAPPER;
    GENERATOR;
    ASYNC_EXECUTION;
    GLOBAL_PROXY;
    MAP;
    SET;
    DATE;
    NUMBER_WRAPPER;
    STRING_WRAPPER;
    UINT8_ARRAY;
    INT8_ARRAY;
    UINT16_ARRAY;
    INT16_ARRAY;
    UINT32_ARRAY;
    INT32_ARRAY;
    FLOAT32_ARRAY;
    FLOAT64_ARRAY;
    UINT8_CLAMPED_ARRAY;
    REGEXP;
    SYMBOL;
}

Shape :: struct {
    marked: bool;
    property_names:   [..] string;
    property_offsets: Table(string, int);

    transitions: Table(string, *Shape);

    next_offset: int;

    fast_offsets: [..] int;
}

Gc_Object :: struct {
    marked: bool;
    is_old: bool;
    in_remembered_set: bool;
    kind:   Gc_Object_Kind;

    next: *Gc_Object;

    prototype: *Gc_Object;

    fields: [..] Value;
    elements: [..] Value;

    shape: *Shape;

    realm: *Realm;

    union {
        primitive_value: Value;

        map_entries: [..] Value;

        struct {
            promise_status:         Promise_Status;
            promise_result:         Value;
            promise_then_callbacks: [..] Value;
        };

        struct {
            async_promise:       Value;
            generator_pc:        int;
            generator_registers: [..] Value;
            generator_func:      *Bytecode_Function;
            generator_closed:    bool;
        };

        regexp: Uniform.Regexp;
    };
}

Gc :: struct {
    young_objects:      *Gc_Object;
    young_object_count: int;
    young_threshold:    int;

    old_objects:      *Gc_Object;
    old_object_count: int;
    old_threshold:    int;

    remembered_set:          [..] *Gc_Object;

    object_pool:             *Gc_Object;

    environments:      *Environment;
    environment_count: int;

    environment_pool:  *Environment;
}

zero_value_for_division: float64 = 0.0;
minimum_value:           float64 = #run  1.0 / zero_value_for_division;
maximum_value:           float64 = #run -1.0 / zero_value_for_division;
positive_infinity_value         := #run  1.0 / zero_value_for_division;
negative_infinity_value         := #run -1.0 / zero_value_for_division;
not_a_number_value              := #run  0.0 / zero_value_for_division;