test_promise :: () {
    test(() => {
        code := #string JS
            let x = 0;
            let p = new Promise(function(resolve) { resolve(42); });
            p.then(function(val) { x = val; });
        JS

        run_test(code);
        expect_global("x", .NUMBER, 42.0);
    });

    test(() => {
        code := #string JS
            let x = 0;
            let y = 0;
            let p = new Promise(function(resolve) { resolve(100); });
            p.then(function(val) { x = val; });
            p.then(function(val) { y = val + 50; });
        JS

        run_test(code);
        expect_global("x", .NUMBER, 100.0);
        expect_global("y", .NUMBER, 150.0);
    });

    test(() => {
        code := #string JS
            let x = 0;
            let p = new Promise(function(resolve) { resolve(10); });
            p.then(function(v) { x = x + v; }).then(function(v) { x = x + v; });
        JS

        run_test(code);
        expect_global("x", .NUMBER, 20.0);
    });

    test(() => {
        code := #string JS
            let x = 0;
            let res;
            let p = new Promise(function(resolve) { res = resolve; });
            p.then(function(val) { x = val; });
            res(77);
        JS

        run_test(code);
        expect_global("x", .NUMBER, 77.0);
    });

    test(() => {
        code := #string JS
            let x = 1;
            let p = new Promise(function(resolve) { resolve(); });
            p.then(function(val) { x = val; });
        JS

        run_test(code);
        expect_global("x", .UNDEFINED, null);
    });
}
