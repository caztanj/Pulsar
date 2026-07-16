test_timer :: () {
    test(() => {
        code := #string JS
            let x = 0;
            let id = setTimeout(() => {
                x = 42;
            }, 10);
            
            let y = 0;
            let id2 = setTimeout(() => {
                y = 100;
            }, 10);
            clearTimeout(id2);
        JS

        run_test(code);
        expect_global("x", .NUMBER, 42.0);
        expect_global("y", .NUMBER, 0.0);
    });

    test(() => {
        code := #string JS
            let count = 0;
            let id = setInterval(() => {
                count++;
                if (count >= 3) {
                    clearInterval(id);
                }
            }, 5);
        JS

        run_test(code);
        expect_global("count", .NUMBER, 3.0);
    });
}
