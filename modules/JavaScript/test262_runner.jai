main :: () {
    print("\n--- Pulsar Test262 Runner ---\n\n");

    assert_js, assert_success := read_entire_file("modules/JavaScript/test262/harness/assert.js", log_errors = false);
    defer free(assert_js);
    sta_js, sta_success       := read_entire_file("modules/JavaScript/test262/harness/sta.js", log_errors = false);
    defer free(sta_js);

    if !assert_success || !sta_success {
        print("Error: The test262 submodule is not checked out.\n");
        print("Please run 'git submodule update --init' in the root directory.\n");
        exit(1);
    }

    harness_code_global = tprint("%\n%\nvar $262 = { createRealm: function() { var r = new Realm(); return { global: r.import('globalThis') }; }, detachArrayBuffer: __detachArrayBuffer__ };\n", assert_js, sta_js);

    print("Starting test execution...\n");

    args := get_command_line_arguments();
    defer array_free(args);
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

    for file: test_files {
        run_test(file.full_name, file.short_name);
    }

    print("\n--- Test Summary ---\n");
    print("Passed:  %\n", total_passed);
    print("Failed:  %\n", total_failed);
    print("Skipped: %\n", total_skipped);
    total := total_passed + total_failed + total_skipped;
    print("Total:   %\n", total);

    if full_run && filter_global == "" {
        update_readme_coverage(total_passed, total_failed, total_skipped, total);
    }

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

Test_File :: struct { full_name: string; short_name: string; }
test_files: [..] Test_File;

SKIPPED_TESTS :: string.[
    "built-ins/AbstractModuleSource",

    // These tests rely on testIntl.js which defines a complex regex
    // containing backreferences (\1) and negative lookaheads (?!).
    // The 'Uniform' NFA-based regex engine does not support these
    // backtracking-dependent features, so the tests fail to compile the regex.
    "intl402/constructors-taint-Object-prototype-2",
    "intl402/constructors-taint-Object-prototype",
    "intl402/default-locale-is-canonicalized",
    "intl402/language-tags-canonicalized",
    "intl402/language-tags-invalid",

    // These tests expect full BCP-47 language tag validation and RangeError throwing,
    // which our basic Intl stubs currently do not implement.
    "intl402/language-tags-with-underscore",
];

visitor :: (info: *File_Visit_Info, user_data: *void) {
    state := get_temporary_storage_mark();
    defer set_temporary_storage_mark(state);

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

    test_file := Test_File.{ copy_string(info.full_name), copy_string(info.short_name) };
    array_add(*test_files, test_file);
}

run_test :: (full_name: string, short_name: string) {
    state := get_temporary_storage_mark();
    defer set_temporary_storage_mark(state);

    test_code, success := read_entire_file(full_name);
    defer free(test_code);
    if !success {
        print("Failed to read test: %\n", full_name);
        exit(1);
    }

    expected_to_fail := contains(test_code, "negative:");

    includes_code: String_Builder;
    init_string_builder(*includes_code);
    defer free_buffers(*includes_code);

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
                defer array_free(includes);
                for includes {
                    include_file := trim(it);
                    if include_file.count > 0 {
                        path := tprint("%/harness/%", "modules/JavaScript/test262", include_file);
                        include_content, success := read_entire_file(path);
                        if success {
                            defer free(include_content);
                            append(*includes_code, include_content);
                            append(*includes_code, "\n");
                        }
                    }
                }
            }
        }
    }

    includes_string := builder_to_string(*includes_code);
    defer free(includes_string);
    full_code := tprint("%\n%\n%\n", harness_code_global, includes_string, test_code);

    print("RUN: %\n", full_name);
    vm := run(full_code, permissions = 0, silence_console_output = true);
    defer {
        if vm.program deinit(vm.program);
        deinit(vm);
    }

    if expected_to_fail {
        if !vm.has_exception {
            print("FAIL: % (Expected an error but got none)\n", full_name);
            if !full_run write_entire_file("debug_test262.js", full_code);
            total_failed += 1;
            if !full_run exit(1);
            return;
        }
    } else {
        if vm.has_exception {
            print("FAIL: %\n", full_name);
            if !full_run write_entire_file("debug_test262.js", full_code);

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

    print("PASS: %\n", short_name);
    total_passed += 1;
}

update_readme_coverage :: (passed: int, failed: int, skipped: int, total: int) {
    readme, success := read_entire_file("README.md");
    if !success {
        print("Failed to read README.md to update coverage.\n");
        return;
    }

    start_index := find_index_from_left(readme, "## Test 262 Coverage");
    if start_index == -1 {
        print("Could not find '## Test 262 Coverage' in README.md\n");
        return;
    }

    end_index := find_index_from_left(readme, "## ", start_index + 1);
    if end_index == -1 {
        end_index = readme.count;
    }

    passed_pct  := ifx total > 0 then (passed * 100) / total else 0;
    failed_pct  := ifx total > 0 then (failed * 100) / total else 0;
    skipped_pct := ifx total > 0 then (skipped * 100) / total else 0;

    table := tprint("## Test 262 Coverage\n\n| Status | Count | Percentage |\n|---|---|---|\n| Passed | % | %% |\n| Failed | % | %% |\n| Skipped | % | %% |\n| **Total** | **%** | **100%** |\n\n",
        passed, passed_pct, "%",
        failed, failed_pct, "%",
        skipped, skipped_pct, "%",
        total, "%");

    part1 := readme;
    part1.count = start_index;

    part2 := readme;
    part2.data += end_index;
    part2.count -= end_index;

    builder: String_Builder;
    append(*builder, part1);
    append(*builder, table);
    append(*builder, part2);

    new_readme := builder_to_string(*builder);
    write_entire_file("README.md", new_readme);
}

#import "Basic" () (MEMORY_DEBUGGER = DEBUG_MEMORY, TEMP_ALLOCATOR_OVERWRITE_MEMORY = false);
#import "File";
#import "File_Utilities";
#import "String";
#import "Math";

#import,file "module.jai";
#import,dir "../Http_Server";

Uniform :: #import,dir "../Uniform";