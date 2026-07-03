test_operators :: () {
    test(() => {
        code := #string JS
            let s = 'hello ' + 'world';
        JS

        run_test(code);
        expect_global("s", .STRING, "hello world");
    });

    test(() => {
        code := #string JS
            let s = 'number: ' + 42;
        JS

        run_test(code);
        expect_global("s", .STRING, "number: 42");
    });

    test(() => {
        code := #string JS
            let a = true && false;
            let b = true || false;
            let c = !true;
            let d = typeof 5;
            let e = -10;
            let f = (false && (1 / 0));
            let g = (true || (1 / 0));
        JS

        run_test(code);
        expect_global("a", .BOOLEAN, false);
        expect_global("b", .BOOLEAN, true);
        expect_global("c", .BOOLEAN, false);
        expect_global("d", .STRING, "number");
        expect_global("e", .NUMBER, -10);
        expect_global("f", .BOOLEAN, false);
        expect_global("g", .BOOLEAN, true);
    });

    test(() => {
        code := #string JS
            let result = 10 % 3;
        JS

        run_test(code);
        expect_global("result", .NUMBER, 1);
    });

    test(() => {
        code := #string JS
            let result = 10 % 5;
        JS

        run_test(code);
        expect_global("result", .NUMBER, 0);
    });

    test(() => {
        code := #string JS
            let result = 7 % 2;
        JS

        run_test(code);
        expect_global("result", .NUMBER, 1);
    });

    test(() => {
        code := #string JS
            let result = 10 % 2.5;
        JS

        run_test(code);
        expect_global("result", .NUMBER, 0);
    });

    test(() => {
        code := #string JS
            let x = 0;
            for (let i = 0; i < 10; i = i + 1) {
                if (i % 2 == 0) continue;
                x = x + 1;
            }
        JS

        run_test(code);
        expect_global("x", .NUMBER, 5);
    });

    test(() => {
        code := #string JS
            let x = 10;
            let a = ++x;
            let b = x++;
            let c = --x;
            let d = x--;
        JS

        run_test(code);
        expect_global("x", .NUMBER, 10);
        expect_global("a", .NUMBER, 11);
        expect_global("b", .NUMBER, 11);
        expect_global("c", .NUMBER, 11);
        expect_global("d", .NUMBER, 11);
    });

    test(() => {
        code := #string JS
            let log1 = (10 || 20);
            let log2 = (0 || 20);
            let log3 = (10 && 20);
            let log4 = (0 && 20);
        JS

        run_test(code);
        expect_global("log1", .NUMBER, 10);
        expect_global("log2", .NUMBER, 20);
        expect_global("log3", .NUMBER, 20);
        expect_global("log4", .NUMBER, 0);
    });

    test(() => {
        code := #string JS
            let obj = {};
            obj['foo'] = 42;
            let result = obj.foo;
            let arr = [1, 2];
            arr[1] = 10;
            let result2 = arr[1];
        JS

        run_test(code);
        expect_global("result", .NUMBER, 42);
        expect_global("result2", .NUMBER, 10);
    });

    test(() => {
        code := #string JS
            let obj = { a: 1 };
            let result1 = 'a' in obj;
            let result2 = 'b' in obj;
        JS

        run_test(code);
        expect_global("result1", .BOOLEAN, true);
        expect_global("result2", .BOOLEAN, false);
    });

    test(() => {
        code := #string JS
            let arr = [10, 20];
            let result1 = '0' in arr;
            let result2 = '1' in arr;
            let result3 = '2' in arr;
        JS

        run_test(code);
        expect_global("result1", .BOOLEAN, true);
        expect_global("result2", .BOOLEAN, true);
        expect_global("result3", .BOOLEAN, false);
    });

    test(() => {
        code := #string JS
            function Foo() {}
            let f = new Foo();
            let result1 = f instanceof Foo;
            let result2 = f instanceof Object;
        JS

        run_test(code);
        expect_global("result1", .BOOLEAN, true);
        expect_global("result2", .BOOLEAN, true);
    });

    test(() => {
        code := #string JS
            let a = 5 & 1;
            let b = 5 | 2;
            let c = 5 ^ 3;
            let d = 5.5 & 1.1;
        JS

        run_test(code);
        expect_global("a", .NUMBER, 1);
        expect_global("b", .NUMBER, 7);
        expect_global("c", .NUMBER, 6);
        expect_global("d", .NUMBER, 1);
    });

    test(() => {
        code := #string JS
            let x = 10;
            x += 5;
            let y = 20;
            y -= 5;
            let z = 10;
            z *= 2;
            let w = 10;
            w /= 2;
            let s = 'hello';
            s += ' world';
        JS

        run_test(code);
        expect_global("x", .NUMBER, 15);
        expect_global("y", .NUMBER, 15);
        expect_global("z", .NUMBER, 20);
        expect_global("w", .NUMBER, 5);
        expect_global("s", .STRING, "hello world");
    });

    test(() => {
        code := #string JS
            let x = 2 ** 3;
            let y = 2 ** 3 ** 2;
            let z = 2;
            z **= 3;
        JS

        run_test(code);

        expect_global_approx("x", 8.0);
        expect_global_approx("y", 512.0);
        expect_global_approx("z", 8.0);
    });

    test(() => {
        code := #string JS
            let a = null ?? 'default';
            let b = undefined ?? 'default';
            let c = 0 ?? 'default';
            let d = '' ?? 'default';
            let e = false ?? 'default';
        JS

        run_test(code);
        expect_global("a", .STRING, "default");
        expect_global("b", .STRING, "default");
        expect_global("c", .NUMBER, 0);
        expect_global("d", .STRING, "");
        expect_global("e", .BOOLEAN, false);
    });

    test(() => {
        code := #string JS
            let a = true ? 10 : 20;
            let b = false ? 10 : 20;
            let c = (1 > 0) ? 'yes' : 'no';
            let d = (0 > 1) ? 'yes' : 'no';
            let e = 1 ? 'truthy' : 'falsy';
            let f = 0 ? 'truthy' : 'falsy';
        JS

        run_test(code);
        expect_global("a", .NUMBER, 10);
        expect_global("b", .NUMBER, 20);
        expect_global("c", .STRING, "yes");
        expect_global("d", .STRING, "no");
        expect_global("e", .STRING, "truthy");
        expect_global("f", .STRING, "falsy");
    });
}