test_boolean :: () {
    test(() => {
        code := #string JS
            let result = Boolean(true) === true;
        JS

        run_test(code);
        expect_global("result", .BOOLEAN, true);
    });

    test(() => {
        code := #string JS
            let result = Boolean(false) === false;
        JS

        run_test(code);
        expect_global("result", .BOOLEAN, true);
    });

    test(() => {
        code := #string JS
            let result = Boolean(0) === false;
        JS

        run_test(code);
        expect_global("result", .BOOLEAN, true);
    });

    test(() => {
        code := #string JS
            let result = Boolean(1) === true;
        JS

        run_test(code);
        expect_global("result", .BOOLEAN, true);
    });

    test(() => {
        code := #string JS
            let result = Boolean("") === false;
        JS

        run_test(code);
        expect_global("result", .BOOLEAN, true);
    });

    test(() => {
        code := #string JS
            let result = Boolean("hello") === true;
        JS

        run_test(code);
        expect_global("result", .BOOLEAN, true);
    });

    test(() => {
        code := #string JS
            let b = new Boolean(true);
            let result = b.valueOf() === true;
        JS

        run_test(code);
        expect_global("result", .BOOLEAN, true);
    });

    test(() => {
        code := #string JS
            let b = new Boolean(false);
            let result = b.toString() === "false";
        JS

        run_test(code);
        expect_global("result", .BOOLEAN, true);
    });

    test(() => {
        code := #string JS
            let b = new Boolean(true);
            let result = (typeof b === "object");
        JS

        run_test(code);
        expect_global("b", .OBJECT, null);
        expect_global("result", .BOOLEAN, true);
    });
}
