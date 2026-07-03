test_recursion :: () {
    test(() => {
        code := #string JS
            function factorial(n) {
                if (n <= 1) return 1;
                return n * factorial(n - 1);
            }

            let result = factorial(5);
        JS

        run_test(code);
        expect_global("result", .NUMBER, 120);
    });

    test(() => {
        code := #string JS
            function fib(n) {
                if (n <= 1) return n;
                return fib(n - 1) + fib(n - 2);
            }

            let result = fib(10);
        JS

        run_test(code);
        expect_global("result", .NUMBER, 55);
    });

    test(() => {
        code := #string JS
            function is_even(n) {
                if (n == 0) return true;
                return is_odd(n - 1);
            }

            function is_odd(n) {
                if (n == 0) return false;
                return is_even(n - 1);
            }

            let result1 = is_even(4);
            let result2 = is_odd(4);
        JS

        run_test(code);
        expect_global("result1", .BOOLEAN, true);
        expect_global("result2", .BOOLEAN, false);
    });

    test(() => {
        code := #string JS
            function outer() {
                function inner(n) {
                    if (n <= 0) return 0;
                    return n + inner(n - 1);
                }

                return inner(5);
            }

            let result = outer();
        JS

        run_test(code);
        expect_global("result", .NUMBER, 15);
    });

    test(() => {
        code := #string JS
            let obj = {
                factorial: function(n) {
                    if (n <= 1) return 1;
                    return n * this.factorial(n - 1);
                }
            };

            let result = obj.factorial(5);
        JS

        run_test(code);
        expect_global("result", .NUMBER, 120);
    });
}
