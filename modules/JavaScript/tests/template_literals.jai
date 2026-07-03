test_template_literals :: () {
    test(() => {
        code := #string JS
            let s = `hello`;
        JS

        run_test(code);
        expect_global("s", .STRING, "hello");
    });

    test(() => {
        code := #string JS
            let name = 'World';
            let s = `hello ${name}`;
        JS

        run_test(code);
        expect_global("s", .STRING, "hello World");
    });

    test(() => {
        code := #string JS
            let s = `1 + 1 = ${1 + 1}`;
        JS

        run_test(code);
        expect_global("s", .STRING, "1 + 1 = 2");
    });

    test(() => {
        code := #string JS
            let s = `${1}${2}${3}`;
        JS

        run_test(code);
        expect_global("s", .STRING, "123");
    });

    test(() => {
        code := #string JS
            let c = 'nested';
            let s = `a ${ `b ${c}` } d`;
        JS

        run_test(code);
        expect_global("s", .STRING, "a b nested d");
    });

    test(() => {
        code := #string JS
            let s = `\`backtick\``;
        JS

        run_test(code);
        expect_global("s", .STRING, "`backtick`");
    });

    test(() => {
        code := #string JS
            let s = `multi\nline`;
        JS

        run_test(code);
        expect_global("s", .STRING, "multi\nline");
    });

    test(() => {
        code := #string JS
            let x = 10;
            let s = `x is ${x > 5 ? 'big' : 'small'}`;
        JS

        run_test(code);
        expect_global("s", .STRING, "x is big");
    });
}
