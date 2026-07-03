test_automatic_semicolon_insertion :: () {
    test(() => {
        code := #string JS
            let x = 1
            let y = 2
        JS

        run_test(code);
        expect_global("x", .NUMBER, 1);
        expect_global("y", .NUMBER, 2);
    });

    test(() => {
        code := #string JS
            function f() {
                return
                    42
            };

            let result = f();
        JS

        run_test(code);
        expect_global("result", .UNDEFINED, null);
    });

    test(() => {
        code := #string JS
            let x = 1 + 2
            let y = x * 2
        JS

        run_test(code);
        expect_global("x", .NUMBER, 3);
        expect_global("y", .NUMBER, 6);
    });

    test(() => {
        code := #string JS
            let x = 10
            let y = 20
            let z = x + y
        JS

        run_test(code);
        expect_global("z", .NUMBER, 30);
    });

    test(() => {
        code := #string JS
            function f() { let x = 5 } let y = f();
        JS

        run_test(code);
        expect_global("y", .NUMBER, 5);
    });
}
