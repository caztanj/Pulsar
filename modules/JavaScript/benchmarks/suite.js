function measure(name, func) {
    let start = Date.now();
    func();
    let end = Date.now();
    let time = end - start;
    print(name + " completed in " + time + " ms");
    return time;
}

print("=== JavaScript Engine Benchmark Suite ===");
let totalTime = 0;

// 1. Fibonacci (Recursion, Call Stack, Math)
totalTime = totalTime + measure("Fibonacci (Recursion)", function() {
    function fib(n) {
        if (n <= 1) return n;
        return fib(n - 1) + fib(n - 2);
    }
    // calculate fib(28)
    let result = fib(28);
    if (result !== 317811) {
        print("ERROR: Fibonacci returned wrong result!");
    }
});

// 2. Arrays (Allocation, Push, Indexing)
totalTime = totalTime + measure("Arrays (Push & Iterate)", function() {
    let arr = [];
    for (let i = 0; i < 1000000; i++) {
        arr.push(i);
    }

    let sum = 0;
    for (let i = 0; i < 1000000; i++) {
        sum = sum + arr[i];
    }
});

// 3. Objects (Property read/write, Monomorphic Inline Caches)
totalTime = totalTime + measure("Objects (Monomorphic IC)", function() {
    let obj = { x: 0, y: 1, z: 2 };
    let sum = 0;
    for (let i = 0; i < 5000000; i++) {
        sum = sum + obj.x + obj.y + obj.z;
        obj.x = obj.x + 1;
        obj.y = obj.y + 1;
        obj.z = obj.z + 1;
    }
});

// 4. Polymorphic Inline Caching (Cache thrashing)
totalTime = totalTime + measure("Objects (Polymorphic IC)", function() {
    function getX(obj) {
        return obj.x;
    }

    let obj1 = { x: 1 };
    let obj2 = { a: 1, x: 2 };
    let obj3 = { b: 1, c: 2, x: 3 };
    let obj4 = { d: 1, x: 4 };

    let sum = 0;
    // We iterate 5 million times doing property access on 4 different shapes.
    // Without PIC, this will miss the cache 20 million times and be extremely slow!
    for (let i = 0; i < 5000000; i++) {
        sum = sum + getX(obj1) + getX(obj2) + getX(obj3) + getX(obj4);
    }
});

// 5. Classes (Instantiation, Methods, GC Stress)
totalTime = totalTime + measure("Classes & GC Stress", function() {
    class Point {
        constructor(x, y) {
            this.x = x;
            this.y = y;
        }

        magnitude() {
            return this.x * this.x + this.y * this.y;
        }
    }

    let sum = 0;
    // Create 1 million objects (stresses GC)
    for (let i = 0; i < 1000000; i++) {
        let p = new Point(i, i);
        sum = sum + p.magnitude();
    }
});

// Generational GC Stress (Long-lived objects pointing to short-lived)
totalTime = totalTime + measure("Generational GC Stress", function() {
    let oldGeneration = [];
    for (let i = 0; i < 1000; i++) {
        oldGeneration.push({ id: i, data: null });
    }

    // Create 1 million short-lived objects, but occasionally link them to the old generation
    let sum = 0;
    for (let i = 0; i < 1000000; i++) {
        let tempObj = { value: i };
        sum = sum + tempObj.value;

        // Every 10,000th iteration, mutate an old object to point to the new object (triggers Write Barrier)
        if (i % 10000 == 0) {
            oldGeneration[i / 10000].data = tempObj;
        }
    }
});

// 6. Closures (Lexical Environment, variable capture)
totalTime = totalTime + measure("Closures", function() {
    function createAdder(x) {
        return function(y) {
            return x + y;
        };
    }

    let adders = [];
    for (let i = 0; i < 1000; i++) {
        adders.push(createAdder(i));
    }

    let sum = 0;
    for (let i = 0; i < 10000; i++) {
        for (let j = 0; j < 1000; j++) {
            sum = sum + adders[j](i);
        }
    }
});

// 6. Strings (Concatenation)
totalTime = totalTime + measure("Strings (Concatenation)", function() {
    let str = "";
    for (let i = 0; i < 50000; i++) {
        str = str + "a";
    }
    if (str.length !== 50000) {
        print("ERROR: String concat failed!");
    }
});

print("---------------------------------------");
print("Total Execution Time: " + totalTime + " ms");
print("=======================================");
