test_realms :: () {
    test(() => {
        code := #string JS
            let x = 10;
            let r = new Realm();
            r.run(function() {
                x = 20;
            });
            let y = r.import('x');
            let z = x;
        JS

        run_test(code);
        expect_global("x", .NUMBER, 10);
        expect_global("y", .NUMBER, 20);
        expect_global("z", .NUMBER, 10);
    });

    test(() => {
        code := #string JS
            let x = 1;
        JS


        run_test(code);

        main_realm := context.vm.current_realm;
        new_realm  := create_realm(context.vm);

        expect_global("x", .NUMBER, 1);

        switch_realm(context.vm, new_realm);

        expect_global("x", .UNDEFINED, null);

        set_global(context.vm, "x", .{ type = .NUMBER, number = 2.0 });
        expect_global("x", .NUMBER, cast(float64) 2.0);

        switch_realm(context.vm, main_realm);
        expect_global("x", .NUMBER, cast(float64) 1.0);
    });

    test(() => {
        code := #string JS
            var a = 'global';
        JS

        run_test(code);

        r1 := create_realm(context.vm);
        r2 := create_realm(context.vm);

        switch_realm(context.vm, r1);
        set_global(context.vm, "a", .{ type = .STRING, s = "realm1" });

        switch_realm(context.vm, r2);
        set_global(context.vm, "a", .{ type = .STRING, s = "realm2" });

        switch_realm(context.vm, r1);
        expect_global("a", .STRING, "realm1");

        switch_realm(context.vm, r2);
        expect_global("a", .STRING, "realm2");
    });

    test(() => {
        code := #string JS
            Array.prototype.myMethod = function() { return 42; };
        JS

        run_test(code);

        r2 := create_realm(context.vm);
        switch_realm(context.vm, r2);

        expect_global_property("Array", .OBJECT, "prototype", .OBJECT, context.vm.array_prototype);

        expect_property_exists(context.vm.array_prototype, "myMethod");

        result := run_in_realm(context.vm, "[].myMethod()");
        expect_value(result, .NUMBER, 42.0);
    });
}

run_in_realm :: (vm: *Vm, code: string) -> Value {
    tokens: [] Token;
    ast:    *Ast_Program;

    {
        push_allocator(temp);
        _, _, tokens = tokenize(code);
        ast    = build_ast(code, tokens);
    }

    program := generate_bytecode(ast, vm.program);

    return execute_main(vm, program);
}
