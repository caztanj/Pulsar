test_date :: () {
    test(() => {
        code := #string JS
            let d = new Date(1600000000000);
            let res = d.getTime();
        JS

        run_test(code);
        expect_global("res", .NUMBER, 1600000000000.0);
    });

    test(() => {
        code := #string JS
            let d = new Date(1600000000000);
            let res = d.getFullYear();
        JS

        run_test(code);
        expect_global("res", .NUMBER, 2020.0);
    });

    test(() => {
        code := #string JS
            let d = new Date(1600000000000);
            let res = d.getMonth();
        JS

        run_test(code);
        expect_global("res", .NUMBER, 8.0);
    });

    test(() => {
        code := #string JS
            let d = new Date(1600000000000);
            let res = d.getDate();
        JS

        run_test(code);
        res := get_global(context.vm, "res");
        expect_type(res, .NUMBER);
        expect_true(res.number == 13.0 || res.number == 14.0);
    });

    test(() => {
        code := #string JS
            let d = new Date(1600000000000);
            let res = d.toISOString();
        JS

        run_test(code);
        expect_global("res", .STRING, "2020-09-13T12:26:40.000Z");
    });

    test(() => {
        code := #string JS
            let n1 = Date.now();
            let n2 = Date.now();
            let res = n2 >= n1;
        JS

        run_test(code);
        expect_global("res", .BOOLEAN, true);
    });
}
