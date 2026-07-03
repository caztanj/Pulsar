test_number :: () {
    test(() => {
        code := #string JS
            let a = Infinity;
            let b = Number.POSITIVE_INFINITY;
            let c = Number.NEGATIVE_INFINITY;
            let d = -Infinity;
            let e = Infinity + 1;
            let f = Infinity * 2;
            let g = 1 / Infinity;
            let h = 1 / 0;
        JS

        run_test(code);
        a := get_global(context.vm, "a");
        b := get_global(context.vm, "b");
        c := get_global(context.vm, "c");
        d := get_global(context.vm, "d");
        e := get_global(context.vm, "e");
        f := get_global(context.vm, "f");
        g := get_global(context.vm, "g");
        h := get_global(context.vm, "h");

        zero_value: float64 = 0.0;
        v1 := a.number;
        v2 := 1.0 / zero_value;
        p1 := *v1;
        p2 := *v2;
        u1 := (cast(*u64) p1).*;
        u2 := (cast(*u64) p2).*;
        expect_equals(u1, u2);
        expect_true(b.number == 1.0 / zero_value);
        expect_true(c.number == -1.0 / zero_value);
        expect_true(d.number == -1.0 / zero_value);
        expect_true(e.number == 1.0 / zero_value);
        expect_true(f.number == 1.0 / zero_value);
        expect_equals(g.number, 0.0);
        expect_true(h.number == 1.0 / zero_value);
    });

    test(() => {
        code := #string JS
            let n1 = Number(123);
            let n2 = new Number(456);
            let v2 = n2.valueOf();
            let s2 = n2.toString();
            let f1 = Number.isFinite(123);
            let f2 = Number.isFinite(Infinity);
            let i1 = Number.isInteger(123);
            let i2 = Number.isInteger(123.456);
            let nan1 = Number.isNaN(NaN);
            let nan2 = Number.isNaN(123);
            let s1 = Number.isSafeInteger(9007199254740991);
            let s2_safe = Number.isSafeInteger(9007199254740992);
            let p1 = Number.parseFloat('123.456');
            let p2 = Number.parseInt('123');
            let tf = (123.456).toFixed(2);
            let maxv = Number.MAX_VALUE;
            let minv = Number.MIN_VALUE;
        JS

        run_test(code);
        expect_global("n1", .NUMBER, 123.0);
        expect_global("n2", .OBJECT, null);
        expect_global("v2", .NUMBER, 456.0);
        expect_global("s2", .STRING, "456");
        expect_global("f1", .BOOLEAN, true);
        expect_global("f2", .BOOLEAN, false);
        expect_global("i1", .BOOLEAN, true);
        expect_global("i2", .BOOLEAN, false);
        expect_global("nan1", .BOOLEAN, true);
        expect_global("nan2", .BOOLEAN, false);
        expect_global("s1", .BOOLEAN, true);
        expect_global("s2_safe", .BOOLEAN, false);
        expect_global("p1", .NUMBER, cast(float64) 123.456);
        expect_global("p2", .NUMBER, 123.0);
        expect_global("tf", .STRING, "123.46");
        expect_global("maxv", .NUMBER, 1.7976931348623157e+308);
        expect_global("minv", .NUMBER, 4.9406564584124654e-324);
    });
}
