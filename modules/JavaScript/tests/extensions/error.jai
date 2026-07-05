test_error :: () {
    test("Error Constructor", () => {
        code := #string JS
            let e = new Error("Something went wrong");
            let t = new TypeError("Bad type");
            let r = new ReferenceError();
        JS

        run_test(code);

        expect_object_property(context.vm, get_global(context.vm, "e"), "name", .STRING, "Error");
        expect_object_property(context.vm, get_global(context.vm, "e"), "message", .STRING, "Something went wrong");
        
        expect_object_property(context.vm, get_global(context.vm, "t"), "name", .STRING, "TypeError");
        expect_object_property(context.vm, get_global(context.vm, "t"), "message", .STRING, "Bad type");
        
        expect_object_property(context.vm, get_global(context.vm, "r"), "name", .STRING, "ReferenceError");
        expect_object_property(context.vm, get_global(context.vm, "r"), "message", .STRING, "");
    });

    test("Error.prototype.toString", () => {
        code := #string JS
            let e = new Error("Hello");
            let string_value = e.toString();
        JS

        run_test(code);

        expect_value(get_global(context.vm, "string_value"), .STRING, "Error: Hello");
    });
    
    test("Error.prototype.stack", () => {
        code := #string JS
            let stack_string = "";
            function a() { b(); }
            function b() { c(); }
            function c() {
                let e = new TypeError("Deep");
                stack_string = e.stack;
            }
            a();
        JS

        run_test(code);

        stack_trace := get_global(context.vm, "stack_string");
        expect_type(stack_trace, .STRING);
        
        stack_string := stack_trace.s;
        
        contains_a := contains(stack_string, "a");
        contains_b := contains(stack_string, "b");
        contains_c := contains(stack_string, "c");
        
        expect_true(contains_a);
        expect_true(contains_b);
        expect_true(contains_c);
        
    });
}
