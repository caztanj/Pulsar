build :: () {
    set_build_options_dc(.{ do_output = false });

    args := get_build_options().compile_time_command_line;

    w := compiler_create_workspace("Pulsar");
    options := get_build_options(w);
    copy_commonly_propagated_fields(get_build_options(), *options);

    success:, plugins_to_create:, args = parse_plugin_arguments(args);
    if !success exit(1);

    is_test := array_find(args, "test");
    is_test262 := array_find(args, "test262");
    is_test262_full := array_find(args, "test262-full");
    is_release := array_find(args, "release");

    if is_test {
        options.output_executable_name = "pulsar_tests";
    } else if is_test262 || is_test262_full {
        options.output_executable_name = "pulsar_test262";
    } else {
        options.output_executable_name = "pulsar";
    }

    options.entry_point_name = "main";

    if is_release {
        options.output_path = "build_release";
        options.intermediate_path = "build_release";
        set_optimization(*options, .OPTIMIZED);
    } else {
        options.output_path = "build_debug";
        options.intermediate_path = "build_debug";
        set_optimization(*options, .DEBUG);
    }

    set_build_options(options, w);

    plugins: [..] *Metaprogram_Plugin;
    success = init_plugins(plugins_to_create, *plugins, w);
    if !success exit(1);

    intercept_flags: Intercept_Flags;
    for plugins if it.before_intercept it.before_intercept(it, *intercept_flags);

    compiler_begin_intercept(w, intercept_flags);

    for plugins if it.add_source it.add_source(it);

    if is_test {
        add_build_file("modules/JavaScript/tests/main.jai", w);
    } else if is_test262 || is_test262_full {
        add_build_file("modules/JavaScript/test262_runner.jai", w);
    } else {
        add_build_file("main.jai", w);
    }

    if is_release {
        add_build_string("DEBUG_MEMORY :: false;", w);
    } else {
        add_build_string("DEBUG_MEMORY :: true;", w);
    }

    while true {
        message := compiler_wait_for_message();
        if message.workspace != w continue;

        for plugins if it.message it.message(it, message);

        if !message break;

        if message.kind == .ERROR exit(1);
        if message.kind == .COMPLETE break;
    }

    compiler_end_intercept(w);

    for plugins if it.finish   it.finish  (it);
    for plugins if it.shutdown it.shutdown(it);

    if is_test || is_test262 || is_test262_full {
        exe_path := tprint("%/%", options.output_path, options.output_executable_name);
        #if OS == .WINDOWS { exe_path = tprint("%.exe", exe_path); }

        args_to_pass: [..] string;
        array_add(*args_to_pass, exe_path);
        if is_test262_full array_add(*args_to_pass, "--full");
        for args {
            if it == "test" || it == "test262" || it == "test262-full" || it == "release" continue;
            array_add(*args_to_pass, it);
        }

        print("\n=== Running Tests (%) ===\n", exe_path);
        result := run_command(..args_to_pass, capture_and_return_output = false);

        if result.exit_code != 0 {
            print("Tests failed with exit code %\n", result.exit_code);
        }
    }
}

#run,stallable build();

#import "Basic";
#import "Compiler";
#import "String";
#import "File";
#import "Metaprogram_Plugins";
#import "Process";