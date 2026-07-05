test_http :: () {
    test(() => {
        code := #string JS
            let error = '';
            try { new HttpServer(3000); } catch (e) { error = e; }
        JS

        run_test(code);
        expect_object_property(context.vm, get_global(context.vm, "error"), "message", .STRING, "Permission denied: network");
    });

    test(() => {
        code := #string JS
            let server = new HttpServer(3000);
            server.shutdown();
        JS

        run_test(code, permissions = .NETWORK);

        if context.vm.has_exception {
            print("Test Exception: %\n", context.vm.exception);
        }
        expect_equals(context.vm.has_exception, false);
    });
}
