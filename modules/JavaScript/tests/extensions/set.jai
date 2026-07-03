test_set :: () {
    test(() => {
        code := #string JS
            let s = new Set();
            s.add(1);
            s.add(2);
            s.add(1);
            let size = s.size();
            let has1 = s.has(1);
            let has3 = s.has(3);
        JS

        run_test(code);
        expect_global("size", .NUMBER, 2.0);
        expect_global("has1", .BOOLEAN, true);
        expect_global("has3", .BOOLEAN, false);
    });

    test(() => {
        code := #string JS
            let s = new Set();
            s.add('a');
            s.delete('a');
            let hasA = s.has('a');
            let s1 = s.size();
            s.add('b');
            s.clear();
            let s2 = s.size();
        JS

        run_test(code);
        expect_global("hasA", .BOOLEAN, false);
        expect_global("s1", .NUMBER, 0.0);
        expect_global("s2", .NUMBER, 0.0);
    });
}
