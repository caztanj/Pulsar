test_gc :: () {
    add_to_globals :: (val: Value) {
        new_globals := NewArray(context.vm.current_realm.globals.count + 1, Value);
        for context.vm.current_realm.globals new_globals[it_index] = it;
        new_globals[new_globals.count - 1] = val;
        context.vm.current_realm.globals = new_globals;
    }

    total_objects :: (vm: *Vm) -> int {
        return vm.gc.young_object_count + vm.gc.old_object_count;
    }

    test(() => {
        run_test("");
        collect_garbage_major(context.vm);
        baseline := total_objects(context.vm);

        obj1 := allocate_object(context.vm);
        obj2 := allocate_object(context.vm);
        expect_total_objects(baseline + 2);

        add_to_globals(.{type = .OBJECT, object = obj1});

        collect_garbage_major(context.vm);
        expect_total_objects(baseline + 1);
        expect_true(context.vm.gc.old_objects == obj1 || context.vm.gc.young_objects == obj1);

        context.vm.current_realm.globals[context.vm.current_realm.globals.count - 1].object = null;
        collect_garbage_major(context.vm);
        expect_total_objects(baseline);
    });

    test(() => {
        run_test("");
        collect_garbage_major(context.vm);
        baseline := total_objects(context.vm);

        parent := allocate_object(context.vm);
        child := allocate_object(context.vm);
        expect_total_objects(baseline + 2);

        array_add(*parent.fields, .{type = .OBJECT, object = child});
        add_to_globals(.{type = .OBJECT, object = parent});

        collect_garbage_major(context.vm);
        expect_total_objects(baseline + 2);

        context.vm.current_realm.globals[context.vm.current_realm.globals.count - 1].object = null;
        collect_garbage_major(context.vm);
        expect_total_objects(baseline);
    });

    test(() => {
        run_test("");
        collect_garbage_major(context.vm);
        baseline := total_objects(context.vm);
        collect_garbage_major(context.vm);
        expect_total_objects(baseline);
    });

    test(() => {
        run_test("");
        collect_garbage_major(context.vm);
        baseline := total_objects(context.vm);
        obj := allocate_object(context.vm);
        expect_total_objects(baseline + 1);
        collect_garbage_major(context.vm);
        expect_total_objects(baseline);
    });

    test(() => {
        run_test("");
        collect_garbage_major(context.vm);
        baseline := total_objects(context.vm);
        obj := allocate_object(context.vm);
        throw_exception(context.vm, .{type = .OBJECT, object = obj});
        collect_garbage_major(context.vm);
        expect_total_objects(baseline + 1);
    });

    test(() => {
        run_test("");
        collect_garbage_major(context.vm);
        baseline := total_objects(context.vm);
        obj := allocate_object(context.vm);
        add_to_globals(.{type = .OBJECT, object = obj});
        collect_garbage_major(context.vm);
        expect_total_objects(baseline + 1);
    });

    test(() => {
        run_test("");
        collect_garbage_major(context.vm);
        baseline := total_objects(context.vm);
        obj1 := allocate_object(context.vm);
        obj2 := allocate_object(context.vm);
        array_add(*obj1.fields, .{type = .OBJECT, object = obj2});

        throw_exception(context.vm, .{type = .OBJECT, object = obj1});
        collect_garbage_major(context.vm);
        expect_total_objects(baseline + 2);

        context.vm.exception = .{type = .UNDEFINED};
        context.vm.has_exception = false;
        collect_garbage_major(context.vm);
        expect_total_objects(baseline);
    });

    test(() => {
        run_test("");
        collect_garbage_major(context.vm);
        baseline := total_objects(context.vm);
        obj1 := allocate_object(context.vm);
        obj2 := allocate_object(context.vm);
        array_add(*obj1.fields, .{type = .OBJECT, object = obj2});
        array_add(*obj2.fields, .{type = .OBJECT, object = obj1});
        collect_garbage_major(context.vm);
        expect_total_objects(baseline);
    });

    test(() => {
        run_test("");
        collect_garbage_major(context.vm);
        baseline := total_objects(context.vm);
        obj1 := allocate_object(context.vm);
        obj2 := allocate_object(context.vm);
        obj1.prototype = obj2;

        throw_exception(context.vm, .{type = .OBJECT, object = obj1});
        collect_garbage_major(context.vm);
        expect_total_objects(baseline + 2);
    });

    test(() => {
        run_test("");
        collect_garbage_major(context.vm);
        baseline := total_objects(context.vm);
        obj1 := allocate_object(context.vm);
        obj1.kind = .ARRAY;

        obj2 := allocate_object(context.vm);
        array_add(*obj1.fields, .{type = .OBJECT, object = obj2});

        throw_exception(context.vm, .{type = .ARRAY, object = obj1});
        collect_garbage_major(context.vm);
        expect_total_objects(baseline + 2);
    });

    test(() => {
        run_test("");
        collect_garbage_major(context.vm);
        baseline := total_objects(context.vm);
        obj1 := allocate_object(context.vm);
        obj1.kind = .PROMISE;
        obj2 := allocate_object(context.vm);
        obj3 := allocate_object(context.vm);
        obj1.promise_result = .{type = .OBJECT, object = obj2};
        array_add(*obj1.promise_then_callbacks, .{type = .OBJECT, object = obj3});

        throw_exception(context.vm, .{type = .OBJECT, object = obj1});
        collect_garbage_major(context.vm);
        expect_total_objects(baseline + 3);
    });

    test(() => {
        run_test("");
        collect_garbage_major(context.vm);
        baseline := total_objects(context.vm);
        obj1 := allocate_object(context.vm);
        obj1.kind = .GENERATOR;
        obj2 := allocate_object(context.vm);
        array_add(*obj1.generator_registers, .{type = .OBJECT, object = obj2});

        throw_exception(context.vm, .{type = .GENERATOR, generator_object = obj1});
        collect_garbage_major(context.vm);
        expect_total_objects(baseline + 2);
    });

    test(() => {
        run_test("");
        collect_garbage_major(context.vm);
        baseline := total_objects(context.vm);
        obj1 := allocate_object(context.vm);
        obj1.kind = .ASYNC_EXECUTION;
        obj2 := allocate_object(context.vm);
        obj1.async_promise = .{type = .OBJECT, object = obj2};

        throw_exception(context.vm, .{type = .OBJECT, object = obj1});
        collect_garbage_major(context.vm);
        expect_total_objects(baseline + 2);
    });

    test(() => {
        run_test("");
        collect_garbage_major(context.vm);
        baseline := total_objects(context.vm);
        obj1 := allocate_object(context.vm);
        task: Microtask;
        task.callback = .{type = .OBJECT, object = obj1};
        array_add(*context.vm.microtask_queue, task);
        collect_garbage_major(context.vm);
        expect_total_objects(baseline + 1);
    });

    test(() => {
        run_test("");
        collect_garbage_major(context.vm);
        baseline := total_objects(context.vm);
        obj1 := allocate_object(context.vm);
        throw_exception(context.vm, .{type = .OBJECT, object = obj1});
        collect_garbage_major(context.vm);
        expect_total_objects(baseline + 1);
    });

    test(() => {
        run_test("");
        collect_garbage_major(context.vm);
        baseline := total_objects(context.vm);
        obj1 := allocate_object(context.vm);
        context.vm.builtin_prototypes[0] = obj1;
        collect_garbage_major(context.vm);
        expect_total_objects(baseline + 1);
    });

    test(() => {
        run_test("");
        collect_garbage_major(context.vm);
        baseline := total_objects(context.vm);
        obj1 := allocate_object(context.vm);
        obj2 := allocate_object(context.vm);
        obj1.primitive_value = .{type = .OBJECT, object = obj2};

        throw_exception(context.vm, .{type = .OBJECT, object = obj1});
        collect_garbage_major(context.vm);
        expect_total_objects(baseline + 2);
    });

    test(() => {
        run_test("");
        collect_garbage_major(context.vm);
        baseline := total_objects(context.vm);
        obj1 := allocate_object(context.vm);
        realm := New(Realm);
        realm.globals = NewArray(1, Value);
        array_add(*context.vm.realms, realm);
        obj1.realm = realm;
        obj2 := allocate_object(context.vm);
        realm.globals[0] = .{type = .OBJECT, object = obj2};

        throw_exception(context.vm, .{type = .OBJECT, object = obj1});
        collect_garbage_major(context.vm);
        expect_total_objects(baseline + 2);
    });
}