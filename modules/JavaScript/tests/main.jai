main :: () {
    #if DEBUG_MEMORY defer report_memory_leaks();

    test_procs := Test_Proc.[
        test_array,
        test_arrow_functions,
        test_async_await,
        test_automatic_semicolon_insertion,
        test_boolean,
        test_classes,
        test_closures,
        test_console,
        test_date,
        test_destructuring,
        test_error,
        test_exceptions,
        test_fetch,
        test_file,
        test_gc,
        test_generators,
        test_global_this,
        test_http,
        test_json,
        test_loops,
        test_map,
        test_math,
        test_modules,
        test_number,
        test_object,
        test_object_extra,
        test_operators,
        test_parser,
        test_print,
        test_promise,
        test_realms,
        test_recursion,
        test_router,
        test_set,
        test_spread,
        test_string,
        test_switch,
        test_regexp,
        test_symbol,
        test_template_literals,
        test_timer,
        test_typed_array,
        test_vm_basic,
    ];

    for test_procs {
        it();
        reset_temporary_storage();
    }

    if !has_error print("All tests passed!\n");
}

test :: (name: string, proc: Test_Proc) {
    context.test_name = name;
    proc();
}

test :: (proc: Test_Proc) {
    context.test_name = "unnamed";
    proc();
}

expect_global :: (name: string, $type: Value_Type, to_be: $T, loc := #caller_location) {
    global := get_global(context.vm, name);
    value  := to_value(type, to_be);

    #if T == *void {
        if global.type != value.type {
            has_error = true;
            log_error("[%]: expect_global(%, .%, %) %", context.test_name, name, type, to_be, loc);
        }

        return;
    }

    if !values_strict_equal(global, value) {
        has_error = true;
        log_error("[%]: expect_global(%, .%, %) %", context.test_name, name, type, to_be, loc);
    }
}

expect_property_exists :: (object: *Gc_Object, property_name: string, loc := #caller_location) {
    found, _ := lookup_property(context.vm, object, property_name);
    if !found {
        has_error = true;
        log_error("[%]: expect_property_exists() - property '%' not found %", context.test_name, property_name, loc);
    }
}

expect_object_property :: (vm: *Vm, value: Value, property_name: string, $type: Value_Type, to_be: $T, loc := #caller_location) {
    if value.type != .OBJECT {
        has_error = true;
        log_error("[%]: expect_object_property() - not an object %", context.test_name, loc);
        return;
    }

    found, property_value := lookup_property(vm, value.object, property_name);
    if !found {
        has_error = true;
        log_error("[%]: expect_object_property() - property '%' not found %", context.test_name, property_name, loc);
        return;
    }

    expected := to_value(type, to_be);

    #if T == *void {
        if property_value.type != expected.type {
            has_error = true;
            log_error("[%]: expect_object_property(%, .%, %) - expected .%, got .% %", context.test_name, property_name, type, to_be, expected.type, property_value.type, loc);
        }
        return;
    }

    if !values_strict_equal(property_value, expected) {
        has_error = true;
        log_error("[%]: expect_object_property(%, .%, %) - got incorrect value %", context.test_name, property_name, type, to_be, loc);
    }
}

expect_not_null :: (ptr: *$T, loc := #caller_location) {
    if ptr == null {
        has_error = true;
        log_error("[%]: expect_not_null() - pointer is null %", context.test_name, loc);
    }
}

expect_equals :: (actual: $T, expected: T, loc := #caller_location) {
    if actual != expected {
        has_error = true;
        log_error("[%]: expect_equals() - expected %, got % %", context.test_name, expected, actual, loc);
    }
}

expect_true :: (actual: bool, loc := #caller_location) {
    if !actual {
        has_error = true;
        log_error("[%]: expect_true() - expected true, got false %", context.test_name, loc);
    }
}

expect_false :: (actual: bool, loc := #caller_location) {
    if actual {
        has_error = true;
        log_error("[%]: expect_false() - expected false, got true %", context.test_name, loc);
    }
}

