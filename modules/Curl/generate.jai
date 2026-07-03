AT_COMPILE_TIME :: true;

// Note for Linux: I couldn’t get libcurl to statically link against libssl et al, so they are now runtime dependencies.
// The old versions we shipped with the compiler did not have this problem, but I don’t know how they were built or obtained.
// Wish I knew how replicate that…
//  -rluba, 2024-01-04

// We don’t ship the source with the compiler. Download a release and update this path if you want to re-compile the library.
SOURCE_PATH :: "src/curl-8.5.0";

DECLARATIONS_TO_OMIT :: string.[
    // These are only available in newer versions of libcurl and
    // we want Linux users to be able to use LINUX_USE_SYSTEM_LIBRARY to fall back to their system library,
    // even if it’s a bit older, to avoid annoying runtime dependency issues,
    // eg. because their system has a different version of libssl than we used to compiler the binaries we include.
    // Feel free to remove these and re-generate the bindings if you need these functions.
    // :LibcurlDependencies
    // -rluba, 2024-01-11
    "curl_global_trace",
    "curl_multi_get_handles",
];

#if AT_COMPILE_TIME {
    #run,stallable {
        set_build_options_dc(.{do_output=false});
        root_options := get_build_options();
        args := root_options.compile_time_command_line;
        if !generate_bindings(args) {
            compiler_set_workspace_status(.FAILED);
        }
    }
} else {
    #import "System";

    main :: () {
        set_working_directory(path_strip_filename(get_path_of_running_executable()));
        args := get_command_line_arguments();
        if !generate_bindings(args) {
            exit(1);
        }
    }
}

#if OS == .WINDOWS {
    PLATFORM_NAME :: "windows";
} else #if OS == .LINUX {
    PLATFORM_NAME :: "linux";
} else #if OS == .MACOS {
    PLATFORM_NAME :: "macos";
} else {
    compiler_report(tprint("Unsupported platform: %", OS));
}

generate_bindings :: (args: [] string) -> bool {
    compile        := array_find(args, "-compile");
    compile_debug  := array_find(args, "-debug");

    if compile {
        if !is_directory(SOURCE_PATH) {
            log_error("Source directory \"%\" does not exist. Did you download and extract a curl release?", SOURCE_PATH);
            return false;
        }
        #if OS == .MACOS {
            UNIVERSAL_DIR :: "macos/lib";
            options := get_build_options();
            success := make_directory_if_it_does_not_exist(UNIVERSAL_DIR, recursive = true);
            success &&= build_libcurl_variant(debug = compile_debug, suffix = "_x64",   extra_config_args = .["-DCMAKE_OSX_ARCHITECTURES=x86_64", "-DCMAKE_OSX_DEPLOYMENT_TARGET=10.13"]);
            success &&= build_libcurl_variant(debug = compile_debug, suffix = "_arm64", extra_config_args = .["-DCMAKE_OSX_ARCHITECTURES=arm64",  "-DCMAKE_OSX_DEPLOYMENT_TARGET=11.0"]);
            if success {
                // Create a universal binary out of the two arch builds:
                universal_lib_path := tprint("%/libcurl.dylib", UNIVERSAL_DIR);
                run_or_exit("lipo", "-create", "macos_x64/lib/libcurl.dylib", "macos_arm64/lib/libcurl.dylib", "-output", universal_lib_path);
                // Fix the dynamic library’s ID since we copied the symlinked short name variant. Otherwise the library still thinks it’s called "libcurl.4.8.0.dylib" and anything you link against it will look for the versioned library name.
                run_or_exit("install_name_tool", "-id", "@rpath/libcurl.dylib", universal_lib_path);
            }
            // @Incomplete: Automatically copy "include" directory from one of the arch build install dirs to the universal dir. I’ve done that by hand for now. -rluba, 2024-04-24
            if !success return false;
        } else {
            success := build_libcurl_variant(debug = compile_debug);
            if !success return false;
        }
	}

    output_filename: string;
    opts: Generate_Bindings_Options;
    {
        using opts;

		#if OS == .WINDOWS {
			array_add(*library_search_paths, "windows");
            generate_library_declarations = true;
            output_filename = "windows.jai";
        } else {
            #if OS == .LINUX {
                array_add(*library_search_paths, "linux");
            } else #if OS == .MACOS {
                array_add(*library_search_paths, "macos");
            } else {
                assert(false);
            }
            generate_library_declarations = false;
            footer = FOOTER_UNIX;
            output_filename = "unix.jai";
		}

		libcurl_include_path          := tprint("%/include", PLATFORM_NAME);
        array_add(*library_search_paths, tprint("%/lib",     PLATFORM_NAME));
        array_add(*libraries,            .{"libcurl", ""});
        array_add(*include_paths,        libcurl_include_path);
        array_add(*source_files,         tprint("%/curl/curl.h", libcurl_include_path));

        array_add(*strip_enum_value_prefixes, .["CURLcode", "CURLE_"]);

        alias_original_enum_names           = false;
        log_stripped_declarations           = false;
        generate_compile_time_struct_checks = false;

        visitor   = libcurl_visitor;
    }

    return generate_bindings(opts, output_filename);
}

