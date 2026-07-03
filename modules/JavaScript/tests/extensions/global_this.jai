test_global_this :: () {
    test(() => {
        code := #string JS
            let result = (globalThis === globalThis.globalThis);
        JS

        run_test(code);
        expect_global("result", .BOOLEAN, true);
    });

    test(() => {
        code := #string JS
            let x = 10;
            let result = (globalThis.x === 10);
        JS

        run_test(code);
        expect_global("result", .BOOLEAN, true);
    });

    test(() => {
        code := #string JS
            let y = 0;
            globalThis.y = 42;
            let result = y;
        JS

        run_test(code);
        expect_global("y", .NUMBER, 42.0);
        expect_global("result", .NUMBER, 42.0);
    });

    test(() => {
        code := #string JS
            let x = 0;
            async function foo() { globalThis.x = 100; }
            foo();
        JS

        run_test(code);
        expect_global("x", .NUMBER, 100.0);
    });
}
