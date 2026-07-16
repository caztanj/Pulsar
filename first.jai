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
    is_release := false;

    for args {
        if it == "release" {
            is_release = true;
        }
    }

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

    compiler_begin_intercept(w);
    add_build_file("main.jai", w);

    if is_release {
        add_build_string("DEBUG_MEMORY :: false;", w);
    } else {
        add_build_string("DEBUG_MEMORY :: true;", w);
    }

    while true {
        message := compiler_wait_for_message();
        if !message break;
        if message.kind == .COMPLETE break;
    }

    compiler_end_intercept(w);
}

#run build();

#import "Basic";
#import "Compiler";
#import "String";
#import "File";