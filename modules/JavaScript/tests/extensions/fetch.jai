test_fetch :: () {
    test("fetch permission denied", () => {
        code := #string JS
            let error = '';
            try { fetch("http://example.com"); } catch (e) { error = e; }
        JS

        run_test(code);
        expect_global("error", .STRING, "Permission denied: Requires NETWORK permission.");
    });

    test("fetch successful request", () => {
        code := #string JS
            let status = 0;
            let ok = false;

            fetch("http://example.com").then(res => {
                status = res.status;
                ok = res.ok;
            });
        JS

        run_test(code, permissions = .NETWORK);

        expect_global("status", .NUMBER, 200.0);
        expect_global("ok", .BOOLEAN, true);
    });
}
