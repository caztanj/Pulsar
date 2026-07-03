test_arrow_functions :: () {
    test(() => {
        code := #string JS
            const add = (a, b) => a + b;
            const result = add(1, 2);
        JS;

        run_test(code);
        expect_global("result", .NUMBER, 3);
    });

    test(() => {
        code := #string JS
            const square = x => {
                return x * x;
            };

            const result = square(4);
        JS;

        run_test(code);
        expect_global("result", .NUMBER, 16);
    });

    test(() => {
        code := #string JS
            const getObject = () => ({ a: 1 });
            const result = getObject().a;
        JS;

        run_test(code);
        expect_global("result", .NUMBER, 1);
    });

    test(() => {
        code := #string JS
            const nested = x => y => x + y;
            const result = nested(1)(2);
        JS;

        run_test(code);
        expect_global("result", .NUMBER, 3);
    });

    test(() => {
        code := #string JS
            const withThis = {
                x: 42,
                get: function() {
                    return () => this.x;
                }
            };

            const result = withThis.get()();
        JS;

        run_test(code);
        expect_global("result", .NUMBER, 42);
    });

    test(() => {
        code := #string JS
            const asyncAdd = async (a, b) => a + b;
            let result = 0;
            asyncAdd(1, 2).then(v => { result = v; });
        JS;

        run_test(code);
        run_microtasks(context.vm);
        expect_global("result", .NUMBER, 3);
    });
}
