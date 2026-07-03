test_router :: () {
    test(() => {
        code := #string JS
            const router = new HttpRouter();

            router.get("/", (req) => {
                return { status: 200, body: "Home" };
            });

            router.get("/hello/*", (req) => {
                return { status: 200, body: "Hello " + req.uri.slice(7) };
            });

            router.post("/submit", (req) => {
                return { status: 201, body: "Submitted: " + req.body };
            });

            const results = [];

            const res1 = router.handle({ method: "GET", uri: "/" });
            results.push(res1.status === 200 && res1.body === "Home");

            const res2 = router.handle({ method: "GET", uri: "/hello/world" });
            results.push(res2.status === 200 && res2.body === "Hello world");

            const res3 = router.handle({ method: "POST", uri: "/submit", body: "data" });
            results.push(res3.status === 201 && res3.body === "Submitted: data");

            const res4 = router.handle({ method: "GET", uri: "/notfound" });
            results.push(res4 === null);

            var success = results.every(x => x === true);
        JS

        run_test(code);
        expect_global("success", .BOOLEAN, true);
    });
}
