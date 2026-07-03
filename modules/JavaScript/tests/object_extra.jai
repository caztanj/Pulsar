test_object_extra :: () {
    test(() => {
        code := #string JS
            let obj = { a: 1, b: 2 };
            let keys = Object.keys(obj);
            let values = Object.values(obj);
            let entries = Object.entries(obj);
        JS

        run_test(code);

        expect_array_count("keys", 2);
        expect_array_element("keys", 0, .STRING, "a");
        expect_array_element("keys", 1, .STRING, "b");

        expect_array_count("values", 2);
        expect_array_element("values", 0, .NUMBER, 1.0);
        expect_array_element("values", 1, .NUMBER, 2.0);

        expect_array_count("entries", 2);
        e0 := expect_array_element("entries", 0, .ARRAY, null);
        expect_array_count(e0, 2);
        expect_array_element(e0, 0, .STRING, "a");
        expect_array_element(e0, 1, .NUMBER, 1.0);
    });

    test(() => {
        code := #string JS
            let target = { a: 1 };
            let source = { b: 2, c: 3 };
            Object.assign(target, source);
        JS

        run_test(code);

        expect_object_fields_count("target", 3);
    });

    test(() => {
        code := #string JS
            let a = [3, 1, 2, 5, 4];
            a.sort();
            let s = a.join(',');
        JS

        run_test(code);
        expect_global("s", .STRING, "1,2,3,4,5");
    });

    test(() => {
        code := #string JS
            let a = [3, 1, 2, 5, 4];
            a.sort(function(x, y) {
                return y - x;
            });
            let s = a.join(',');
        JS

        run_test(code);
        expect_global("s", .STRING, "5,4,3,2,1");
    });

    test(() => {
        code := #string JS
            let m = new Map();
            m.set('a', 1);
            m.set('b', 2);
            let sum = 0;
            m.forEach(function(v) {
                sum += v;
            });
        JS

        run_test(code);
        expect_global("sum", .NUMBER, 3);
    });

    test(() => {
        code := #string JS
            let s = new Set();
            s.add(10);
            s.add(20);
            let sum = 0;
            s.forEach(function(v) {
                sum += v;
            });
        JS

        run_test(code);
        expect_global("sum", .NUMBER, 30);
    });

    test(() => {
        code := #string JS
            let s = 'hello world';
            let s2 = s.replace('world', 'jai');
        JS

        run_test(code);
        expect_global("s2", .STRING, "hello jai");
    });
}
