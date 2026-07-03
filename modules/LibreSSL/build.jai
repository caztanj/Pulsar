main :: () {
    set_build_options_dc(.{ do_output = false });

    platform_identifier := get_platform_identifier();

    if file_exists(platform_identifier) delete_directory(platform_identifier);
    make_directory_if_it_does_not_exist(platform_identifier);

    if file_exists(BUILD_DIRECTORY) delete_directory(BUILD_DIRECTORY);
    make_directory_if_it_does_not_exist(BUILD_DIRECTORY);

    absolute_platform_directory := get_absolute_path(platform_identifier);

    set_working_directory(join(path_strip_filename(#filepath), BUILD_DIRECTORY, separator = "/"));

    configure_command: [..] string;

    array_add(
        *configure_command,
        "cmake",
        "-G", "Ninja",
        "-DLIBRESSL_APPS=OFF",
        "-DLIBRESSL_TESTS=OFF",
        sprint("-DCMAKE_INSTALL_PREFIX=%", absolute_platform_directory),
        "-DCMAKE_CONFIGURATION_TYPES=Release",
    );

    if OS == .WINDOWS array_add(*configure_command, "-DUSE_STATIC_MSVC_RUNTIMES=ON");

    array_add(*configure_command, "..");

    result := run_command(..configure_command);
    if result.exit_code != 0 {
        log_error("Error: Failed to run the cmake configure command.");
        exit(1);
    }

    result = run_command("ninja");
    if result.exit_code != 0 {
        log_error("Error: Failed to run the ninja command.");
        exit(1);
    }

    result = run_command("cmake", "--install", ".");
    if result.exit_code != 0 {
        log_error("Error: Failed to run the cmake install command.");
        exit(1);
    }

    set_working_directory(path_strip_filename(#filepath));

    if OS == {
        case .WINDOWS;
            source_crypto      := join(platform_identifier, "lib", "crypto.lib", separator = "/");
            destination_crypto := join(platform_identifier, "crypto.lib",        separator = "/");
            source_ssl         := join(platform_identifier, "lib", "ssl.lib",    separator = "/");
            destination_ssl    := join(platform_identifier, "ssl.lib",           separator = "/");

            atomic_file_replace_or_just_rename_if_destination_file_does_not_exist(source_crypto, destination_crypto);
            atomic_file_replace_or_just_rename_if_destination_file_does_not_exist(source_ssl,    destination_ssl);

        case .LINUX; #through;
        case .MACOS;
            source_crypto      := join(platform_identifier, "lib", "libcrypto.a", separator = "/");
            destination_crypto := join(platform_identifier, "libcrypto.a",        separator = "/");
            source_ssl         := join(platform_identifier, "lib", "libssl.a",    separator = "/");
            destination_ssl    := join(platform_identifier, "libssl.a",           separator = "/");

            atomic_file_replace_or_just_rename_if_destination_file_does_not_exist(source_crypto, destination_crypto);
            atomic_file_replace_or_just_rename_if_destination_file_does_not_exist(source_ssl,    destination_ssl);
    }
}

get_platform_identifier :: () -> string {
    operating_system: string;
    architecture:     string;

    if OS == {
        case .WINDOWS; operating_system = "windows";
        case .LINUX;   operating_system = "linux";
        case .MACOS;   operating_system = "macos";
        case;          assert(false, "Unsupported operating system.");
    }

    if CPU == {
        case .X64;   architecture = "x64";
        case .ARM64; architecture = "arm64";
        case;        assert(false, "Unsupported architecture.");
    }

    return sprint("%_%", operating_system, architecture);
}

#run main();

BUILD_DIRECTORY :: "LibreSSL-4.3.1/build";

#import "Basic";
#import "Compiler";
#import "File";
#import "File_Utilities";
#import "Process";
#import "String";