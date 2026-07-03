test_object :: () {
    test(() => {
        code := #string JS
            let proto = { x: 10, y: 20 };
            let obj = { y: 30 };
            Object.setPrototypeOf(obj, proto);
            let a = obj.x;
            let b = obj.y;
            let c = obj.z;
        JS

        run_test(code);
        expect_global("a", .NUMBER, 10.0);
        expect_global("b", .NUMBER, 30.0);
        expect_global("c", .UNDEFINED, null);
    });

    test(() => {
        code := #string JS
            let proto = { a: 1 };
            let obj = Object.create(proto);
            let p = Object.getPrototypeOf(obj);
            let valB = 0;
            Object.defineProperty(obj, 'b', { value: 2 });
            valB = obj.b;
            let desc = Object.getOwnPropertyDescriptor(obj, 'b');
        JS

        run_test(code);
        expect_global("valB", .NUMBER, 2.0);
        
        obj := get_global(context.vm, "obj");
        p := get_global(context.vm, "p");
        proto := get_global(context.vm, "proto");
        desc := get_global(context.vm, "desc");

        expect_type(obj, .OBJECT);
        expect_equals(obj.object.prototype, proto.object);
        expect_equals(p.object, proto.object);
        expect_type(desc, .OBJECT);

        expect_global_property("desc", .OBJECT, "value", .NUMBER, 2.0);
    });
}