build_libcurl_variant :: (debug: bool, extra_config_args: [] string = .[], suffix := "") -> bool {
    build_type := ifx debug then "Debug" else "Release";

	install_dir := join(PLATFORM_NAME, suffix,, temp);
    success := make_directory_if_it_does_not_exist(install_dir);
    if !success {
        log_error("Could not create directory \"%\"\n", install_dir);
		return false;
    }

	absolute_install_dir := get_absolute_path(install_dir);
	assert(absolute_install_dir != "");

    absolute_build_dir := join(absolute_install_dir, "_build");
    log("Configuring libcurl... \"%\" -> \"%\"", absolute_build_dir, absolute_install_dir);
	if file_exists(absolute_build_dir) {
		success := delete_directory(absolute_build_dir);
		if !success {
			log_error("Could not delete old build directory");
			return false;
		}
	}
    success = make_directory_if_it_does_not_exist(absolute_build_dir);
    if !success {
        log_error("Could not create directory \"%\"\n", absolute_build_dir);
		return false;
    }

	absolute_libcurl_path := get_absolute_path(SOURCE_PATH);
    config_command: [..] string;
    array_add(*config_command,
		"cmake",
		absolute_libcurl_path,
		"-DBUILD_CURL_EXE=OFF",
        "-DENABLE_DEBUG=OFF",
        tprint("-DCMAKE_INSTALL_PREFIX=%", absolute_install_dir),
        tprint("-DCMAKE_PREFIX_PATH=%",    install_dir),
	);
    array_add(*config_command, ..extra_config_args);

    array_add(*config_command, tprint("-DCMAKE_BUILD_TYPE=%", build_type));
    #if OS == .WINDOWS {
        array_add(*config_command, tprint("-DCMAKE_CONFIGURATION_TYPES=%", build_type));
    }
    #if OS == .MACOS {
        array_add(*config_command, "-DCURL_USE_SECTRANSP=ON"); // Tell Curl to use macOS’ builtin SSL library
    }

    // Tried to statically link dependencies like libssl into libcurl – no success.
    // -rluba, 2024-01-04
    // #if OS == .LINUX {
    //     array_add(*config_command, "-DCMAKE_FIND_LIBRARY_SUFFIXES=.a,.so"); // Prefer static libraries
    // } else #if OS == .MACOS {
    //     array_add(*config_command, "-DCMAKE_FIND_LIBRARY_SUFFIXES=.a,.dylib"); // Prefer static libraries
    // }

    run_or_exit(..config_command, working_directory = absolute_build_dir);
    log("Done configuring libcurl");

    log("Building libcurl…");
    build_command: [..] string;
    array_add(*build_command, "cmake", "--build", absolute_build_dir, "--target", "install");
    if OS == .WINDOWS {
        array_add(*build_command, tprint("--config=%", build_type));
    }

    run_or_exit(..build_command);
	log("Done building libcurl");

	return true;
}

run_or_exit :: (command: .. string, working_directory := "") -> string {
    // Enable this to see the commands being executed.
    // Might be useful if, for example, you need to compile LLVM on a platform where we don’t have a Jai compiler yet and want to do it manually.
    // log("Executing command \"%\" in directory \"%\"\n", join(..command, separator = " "), working_directory);

    result, output_string, error_string := run_command(..command, working_directory = working_directory, capture_and_return_output = true, print_captured_output = true);
    defer {
        free(error_string);
    }
    if result.exit_code != 0 {
        log_error("Could not run command \"%\" in directory \"%\". Exit code: %\nError:\n%", get_quoted_command_string(command), working_directory, result.exit_code, error_string);
        // if !LIVE_OUTPUT {
        //     log_error("Output:\n%", output_string);
        // }
        exit(1);
    }
    return output_string;
}


libcurl_visitor :: (decl: *Declaration, parent_decl: *Declaration) -> Declaration_Visit_Result {
    if !parent_decl && array_find(DECLARATIONS_TO_OMIT, decl.name) {
        decl.decl_flags |= .OMIT_FROM_OUTPUT;
        return .STOP;
    }
    return .RECURSE;
}

#import "Basic";
#import "Bindings_Generator";
#import "Compiler";
#import "File";
#import "File_Utilities";
#import "String";
#import "Process";

FOOTER_UNIX :: #string END

#if OS == .MACOS    libcurl :: #library "macos/lib/libcurl";
#if OS == .LINUX    {
    #if LINUX_USE_SYSTEM_LIBRARY {
        libcurl :: #library,system "libcurl";
    } else {
        libcurl :: #library "linux/lib/libcurl";
    }
}

END


