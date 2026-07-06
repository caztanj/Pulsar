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

    test(() => {
        code := #string JS
            let x = 0;
            try {
                x = 1;
            } finally {
                x = 2;
            }
            let result = x;
        JS

        run_test(code);
        expect_global("result", .NUMBER, 2);
    });

    test(() => {
        code := #string JS
            let x = 0;
            try {
                throw 42;
            } catch (e) {
                x = 1;
            } finally {
                x = 2;
            }
            let result = x;
        JS

        run_test(code);
        expect_global("result", .NUMBER, 2);
    });

    test(() => {
        code := #string JS
            let x = 0;
            let caught = 0;
            try {
                try {
                    throw 10;
                } finally {
                    x = 1;
                }
            } catch (e) {
                caught = e;
            }
            let result_x = x;
            let result_caught = caught;
        JS

        run_test(code);
        expect_global("result_x", .NUMBER, 1);
        expect_global("result_caught", .NUMBER, 10);
    });
}
