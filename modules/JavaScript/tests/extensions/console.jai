test_console :: () {
    test(() => {
        code := #string JS
            let hasLog = typeof console.log === "function";
            let hasError = typeof console.error === "function";
            let hasWarn = typeof console.warn === "function";
            let hasInfo = typeof console.info === "function";
            let hasDebug = typeof console.debug === "function";
            let hasTime = typeof console.time === "function";
            let hasTimeEnd = typeof console.timeEnd === "function";
            let hasAssert = typeof console.assert === "function";
            let hasClear = typeof console.clear === "function";

            // We just call them to ensure no crashes
            console.log("test console.log", 123, {a: 1});
            console.warn("test console.warn", [1, 2, 3]);
            console.error("test console.error", null, undefined);
            console.info("test console.info");
            console.debug("test console.debug");
            
            console.time("testTimer");
            console.timeEnd("testTimer");

            console.assert(true, "this should not print");
            console.assert(false, "this should print assertion failed");

            // clear might clear the screen, so maybe skip or just call it
            // console.clear(); 
        JS

        run_test(code);
        expect_global("hasLog", .BOOLEAN, true);
        expect_global("hasError", .BOOLEAN, true);
        expect_global("hasWarn", .BOOLEAN, true);
        expect_global("hasInfo", .BOOLEAN, true);
        expect_global("hasDebug", .BOOLEAN, true);
        expect_global("hasTime", .BOOLEAN, true);
        expect_global("hasTimeEnd", .BOOLEAN, true);
        expect_global("hasAssert", .BOOLEAN, true);
        expect_global("hasClear", .BOOLEAN, true);
    });
}
