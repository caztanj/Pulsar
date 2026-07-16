test_symbol :: () {
    test(() => {
        code := #string JS
            let s1 = Symbol("a");
            let s2 = Symbol("a");
            let isUnique = s1 !== s2;
        JS

        run_test(code);
        expect_global("isUnique", .BOOLEAN, true);
    });
}
