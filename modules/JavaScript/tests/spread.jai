test_spread :: () {
    test(() => {
        code := #string JS
            let a = [1, 2];
            let b = [...a, 3, 4];
        JS

        run_test(code);

        b := get_global(context.vm, "b");
        expect_type(b, .ARRAY);
        expect_array_count(b, 4);
        expect_array_element(b, 0, .NUMBER, 1.0);
        expect_array_element(b, 1, .NUMBER, 2.0);
        expect_array_element(b, 2, .NUMBER, 3);
        expect_array_element(b, 3, .NUMBER, 4);
    });

    test(() => {
        code := #string JS
            let a = { x: 1, y: 2 };
            let b = { ...a, z: 3 };
        JS

        run_test(code);
        expect_global_property("b", .OBJECT, "x", .NUMBER, 1);
        expect_global_property("b", .OBJECT, "y", .NUMBER, 2);
        expect_global_property("b", .OBJECT, "z", .NUMBER, 3);
    });

    test(() => {
        code := #string JS
            function f(a, b, ...c) {
                return c;
            }

            let result = f(1, 2, 3, 4, 5);
        JS

        run_test(code);

        result := get_global(context.vm, "result");
        expect_type(result, .ARRAY);
        expect_array_count(result, 3);
        expect_array_element(result, 0, .NUMBER, 3.0);
        expect_array_element(result, 1, .NUMBER, 4.0);
        expect_array_element(result, 2, .NUMBER, 5.0);
    });

    test(() => {
        code := #string JS
            let a = [1, 2, 3, 4];
            let [b, c, ...d] = a;
        JS

        run_test(code);
        expect_global("b", .NUMBER, 1);
        expect_global("c", .NUMBER, 2);

        d := get_global(context.vm, "d");
        expect_type(d, .ARRAY);
        expect_array_count(d, 2);
        expect_array_element(d, 0, .NUMBER, 3.0);
        expect_array_element(d, 1, .NUMBER, 4.0);
    });

    test(() => {
        code := #string JS
            function f(a, b, c) {
                return a + b + c;
            }

            let args = [1, 2, 3];
            let result = f(...args);
        JS

        run_test(code);
        expect_global("result", .NUMBER, 6);
    });
}
