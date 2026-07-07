test_regexp :: () {
    test(() => {
        code := #string JS
            let r = new RegExp('foo');
            let t = r.test('foobar');
        JS

        run_test(code);
        expect_global("t", .BOOLEAN, true);
    });

    test(() => {
        code := #string JS
            let r = new RegExp('bar');
            let t = r.test('foo');
        JS

        run_test(code);
        expect_global("t", .BOOLEAN, false);
    });

    test(() => {
        code := #string JS
            let r = new RegExp('hello');
            let match = r.exec('hello world');
            let matched = match !== null && match[0] === 'hello';
        JS

        run_test(code);
        expect_global("matched", .BOOLEAN, true);
    });

    test(() => {
        code := #string JS
            let r = new RegExp('o(o)');
            let match = r.exec('foobar');
            let matched = match !== null && match[0] === 'oo' && match[1] === 'o';
        JS

        run_test(code);
        expect_global("matched", .BOOLEAN, true);
    });
}
