test_loops :: () {
    test(() => {
        code := #string JS
            let x = 0;

            while (x < 5) {
                x = x + 1;
            }
        JS

        run_test(code);
        expect_global("x", .NUMBER, 5);
    });

    test(() => {
        code := #string JS
            let x = 0;

            for (let i = 0; i < 10; i = i + 1) {
                x = x + 1;
            }
        JS

        run_test(code);
        expect_global("x", .NUMBER, 10);
    });

    test(() => {
        code := #string JS
            let sum = 0;
            let arr = [10, 20, 30];

            for (let x of arr) {
                sum = sum + x;
            }

            let result = sum;
        JS

        run_test(code);
        expect_global("result", .NUMBER, 60);
    });

    test(() => {
        code := #string JS
            let x = 0;

            while (true) {
                x = x + 1;
                if (x == 5) break;
            }
        JS

        run_test(code);
        expect_global("x", .NUMBER, 5);
    });

    test(() => {
        code := #string JS
            let x = 0;

            for (let i = 0; i < 10; i = i + 1) {
                if (i == 5) break;
                x = x + 1;
            }
        JS

        run_test(code);
        expect_global("x", .NUMBER, 5);
    });

    test(() => {
        code := #string JS
            let x = 0;
            let arr = [1, 2, 3, 4, 5];

            for (let v of arr) {
                if (v == 3) break;
                x = x + v;
            }
        JS

        run_test(code);
        expect_global("x", .NUMBER, 3);
    });

    test(() => {
        code := #string JS
            let x = 0;

            for (let i = 0; i < 10; i = i + 1) {
                if (i < 5) continue;
                x = x + 1;
            }
        JS

        run_test(code);
        expect_global("x", .NUMBER, 5);
    });

    test(() => {
        code := #string JS
            let x = 0;
            let i = 0;

            while (i < 10) {
                i = i + 1;
                if (i <= 5) continue;
                x = x + 1;
            }
        JS

        run_test(code);
        expect_global("x", .NUMBER, 5);
    });

    test(() => {
        code := #string JS
            let x = 0;
            let arr = [1, 2, 3, 4, 5];

            for (let v of arr) {
                if (v <= 2) continue;
                x = x + 1;
            }
        JS

        run_test(code);
        expect_global("x", .NUMBER, 3);
    });
    test(() => {
        code := #string JS
            let keys = "";
            let obj = { a: 1, b: 2 };
            for (let k in obj) {
                keys = keys + k;
            }
        JS

        run_test(code);
        expect_global("keys", .STRING, "ab");
    });

    test(() => {
        code := #string JS
            let keys = "";
            let obj = [10, 20];
            for (let k in obj) {
                keys = keys + k;
            }
        JS

        run_test(code);
        expect_global("keys", .STRING, "01");
    });
}
