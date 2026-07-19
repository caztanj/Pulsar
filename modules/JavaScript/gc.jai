init_gc :: (gc: *Gc) {
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
    to_remove: [..] string;

    for current_shape: vm.shapes {
        if current_shape.marked {
            for target_shape, name: current_shape.transitions {
                if !target_shape.marked array_add(*to_remove, name);
            }
            for name: to_remove table_remove(*current_shape.transitions, name);
            to_remove.count = 0;
        }
    }
    
    array_free(to_remove);

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
            } else if unreachable.kind == .REGEXP {
                Uniform.uninit(*unreachable.regexp);
            } else if is_typed_array(unreachable.kind) {
                if unreachable.primitive_value.s.data free(unreachable.primitive_value.s.data);
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
                } else if is_typed_array(unreachable.kind) {
                    if unreachable.primitive_value.s.data free(unreachable.primitive_value.s.data);
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

