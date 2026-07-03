test_array :: () {
    test(() => {
        code := #string JS
            let a = [1, 2, 3];
            a.push(4, 5);
            let len = a.length;
            let s = a.join('-');
            let p = a.pop();
            let len2 = a.length;
            let isArr = Array.isArray(a);
            let isNotArr = Array.isArray(5);
            let sh = a.shift();
            a.push(10);
            let idx = a.indexOf(3);
            let idx2 = a.indexOf(100);
        JS

        run_test(code);
        expect_global("len", .NUMBER, 5.0);
        expect_global("s", .STRING, "1-2-3-4-5");
        expect_global("p", .NUMBER, 5.0);
        expect_global("len2", .NUMBER, 4.0);
        expect_global("isArr", .BOOLEAN, true);
        expect_global("isNotArr", .BOOLEAN, false);
        expect_global("sh", .NUMBER, 1.0);
        expect_global("idx", .NUMBER, 1.0);
        expect_global("idx2", .NUMBER, -1.0);
    });

    test(() => {
        code := #string JS
            let sum = 0;
            [1, 2, 3].forEach(function(x) { sum = sum + x; });
        JS

        run_test(code);
        expect_global("sum", .NUMBER, 6.0);
    });

    test(() => {
        code := #string JS
            let a = [1, 2, 3].map(function(x) { return x * 2; });
        JS

        run_test(code);
        expect_global("a", .ARRAY, null);
        a := get_global(context.vm, "a");
        expect_array_count(a, 3);
        expect_array_element(a, 0, .NUMBER, 2.0);
        expect_array_element(a, 1, .NUMBER, 4.0);
        expect_array_element(a, 2, .NUMBER, 6.0);
    });

    test(() => {
        code := #string JS
            let a = [1, 2, 3, 4].filter(function(x) { return x % 2 == 0; });
        JS

        run_test(code);
        expect_global("a", .ARRAY, null);
        a := get_global(context.vm, "a");
        expect_array_count(a, 2);
        expect_array_element(a, 0, .NUMBER, 2.0);
        expect_array_element(a, 1, .NUMBER, 4.0);
    });

    test(() => {
        code := #string JS
            let sum = [1, 2, 3, 4].reduce(function(a, b) { return a + b; }, 0);
        JS

        run_test(code);
        expect_global("sum", .NUMBER, 10.0);
    });

    test(() => {
        code := #string JS
            let sum = [1, 2, 3, 4].reduce(function(a, b) { return a + b; });
        JS

        run_test(code);
        expect_global("sum", .NUMBER, 10.0);
    });

    test(() => {
        code := #string JS
            let res = [1, 2, 3].reduce(function(a, b, i) { a.push(i); return a; }, []);
        JS

        run_test(code);
        expect_global("res", .ARRAY, null);
        res := get_global(context.vm, "res");
        expect_array_count(res, 3);
        expect_array_element(res, 0, .NUMBER, 0.0);
        expect_array_element(res, 1, .NUMBER, 1.0);
        expect_array_element(res, 2, .NUMBER, 2.0);
    });

    test(() => {
        code := #string JS
            let a = [1, 2, 3];
            a.reverse();
            let s = a.join(',');
        JS

        run_test(code);
        expect_global("s", .STRING, "3,2,1");
    });

    test(() => {
        code := #string JS
            let a = [1, 2];
            let b = a.concat([3, 4], 5);
            let s = b.join(',');
        JS

        run_test(code);
        expect_global("s", .STRING, "1,2,3,4,5");
    });

    test(() => {
        code := #string JS
            let a = [1, 2, 3, 4, 5];
            let b = a.splice(1, 2, 10, 20);
            let s1 = a.join(',');
            let s2 = b.join(',');
        JS

        run_test(code);
        expect_global("s1", .STRING, "1,10,20,4,5");
        expect_global("s2", .STRING, "2,3");
    });

    test(() => {
        code := #string JS
            let a = [5, 2, 8, 1, 4];
            a.sort();
            let s = a.join(',');
        JS

        run_test(code);
        expect_global("s", .STRING, "1,2,4,5,8");
    });

    test(() => {
        code := #string JS
            let a = [5, 2, 8, 1, 4];
            a.sort(function(x, y) { return y - x; });
            let s = a.join(',');
        JS

        run_test(code);
        expect_global("s", .STRING, "8,5,4,2,1");
    });

    test(() => {
        code := #string JS
            let a1 = Array.from('abc');
            let a2 = Array.of(1, 2, 3);
            let valAt = a1.at(-1);
            let flat = [1, [2, [3]]].flat(2);
            let flatMap = [1, 2].flatMap(x => [x, x * 2]);
            let filled = [0, 0, 0].fill(7, 1);
        JS

        run_test(code);
        expect_global("a1", .ARRAY, null);
        a1 := get_global(context.vm, "a1");
        expect_array_count(a1, 3);
        expect_array_element(a1, 0, .STRING, "a");

        expect_global("a2", .ARRAY, null);
        a2 := get_global(context.vm, "a2");
        expect_array_count(a2, 3);
        expect_array_element(a2, 2, .NUMBER, 3.0);

        expect_global("valAt", .STRING, "c");

        expect_global("flat", .ARRAY, null);
        flat := get_global(context.vm, "flat");
        expect_array_count(flat, 3);
        expect_array_element(flat, 2, .NUMBER, 3.0);

        expect_global("flatMap", .ARRAY, null);
        flatMap := get_global(context.vm, "flatMap");
        expect_array_count(flatMap, 4);
        expect_array_element(flatMap, 3, .NUMBER, 4.0);

        expect_global("filled", .ARRAY, null);
        filled := get_global(context.vm, "filled");
        expect_array_element(filled, 0, .NUMBER, 0.0);
        expect_array_element(filled, 1, .NUMBER, 7.0);
        expect_array_element(filled, 2, .NUMBER, 7.0);
    });
}
