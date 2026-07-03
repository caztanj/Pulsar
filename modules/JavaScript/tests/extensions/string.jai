test_string :: () {
    test(() => {
        code := #string JS
            let s = 'hello world';
            let idx = s.indexOf('world');
            let sub = s.substring(0, 5);
            let upper = s.toUpperCase();
            let lower = upper.toLowerCase();
            let char = s.charAt(0);
            let inc = s.includes('hello');
            let rep = 'abc'.repeat(3);
            let t = '  trim  '.trim();
            let len = s.length;
            let parts = 'a,b,c'.split(',');
            let count = parts.length;
            let p0 = parts[0];
            let p1 = parts[1];
            let p2 = parts[2];
        JS

        run_test(code);
        expect_global("idx", .NUMBER, 6.0);
        expect_global("sub", .STRING, "hello");
        expect_global("upper", .STRING, "HELLO WORLD");
        expect_global("lower", .STRING, "hello world");
        expect_global("char", .STRING, "h");
        expect_global("inc", .BOOLEAN, true);
        expect_global("rep", .STRING, "abcabcabc");
        expect_global("t", .STRING, "trim");
        expect_global("len", .NUMBER, 11.0);
        expect_global("count", .NUMBER, 3.0);
        expect_global("p0", .STRING, "a");
        expect_global("p1", .STRING, "b");
        expect_global("p2", .STRING, "c");
    });

    test(() => {
        code := #string JS
            let s = 'abc';
            let ps = s.padStart(5, '0');
            let pe = s.padEnd(5, '!');
            let ts = '  abc'.trimStart();
            let te = 'abc  '.trimEnd();
            let sat = s.at(-1);
        JS

        run_test(code);
        expect_global("ps", .STRING, "00abc");
        expect_global("pe", .STRING, "abc!!");
        expect_global("ts", .STRING, "abc");
        expect_global("te", .STRING, "abc");
        expect_global("sat", .STRING, "c");
    });
}
