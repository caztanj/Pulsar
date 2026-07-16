build :: () {
    set_build_options_dc(.{do_output=false});

    w := compiler_create_workspace("Pulsar");
    if !w {
        print("Workspace creation failed.\n");
        return;
    }

    options := get_build_options(w);
    options.output_executable_name = "pulsar";

    args := options.compile_time_command_line;

    plugins: [..] *Metaprogram_Plugin;
    intercept_flags: Intercept_Flags;

    success, plugins_to_create, remaining_args := parse_plugin_arguments(args);
    if !success exit(1);

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
    add_build_file("main.jai", w);

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
}

#run build();

#import "Basic";
#import "Compiler";
#import "String";
#import "File";
#import "Metaprogram_Plugins";