expect_type :: (value: Value, expected: Value_Type, loc := #caller_location) {
    if value.type != expected {
        has_error = true;
        log_error("[%]: expect_type() - expected .%, got .% %", context.test_name, expected, value.type, loc);
    }
}

expect_value :: (val: Value, $type: Value_Type, to_be: $T, loc := #caller_location) {
    expected := to_value(type, to_be);

    #if T == *void {
        if val.type != expected.type {
            has_error = true;
            log_error("[%]: expect_value(.%, %) - expected .%, got .% %", context.test_name, type, to_be, expected.type, val.type, loc);
        }
        return;
    }

    if !values_strict_equal(val, expected) {
        has_error = true;
        log_error("[%]: expect_value(.%, %) - got incorrect value %", context.test_name, type, to_be, loc);
    }
}

expect_global_property :: (name: string, $type: Value_Type, property_name: string, $property_type: Value_Type, to_be: $T, loc := #caller_location) {
    global          := get_global(context.vm, name);
    found, property := lookup_property(context.vm, global.object, property_name);
    if !found {
        property = .{ type = .UNDEFINED };
    }

    if global.type != type {
        has_error = true;
        log_error("[%]: expect_global_property(%, .%, %, .%, %) %", context.test_name, name, type, property_name, property_type, to_be, loc);
        return;
    }

    value := to_value(property_type, to_be);

    if !values_strict_equal(property, value) {
        has_error = true;
        log_error("[%]: expect_global_property(%, .%, %, .%, %) %", context.test_name, name, type, property_name, property_type, to_be, loc);
    }
}

expect_global_approx :: (name: string, to_be: float64, epsilon: float64 = 0.00001, loc := #caller_location) {
    global := get_global(context.vm, name);
    if global.type != .NUMBER {
        has_error = true;
        log_error("[%]: expect_global_approx(%, %) - expected number, got .% %", context.test_name, name, to_be, global.type, loc);
        return;
    }

    if abs(global.number - to_be) >= epsilon {
        has_error = true;
        log_error("[%]: expect_global_approx(%, %) - got % %", context.test_name, name, to_be, global.number, loc);
    }
}

expect_total_objects :: (expected: int, loc := #caller_location) {
    actual := context.vm.gc.young_object_count + context.vm.gc.old_object_count;
    if actual != expected {
        has_error = true;
        log_error("[%]: expect_total_objects() - expected %, got % %", context.test_name, expected, actual, loc);
    }
}

expect_array_count :: (name: string, expected_count: int, loc := #caller_location) {
    val := get_global(context.vm, name);
    expect_array_count(val, expected_count, loc = loc);
}

expect_object_fields_count :: (name: string, expected_count: int, loc := #caller_location) {
    val := get_global(context.vm, name);
    expect_object_fields_count(val, expected_count, loc = loc);
}

expect_array_element :: (name: string, index: int, $type: Value_Type, to_be: $T, loc := #caller_location) -> Value {
    val := get_global(context.vm, name);
    return expect_array_element(val, index, type, to_be, loc = loc);
}

expect_array_count :: (val: Value, expected_count: int, loc := #caller_location) {
    if val.type != .ARRAY {
        has_error = true;
        log_error("[%]: expect_array_count(%) - not an array %", context.test_name, expected_count, loc);
        return;
    }
    if val.object.elements.count != expected_count {
        has_error = true;
        log_error("[%]: expect_array_count(%) - expected %, got % %", context.test_name, expected_count, expected_count, val.object.elements.count, loc);
    }
}

expect_object_fields_count :: (val: Value, expected_count: int, loc := #caller_location) {
    if val.type != .OBJECT {
        has_error = true;
        log_error("[%]: expect_object_fields_count(%) - not an object %", context.test_name, expected_count, loc);
        return;
    }
    if val.object.fields.count != expected_count {
        has_error = true;
        log_error("[%]: expect_object_fields_count(%) - expected %, got % %", context.test_name, expected_count, expected_count, val.object.fields.count, loc);
    }
}

