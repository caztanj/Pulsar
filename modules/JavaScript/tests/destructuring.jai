test_destructuring :: () {
    test(() => {
        code := #string JS
            let a;
            let b;
            [a, b] = [1, 2];
        JS

        run_test(code);
        expect_global("a", .NUMBER, 1);
        expect_global("b", .NUMBER, 2);
    });

    test(() => {
        code := #string JS
            let [a, b] = [100, 200];
        JS

        run_test(code);
        expect_global("a", .NUMBER, 100);
        expect_global("b", .NUMBER, 200);
    });

    test(() => {
        code := #string JS
            let { x, y } = { x: 300, y: 400 };
        JS

        run_test(code);
        expect_global("x", .NUMBER, 300);
        expect_global("y", .NUMBER, 400);
    });

    test(() => {
        code := #string JS
            let { a: x, b: y } = { a: 10, b: 20 };
        JS

        run_test(code);
        expect_global("x", .NUMBER, 10);
        expect_global("y", .NUMBER, 20);
    });

    test(() => {
        code := #string JS
            let [a, [b, c]] = [1, [2, 3]];
        JS

        run_test(code);
        expect_global("a", .NUMBER, 1);
        expect_global("b", .NUMBER, 2);
        expect_global("c", .NUMBER, 3);
    });

    test(() => {
        code := #string JS
            let arr = [[1, 2]];
            let a;
            let b;
            for ([a, b] of arr) {}
        JS

        run_test(code);
        expect_global("a", .NUMBER, 1);
        expect_global("b", .NUMBER, 2);
    });
}
