test_map :: () {
    test(() => {
        code := #string JS
            let m = new Map();
            m.set('a', 1);
            m.set('b', 2);
            let s = m.size;
            let a = m.get('a');
            let b = m.get('b');
            let hasA = m.has('a');
            let hasC = m.has('c');
        JS

        run_test(code);
        expect_global("s", .NUMBER, 2.0);
        expect_global("a", .NUMBER, 1.0);
        expect_global("b", .NUMBER, 2.0);
        expect_global("hasA", .BOOLEAN, true);
        expect_global("hasC", .BOOLEAN, false);
    });

    test(() => {
        code := #string JS
            let m = new Map();
            let obj = {x: 1};
            m.set(obj, 100);
            let val = m.get(obj);
            let hasObj = m.has(obj);
        JS

        run_test(code);
        expect_global("val", .NUMBER, 100.0);
        expect_global("hasObj", .BOOLEAN, true);
    });

    test(() => {
        code := #string JS
            let m = new Map();
            m.set('a', 1);
            m.delete('a');
            let hasA = m.has('a');
            let s1 = m.size;
            m.set('b', 2);
            m.clear();
            let s2 = m.size;
        JS

        run_test(code);
        expect_global("hasA", .BOOLEAN, false);
        expect_global("s1", .NUMBER, 0.0);
        expect_global("s2", .NUMBER, 0.0);
    });
}