expect_array_element :: (val: Value, index: int, $type: Value_Type, to_be: $T, loc := #caller_location) -> Value {
    if val.type != .ARRAY {
        has_error = true;
        log_error("[%]: expect_array_element(%, .%, %) - not an array %", context.test_name, index, type, to_be, loc);
        return .{};
    }
    if index < 0 || index >= val.object.elements.count {
        has_error = true;
        log_error("[%]: expect_array_element(%, .%, %) - out of bounds (count: %) %", context.test_name, index, type, to_be, val.object.elements.count, loc);
        return .{};
    }

    element := val.object.elements[index];
    value   := to_value(type, to_be);

    #if T == *void {
        if element.type != value.type {
            has_error = true;
            log_error("[%]: expect_array_element(%, .%, %) %", context.test_name, index, type, to_be, loc);
        }
        return element;
    }

    if !values_strict_equal(element, value) {
        has_error = true;
        log_error("[%]: expect_array_element(%, .%, %) %", context.test_name, index, type, to_be, loc);
    }

    return element;
}

to_value :: ($type: Value_Type, value: $T) -> Value
#modify {
    if T == {
        case bool;    return type == .BOOLEAN;
        case int;     return type == .NUMBER;
        case float32; return type == .NUMBER;
        case float64; return type == .NUMBER;
        case string;  return type == .STRING;
        case *Gc_Object; return type == .OBJECT || type == .ARRAY || type == .FUNCTION || type == .GENERATOR;
        case *void;   return true;
    }

    return false;
} {
    js_value := Value.{ type = type };

    #if T == {
        case bool;    js_value.boolean = xx value;
        case int;     js_value.number  = xx value;
        case float32; js_value.number  = xx value;
        case float64; js_value.number  = xx value;
        case string;  js_value.s       = value;
        case *Gc_Object; js_value.object = value;
    }

    return js_value;
};

run_test :: (code: string, permissions: Permission = 0) #expand {
    vm_to_free := run(code, permissions = permissions);
    vm_to_free.silence_console_output = true;
    context.vm = vm_to_free;

    `defer {
        deinit(vm_to_free.program);
        deinit(vm_to_free);
    }
}

Test_Proc :: #type () -> ();

has_error := false;

#add_context test_name: string;
#add_context vm: *Vm;

#load "arrow_functions.jai";
#load "async_await.jai";
#load "automatic_semicolon_insertion.jai";
#load "classes.jai";
#load "closures.jai";
#load "destructuring.jai";
#load "exceptions.jai";
#load "gc.jai";
#load "generators.jai";
#load "loops.jai";
#load "modules.jai";
#load "object_extra.jai";
#load "operators.jai";
#load "parser.jai";
#load "realms.jai";
#load "recursion.jai";
#load "router.jai";
#load "spread.jai";
#load "switch.jai";
#load "template_literals.jai";
#load "vm_basic.jai";

#load "extensions/array.jai";
#load "extensions/boolean.jai";
#load "extensions/date.jai";
#load "extensions/error.jai";
#load "extensions/fetch.jai";
#load "extensions/file.jai";
#load "extensions/global_this.jai";
#load "extensions/http.jai";
#load "extensions/json.jai";
#load "extensions/map.jai";
#load "extensions/math.jai";
#load "extensions/number.jai";
#load "extensions/object.jai";
#load "extensions/print.jai";
#load "extensions/promise.jai";
#load "extensions/set.jai";
#load "extensions/string.jai";
#load "extensions/typed_array.jai";
#load "extensions/symbol.jai";
#load "extensions/console.jai";
#load "extensions/timer.jai";
#load "extensions/regexp.jai";

#import "Basic" () (MEMORY_DEBUGGER = DEBUG_MEMORY, TEMP_ALLOCATOR_OVERWRITE_MEMORY = false);
#import "File";
#import "Math";
#import "String";

#import,file "../module.jai";
#import,dir "../../Http_Server";

Uniform :: #import,dir "../../Uniform";