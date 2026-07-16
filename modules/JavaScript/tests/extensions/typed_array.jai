test_typed_array :: () {
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

            // Test clamping in Uint8ClampedArray
            let clamped = new Uint8ClampedArray(3);
            clamped[0] = -50;
            clamped[1] = 150;
            clamped[2] = 500;
            let clamped_str = clamped.join(",");

            // Test precision in Float64Array
            let floatArr = new Float64Array(2);
            floatArr[0] = 3.14159;
            floatArr[1] = -2.718;
            let float_str = floatArr.join(",");

            // Test precision in Int32Array
            let int32Arr = new Int32Array(2);
            int32Arr[0] = -123456789;
            int32Arr[1] = 987654321;
            let int32_str = int32Arr.join(",");

            // Test wrapping / overflow in Int8Array
            let int8Arr = new Int8Array(1);
            int8Arr[0] = 128; // overflows to -128 in C/C++ but let's see. Wait, in our implementation we just cast(s8) val. 128 as s8 is -128.
            let int8_val = int8Arr[0];
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

        expect_global("clamped_str", .STRING, "0,150,255");
        expect_global("float_str", .STRING, "3.14159,-2.718");
        expect_global("int32_str", .STRING, "-123456789,987654321");
        expect_global("int8_val", .NUMBER, -128.0);
    });
}
