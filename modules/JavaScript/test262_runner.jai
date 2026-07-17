main :: () {
    print("\n--- Pulsar Test262 Runner ---\n\n");

    is_dir := is_directory("modules/JavaScript/test262");
    if !is_dir {
        print("Error: The test262 submodule is not checked out.\n");
        print("Please run 'git submodule update --init' in the root directory.\n");
        exit(1);
    }

    print("Test262 repository found.\n");
    print("Loading test262 harness files...\n");

    assert_js, assert_success := read_entire_file("modules/JavaScript/test262/harness/assert.js");
    sta_js, sta_success       := read_entire_file("modules/JavaScript/test262/harness/sta.js");

    if !assert_success || !sta_success {
        print("Error: Could not read harness files.\n");
        exit(1);
    }

    harness_code_global = tprint("%\n%\n", assert_js, sta_js);

    print("Starting test execution (failing fast on first error)...\n");

    test_dir := "modules/JavaScript/test262/test";
    visit_files(test_dir, true, null, visitor, visit_files=true, visit_directories=true);

    print("\nAll tests passed!\n");
}

harness_code_global: string;

visitor :: (info: *File_Visit_Info, user_data: *void) {
    if info.is_directory return;
    if !ends_with(info.short_name, ".js") return;
    
    if contains(info.full_name, "harness") return;

    test_code, success := read_entire_file(info.full_name);
    if !success {
        print("Failed to read test: %\n", info.full_name);
        exit(1);
    }

    expected_to_fail := contains(test_code, "negative:");

    full_code := tprint("%\n%\n", harness_code_global, test_code);

    print("RUN: %\n", info.short_name);
    vm := run(full_code, permissions = 0, silence_console_output = true);
    defer {
        if vm.program deinit(vm.program);
        deinit(vm);
    }

    if expected_to_fail {
        if !vm.has_exception {
            print("FAIL: % (Expected an error but got none)\n", info.full_name);
            exit(1);
        }
    } else {
        if vm.has_exception {
            print("FAIL: %\n", info.full_name);
            print("Uncaught exception: ");
            print(vm, .{}, .[vm.exception]);
            print("\n");
            if vm.has_stack_trace {
                print("%\n", vm.stack_trace);
            }
            exit(1);
        }
    }

    print("PASS: %\n", info.short_name);
}

#import "Basic" () (MEMORY_DEBUGGER = DEBUG_MEMORY, TEMP_ALLOCATOR_OVERWRITE_MEMORY = false);
#import "File";
#import "File_Utilities";
#import "String";
#import "Math";

#import,file "module.jai";
#import,dir "../Http_Server";

Uniform :: #import,dir "../Uniform";