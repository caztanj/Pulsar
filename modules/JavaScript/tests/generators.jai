test_generators :: () {
    test(() => {
        code := #string JS
            function* gen() {
                yield 1;
                yield 2;
                return 3;
            }

            let g = gen();
            let r1 = g.next();
            let r2 = g.next();
            let r3 = g.next();
            let r4 = g.next();
        JS

        run_test(code);
        expect_global_property("r1", .OBJECT, "value", .NUMBER, 1);
        expect_global_property("r1", .OBJECT, "done", .BOOLEAN, false);
        expect_global_property("r2", .OBJECT, "value", .NUMBER, 2);
        expect_global_property("r2", .OBJECT, "done", .BOOLEAN, false);
        expect_global_property("r3", .OBJECT, "value", .NUMBER, 3);
        expect_global_property("r3", .OBJECT, "done", .BOOLEAN, true);
        expect_global_property("r4", .OBJECT, "value", .UNDEFINED, null);
        expect_global_property("r4", .OBJECT, "done", .BOOLEAN, true);
    });
}
