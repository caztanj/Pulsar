test_async_await :: () {
    test(() => {
        code := #string JS
            let result = 0;

            async function foo() {
                return 42;
            }

            foo().then(function(value) { result = value; });
        JS

        run_test(code);
        expect_global("result", .NUMBER, 42);
    });

    test(() => {
        code := #string JS
            let result = 0;

            async function foo() {
                let a = await 10;
                let b = await 20;

                return a + b;
            }

            foo().then(function(value) { result = value; });
        JS

        run_test(code);
        expect_global("result", .NUMBER, 30);
    });

    test(() => {
        code := #string JS
            let result = 0;

            async function foo() {
                let p = new Promise(function(resolve) {
                    resolve(100);
                });

                let value = await p;

                return value + 50;
            }

            foo().then(function(value) { result = value; });
        JS

        run_test(code);
        expect_global("result", .NUMBER, 150);
    });
}
