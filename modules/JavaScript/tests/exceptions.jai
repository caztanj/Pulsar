test_exceptions :: () {
    test(() => {
        code := #string JS
            let x = 0;

            try {
                throw 42;
            } catch (e) {
                x = e;
            }

            let result = x;
        JS

        run_test(code);
        expect_global("result", .NUMBER, 42);
    });

    test(() => {
        code := #string JS
            let x = 0;

            try {
                x = 10;
            } catch (e) {
                x = 20;
            }

            let result = x;
        JS

        run_test(code);
        expect_global("result", .NUMBER, 10);
    });

    test(() => {
        code := #string JS
            let x = 0;

            function foo() {
                throw 100;
            }

            try {
                foo();
            } catch (e) {
                x = e;
            }

            let result = x;
        JS

        run_test(code);
        expect_global("result", .NUMBER, 100);
    });
}
