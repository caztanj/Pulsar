main :: () {
    #if DEBUG_MEMORY defer report_memory_leaks();

    success, args, is_set, free_args := parse_arguments(Arguments);
    if !success exit(EXIT_CODE_INVALID_ARGUMENTS);

    permissions: Permission;
    if args.network    permissions |= .NETWORK;
    if args.filesystem permissions |= .FILESYSTEM;

    if args.repl {
        run_repl(permissions);
        exit(EXIT_CODE_SUCCESS);
    }

    if free_args.count != 1 {
        log_error("Usage: Pulsar [options] <file.js>");
        exit(EXIT_CODE_INVALID_ARGUMENTS);
    }

    file_path := free_args[0];

    code:, success = read_entire_file(file_path);
    if !success {
        log_error("Could not read file: %", file_path);
        exit(EXIT_CODE_FILE_NOT_FOUND);
    }

    error, error_message, tokens := tokenize(code,, temp);
    if error {
        log_error("%", error_message);
        exit(EXIT_CODE_JS_ERROR);
    }

    ast := build_ast(code, tokens,, temp);
    optimize_ast(ast);

    bytecode := generate_bytecode(ast);
    optimize_bytecode(bytecode);

    vm := run_bytecode(bytecode, false, permissions = permissions);

    if vm.has_exception {
        print("Uncaught exception: ");
        print(vm, .{}, .[vm.exception]);

        if vm.has_stack_trace {
            print("%\n", vm.stack_trace);
        }

        exit(EXIT_CODE_JS_ERROR);
    }

    reset_temporary_storage();

    deinit(bytecode);
    deinit(vm);

    exit(EXIT_CODE_SUCCESS);
}

Arguments :: struct {
    network:    bool;
    filesystem: bool;

    repl:       bool;
}

EXIT_CODE_SUCCESS            :: 0;
EXIT_CODE_INVALID_ARGUMENTS  :: 1;
EXIT_CODE_FILE_NOT_FOUND     :: 2;
EXIT_CODE_JS_ERROR           :: 3;

DEBUG_MEMORY :: false;

#if OS == .WINDOWS {
    Windows :: #import "Windows";
} else {
    POSIX :: #import "POSIX";
}

#load "repl.jai";

#import "Basic" () (MEMORY_DEBUGGER = DEBUG_MEMORY, TEMP_ALLOCATOR_OVERWRITE_MEMORY = false);
#import "Command_Line";
#import "File";
#import "JavaScript";