test_closures :: () {
    test(() => {
        code := #string JS
            function outer() {
                let x = 10;

                function inner() {
                    return x;
                }

                return inner;
            }

            let f = outer();
            let result = f();
        JS

        run_test(code);
        expect_global("result", .NUMBER, 10);
    });

    test(() => {
        code := #string JS
            function outer() {
                let x = 10;

                function inc() {
                    x = x + 1;
                }

                function get() {
                    return x;
                }

                return [inc, get];
            }

            let funcs = outer();
            let inc = funcs[0];
            let get = funcs[1];

            inc();

            let result1 = get();

            inc();

            let result2 = get();
        JS

        run_test(code);
        expect_global("result1", .NUMBER, 11);
        expect_global("result2", .NUMBER, 12);
    });

    test(() => {
        code := #string JS
            function outer(x) {
                return function(y) {
                    return x + y;
                };
            }

            let f = outer(10);
            let result = f(5);
        JS

        run_test(code);
        expect_global("result", .NUMBER, 15);
    });

    test(() => {
        code := #string JS
            function outer() {
                let x = 0;

                return function() {
                    x = x + 1;

                    return x;
                };
            }

            let f1 = outer();
            let f2 = outer();

            let result1 = f1();
            let result2 = f1();
            let result3 = f2();
        JS

        run_test(code);
        expect_global("result1", .NUMBER, 1);
        expect_global("result2", .NUMBER, 2);
        expect_global("result3", .NUMBER, 1);
    });

    test(() => {
        code := #string JS
            function outer(x) {
                return function() {
                    return x;
                };
            }

            let f = outer(42);
            let result = f();
        JS

        run_test(code);
        expect_global("result", .NUMBER, 42);
    });

    test(() => {
        code := #string JS
            function foo() {
                let funcs = [];

                for (let i = 0; i < 3; i = i + 1) {
                    funcs.push(function() {
                        return i;
                    });
                }

                return funcs;
            }

            let fs = foo();
            let f0 = fs[0];
            let f1 = fs[1];
            let f2 = fs[2];
            let r0 = f0();
            let r1 = f1();
            let r2 = f2();
        JS

        run_test(code);
        expect_global("r0", .NUMBER, 3);
        expect_global("r1", .NUMBER, 3);
        expect_global("r2", .NUMBER, 3);
    });

    test(() => {
        code := #string JS
            function a(x) {
                return function(y) {
                    return function(z) {
                        return x + y + z;
                    };
                };
            }

            let f1 = a(10);
            let f2 = f1(20);
            let result = f2(30);
        JS

        run_test(code);
        expect_global("result", .NUMBER, 60);
    });
}
