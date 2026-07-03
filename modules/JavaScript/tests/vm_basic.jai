test_vm_basic :: () {
    test(() => {
        code := #string JS
            let x = 10;
            let y = 20;
            let z = x + y;
        JS

        run_test(code);
        expect_global("x", .NUMBER, 10.0);
        expect_global("y", .NUMBER, 20.0);
        expect_global("z", .NUMBER, 30.0);
    });

    test(() => {
        code := #string JS
            let a = [10, 20, 30];
            let b = a[1];
        JS

        run_test(code);
        expect_global("a", .ARRAY, null);
        a := get_global(context.vm, "a");
        expect_array_count(a, 3);
        expect_global("b", .NUMBER, 20.0);
    });

    test(() => {
        code := #string JS
            let o = {x: 10, y: 20};
            let z = o.x + o.y;
        JS

        run_test(code);
        expect_global("o", .OBJECT, null);
        expect_global("z", .NUMBER, 30.0);
    });

    test(() => {
        code := #string JS
            let a = [1, 2, 3, 4];
            let b = a.length;
            let s = 'hello';
            let c = s.length;
            let d = [].length;
            let e = ''.length;
        JS

        run_test(code);
        expect_global("b", .NUMBER, 4.0);
        expect_global("c", .NUMBER, 5.0);
        expect_global("d", .NUMBER, 0.0);
        expect_global("e", .NUMBER, 0.0);
    });
}
