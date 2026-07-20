main :: () {
    print("\n--- Pulsar Test262 Runner ---\n\n");

    assert_js, assert_success := read_entire_file("modules/JavaScript/test262/harness/assert.js", log_errors = false);
    sta_js, sta_success       := read_entire_file("modules/JavaScript/test262/harness/sta.js", log_errors = false);

    if !assert_success || !sta_success {
        print("Error: The test262 submodule is not checked out.\n");
        print("Please run 'git submodule update --init' in the root directory.\n");
        exit(1);
    }

    harness_code_global = tprint("%\n%\n", assert_js, sta_js);

    print("Starting test execution...\n");

    args := get_command_line_arguments();
    for i: 1..args.count-1 {
        if args[i] == "--full" {
            full_run = true;
        } else {
            filter_global = args[i];
            print("Using filter: %\n", filter_global);
        }
    }

    test_dir := "modules/JavaScript/test262/test";
    visit_files(test_dir, true, null, visitor, visit_files=true, visit_directories=true);

    print("\n--- Test Summary ---\n");
    print("Passed:  %\n", total_passed);
    print("Failed:  %\n", total_failed);
    print("Skipped: %\n", total_skipped);
    print("Total:   %\n", total_passed + total_failed + total_skipped);

    if total_failed > 0 {
        exit(1);
    } else {
        print("\nAll tests passed!\n");
    }
}

harness_code_global: string;
filter_global: string;
full_run: bool;
total_passed: int;
total_failed: int;
total_skipped: int;

SKIPPED_TESTS :: string.[
    "built-ins/AbstractModuleSource",
];

visitor :: (info: *File_Visit_Info, user_data: *void) {
    if info.is_directory return;
    if !ends_with(info.short_name, ".js") return;

    if contains(info.full_name, "harness") return;

    if filter_global.count > 0 && !contains(info.full_name, filter_global) return;

    for SKIPPED_TESTS {
        if contains(info.full_name, it) {
            print("SKIP: %\n", it);
            total_skipped += 1;
            return;
        }
    }

    test_code, success := read_entire_file(info.full_name);
    if !success {
        print("Failed to read test: %\n", info.full_name);
        exit(1);
    }

    expected_to_fail := contains(test_code, "negative:");

    includes_code: String_Builder;
    init_string_builder(*includes_code);

    header_start := find_index_from_left(test_code, "/*---");
    header_end   := find_index_from_left(test_code, "---*/");
    if header_start >= 0 && header_end > header_start {
        header := slice(test_code, header_start, header_end - header_start);
        includes_index := find_index_from_left(header, "includes: [");
        if includes_index >= 0 {
            start := includes_index + 11;
            end := find_index_from_left(header, "]", start);
            if end > start {
                includes_str := slice(header, start, end - start);
                includes := split(includes_str, ",");
                for includes {
                    include_file := trim(it);
                    if include_file.count > 0 {
                        path := tprint("%/harness/%", "modules/JavaScript/test262", include_file);
                        include_content, success := read_entire_file(path);
                        if success {
                            append(*includes_code, include_content);
                            append(*includes_code, "\n");
                        }
                    }
                }
            }
        }
    }

    full_code := tprint("%\n%\n%\n", harness_code_global, builder_to_string(*includes_code), test_code);

    print("RUN: %\n", info.short_name);
    write_entire_file("debug_test262.js", full_code);
    vm := run(full_code, permissions = 0, silence_console_output = true);
    defer {
        if vm.program deinit(vm.program);
        deinit(vm);
    }

    if expected_to_fail {
        if !vm.has_exception {
            print("FAIL: % (Expected an error but got none)\n", info.full_name);
            total_failed += 1;
            if !full_run exit(1);
            return;
        }
    } else {
        if vm.has_exception {
            print("FAIL: %\n", info.full_name);

            name := "Error";
            msg := "";
            if vm.exception.type == .OBJECT && vm.exception.object {
                found_name, name_val := lookup_property(vm, vm.exception.object, "name");
                found_msg, msg_val := lookup_property(vm, vm.exception.object, "message");
                if found_name && name_val.type == .STRING then name = name_val.s;
                if found_msg && msg_val.type == .STRING then msg = msg_val.s;
            } else if vm.exception.type == .STRING {
                msg = vm.exception.s;
            }
            print("Uncaught exception: %: %\n", name, msg);
            print("\n");

            if vm.has_stack_trace {
                print("%\n", vm.stack_trace);
            }
            total_failed += 1;
            if !full_run exit(1);
            return;
        }
    }

    print("PASS: %\n", info.short_name);
    total_passed += 1;
}

#import "Basic" () (MEMORY_DEBUGGER = DEBUG_MEMORY, TEMP_ALLOCATOR_OVERWRITE_MEMORY = false);
#import "File";
#import "File_Utilities";
#import "String";
#import "Math";

#import,file "module.jai";
#import,dir "../Http_Server";

Uniform :: #import,dir "../Uniform";