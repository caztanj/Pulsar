test_math :: () {
    test(() => {
        code := #string JS
            let a = Math.min();
        JS

        run_test(code);
        expect_true(get_global(context.vm, "a") == get_global(context.vm, "Infinity"));
    });

    test(() => {
        code := #string JS
            let a = Math.min(1);
        JS

        run_test(code);
        expect_global("a", .NUMBER, 1.0);
    });

    test(() => {
        code := #string JS
            let a = Math.min(8, 3, 4, 5);
        JS

        run_test(code);
        expect_global("a", .NUMBER, 3.0);
    });

    test(() => {
        code := #string JS
            let a = Math.max();
        JS

        run_test(code);
        negative_infinity := get_global(context.vm, "Infinity");
        negative_infinity.number = -negative_infinity.number;

        expect_true(get_global(context.vm, "a") == negative_infinity);
    });

    test(() => {
        code := #string JS
            let a = Math.max(2);
        JS

        run_test(code);
        expect_global("a", .NUMBER, 2.0);
    });

    test(() => {
        code := #string JS
            let a = Math.max(1, -2, 3);
        JS

        run_test(code);
        expect_global("a", .NUMBER, 3.0);
    });

    test(() => {
        code := #string JS
            let a = Math.sqrt(16);
        JS

        run_test(code);
        expect_global("a", .NUMBER, 4.0);
    });

    test(() => {
        code := #string JS
            let a = Math.abs(-5);
        JS

        run_test(code);
        expect_global("a", .NUMBER, 5.0);
    });

    test(() => {
        code := #string JS
            let a = Math.floor(1.9);
        JS

        run_test(code);
        expect_global("a", .NUMBER, 1.0);
    });

    test(() => {
        code := #string JS
            let a = Math.ceil(1.1);
        JS

        run_test(code);
        expect_global("a", .NUMBER, 2.0);
    });

    test(() => {
        code := #string JS
            let a = Math.round(1.5);
        JS

        run_test(code);
        expect_global("a", .NUMBER, 2.0);
    });

    test(() => {
        code := #string JS
            let a = Math.random();
        JS

        run_test(code);
        val := get_global(context.vm, "a");
        expect_type(val, .NUMBER);
        expect_true(val.number >= 0.0 && val.number < 1.0);
    });

    test(() => {
        code := #string JS
            let a = Math.PI;
        JS

        run_test(code);
        expect_global("a", .NUMBER, 3.141592653589793);
    });

    test(() => {
        code := #string JS
            let a = Math.E;
        JS

        run_test(code);
        expect_global("a", .NUMBER, 2.718281828459045);
    });

    test(() => {
        code := #string JS
            let a = Math.trunc(13.37);
            let b = Math.trunc(-13.37);
        JS

        run_test(code);
        expect_global("a", .NUMBER, 13.0);
        expect_global("b", .NUMBER, -13.0);
    });

    test(() => {
        code := #string JS
            let a = Math.sign(5);
            let b = Math.sign(-5);
            let c = Math.sign(0);
        JS

        run_test(code);
        expect_global("a", .NUMBER, 1.0);
        expect_global("b", .NUMBER, -1.0);
        expect_global("c", .NUMBER, 0.0);
    });

    test(() => {
        code := #string JS
            let a = Math.cbrt(8);
            let b = Math.cbrt(-27);
        JS

        run_test(code);
        expect_global("a", .NUMBER, 2.0);
        
        b := get_global(context.vm, "b");
        expect_true(b.type == .NUMBER && (b.number > -3.00001 && b.number < -2.99999));
    });

    test(() => {
        code := #string JS
            let a = Math.pow(2, 3);
            let b = Math.pow(9, 0.5);
        JS

        run_test(code);
        expect_global("a", .NUMBER, 8.0);
        
        b_val := get_global(context.vm, "b");
        expect_true(b_val.type == .NUMBER && (b_val.number > 2.99999 && b_val.number < 3.00001));
    });

    test(() => {
        code := #string JS
            let a = Math.asin(1);
            let b = Math.acos(0);
            let c = Math.atan(1);
            let d = Math.atan2(1, 1);
            let e = Math.log2(8);
        JS

        run_test(code);
        expect_true(abs(get_global(context.vm, "a").number - 1.570796) < 0.000001);
        expect_true(abs(get_global(context.vm, "b").number - 1.570796) < 0.000001);
        expect_true(abs(get_global(context.vm, "c").number - 0.785398) < 0.000001);
        expect_true(abs(get_global(context.vm, "d").number - 0.785398) < 0.000001);
        expect_true(abs(get_global(context.vm, "e").number - 3.0) < 0.000001);
    });

    test(() => {
        code := #string JS
            let a = Math.min(0, -0);
            let b = Math.max(0, -0);
        JS

        run_test(code);
        a := get_global(context.vm, "a");
        b := get_global(context.vm, "b");
        expect_true(a.type == .NUMBER && (cast(*u64) *a.number).* == 0x8000000000000000);
        expect_true(b.type == .NUMBER && (cast(*u64) *b.number).* == 0x0000000000000000);
    });
}
