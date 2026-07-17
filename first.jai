build :: () {
    set_build_options_dc(.{do_output=false});

    w := compiler_create_workspace("Pulsar");
    if !w {
        print("Workspace creation failed.\n");
        return;
    }

    options := get_build_options(w);
    args := options.compile_time_command_line;

    success, plugins_to_create, remaining_args := parse_plugin_arguments(args);
    if !success exit(1);

    is_test := array_find(remaining_args, "test");
    is_test262 := array_find(remaining_args, "test262");

    if is_test {
        options.output_executable_name = "pulsar_tests";
    } else if is_test262 {
        options.output_executable_name = "pulsar_test262";
    } else {
        options.output_executable_name = "pulsar";
    }

    plugins: [..] *Metaprogram_Plugin;
    intercept_flags: Intercept_Flags;


    is_release := array_find(remaining_args, "release");

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

    success = init_plugins(plugins_to_create, *plugins, w);
    if !success exit(1);

    for plugins if it.before_intercept it.before_intercept(it, *intercept_flags);

    compiler_begin_intercept(w, intercept_flags);

    for plugins if it.add_source it.add_source(it);
    
    if is_test {
        add_build_file("modules/JavaScript/tests/main.jai", w);
    } else if is_test262 {
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

        for plugins if it.message it.message(it, message);

        if !message break;
        if message.kind == .COMPLETE break;
    }

    compiler_end_intercept(w);

    for plugins if it.finish   it.finish  (it);
    for plugins if it.shutdown it.shutdown(it);

    if is_test || is_test262 {
        exe_path := tprint("%/%", options.output_path, options.output_executable_name);
        #if OS == .WINDOWS { exe_path = tprint("%.exe", exe_path); }

        args_to_pass: [..] string;
        array_add(*args_to_pass, exe_path);
        for remaining_args {
            if it == "test" || it == "test262" || it == "release" || it == "first.jai" || it == "-" continue;
            array_add(*args_to_pass, it);
        }

        print("\n=== Running Tests (%) ===\n", exe_path);
        result, output, error := run_command(..args_to_pass, capture_and_return_output = true);
        print("%", output);
        if error print("%", error);

        if result.exit_code != 0 {
            print("Tests failed with exit code %\n", result.exit_code);
            exit(1);
        }
    }
}

#run build();

#import "Basic";
#import "Compiler";
#import "String";
#import "File";
#import "Metaprogram_Plugins";
#import "Process";