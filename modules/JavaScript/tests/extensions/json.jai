test_json :: () {
    test(() => {
        code := #string JS
            let res = JSON.stringify(null);
        JS

        run_test(code);
        expect_global("res", .STRING, "null");
    });

    test(() => {
        code := #string JS
            let res = JSON.stringify(true);
        JS

        run_test(code);
        expect_global("res", .STRING, "true");
    });

    test(() => {
        code := #string JS
            let res = JSON.stringify(123.45);
        JS

        run_test(code);
        expect_global("res", .STRING, "123.45");
    });

    test(() => {
        code := #string JS
            let res = JSON.stringify("hello");
        JS

        run_test(code);
        expect_global("res", .STRING, "\"hello\"");
    });

    test(() => {
        code := #string JS
            let res = JSON.stringify([1, 2, 3]);
        JS

        run_test(code);
        expect_global("res", .STRING, "[1,2,3]");
    });

    test(() => {
        code := #string JS
            let res = JSON.stringify({a: 1, b: "test"});
        JS

        run_test(code);
        expect_global("res", .STRING, "{\"a\":1,\"b\":\"test\"}");
    });

    test(() => {
        code := #string JS
            let res = JSON.parse("123");
        JS

        run_test(code);
        expect_global("res", .NUMBER, 123.0);
    });

    test(() => {
        code := #string JS
            let res = JSON.parse("[1, 2, 3]");
        JS

        run_test(code);
        expect_global("res", .ARRAY, null);
        res := get_global(context.vm, "res");
        expect_array_count(res, 3);
        expect_array_element(res, 0, .NUMBER, 1);
        expect_array_element(res, 1, .NUMBER, 2);
        expect_array_element(res, 2, .NUMBER, 3);
    });

    test(() => {
        code := #string JS
            let obj = JSON.parse('{a: 123}');
            let res = obj.a;
        JS

        run_test(code);
        expect_global("res", .NUMBER, 123.0);
    });

    test(() => {
        code := #string JS
            let obj = JSON.parse('{a: [1, 2], b: {c: 3}}');
            let res = obj.a[1] + obj.b.c;
        JS

        run_test(code);
        expect_global("res", .NUMBER, 5.0);
    });
}
