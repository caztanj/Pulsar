test_uint8_array :: () {
    test(() => {
        code := #string JS
            let arr = new Uint8Array(5);
            let len = arr.length;

            arr[0] = 10;
            arr[4] = 20;

            let first = arr[0];
            let last = arr[4];
            let middle = arr[2];

            let isInstance = arr instanceof Uint8Array;

            let arr2 = new Uint8Array([1, 2, 3, 4, 5]);
            let arr3 = new Uint8Array(arr2);
            let arr3_1 = arr3[1];

            arr3.set([10, 20], 1);
            let arr3_str = arr3.join("-");

            let sliced = arr3.slice(1, 3);
            let sliced_str = sliced.join(",");

            arr3.fill(99, 1, 3);
            let fill_str = arr3.join("-");

            let index = arr3.indexOf(99);
            let has99 = arr3.includes(99);

            arr3.reverse();
            let rev_str = arr3.join("-");

            let mapped = arr3.map(x => x * 2);
            let map_str = mapped.join("-");

            let filtered = mapped.filter(x => x > 100);
            let filt_str = filtered.join("-");

            let sum = filtered.reduce((acc, curr) => acc + curr, 0);

            let forEachSum = 0;
            filtered.forEach(x => forEachSum += x);
        JS

        run_test(code);
        expect_global("len", .NUMBER, 5.0);
        expect_global("first", .NUMBER, 10.0);
        expect_global("last", .NUMBER, 20.0);
        expect_global("middle", .NUMBER, 0.0);
        expect_global("isInstance", .BOOLEAN, true);

        expect_global("arr3_1", .NUMBER, 2.0);
        expect_global("arr3_str", .STRING, "1-10-20-4-5");
        expect_global("sliced_str", .STRING, "10,20");
        expect_global("fill_str", .STRING, "1-99-99-4-5");
        expect_global("index", .NUMBER, 1.0);
        expect_global("has99", .BOOLEAN, true);
        expect_global("rev_str", .STRING, "5-4-99-99-1");
        expect_global("map_str", .STRING, "10-8-198-198-2");
        expect_global("filt_str", .STRING, "198-198");
        expect_global("sum", .NUMBER, 396.0);
        expect_global("forEachSum", .NUMBER, 396.0);
    });
}
