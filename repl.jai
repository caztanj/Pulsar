read_console_line :: () -> string {
    #if OS == .WINDOWS {
        handle := Windows.GetStdHandle(Windows.STD_INPUT_HANDLE);
        buffer: [1024] u8;
        bytes_read: u32;

        if Windows.ReadFile(handle, buffer.data, cast(u32) buffer.count, *bytes_read, null) {
            s := cast(string) .{cast(s64) bytes_read, buffer.data};

            while s.count > 0 && (s[s.count-1] == #char "\n" || s[s.count-1] == #char "\r") {
                s.count -= 1;
            }

            return copy_string(s);
        }
    } else {
        buffer: [1024] u8;
        bytes_read := POSIX.read(POSIX.STDIN_FILENO, buffer.data, cast(u64) buffer.count);

        if bytes_read > 0 {
            s := cast(string) .{cast(s64) bytes_read, buffer.data};

            while s.count > 0 && (s[s.count-1] == #char "\n" || s[s.count-1] == #char "\r") {
                s.count -= 1;
            }

            return copy_string(s);
        }
    }

    return "";
}

run_repl :: (permissions: Permission) {
    print("Welcome to Pulsar REPL. Type '.exit' to quit.\n");

    vm: *Vm = null;
    bytecode: *Bytecode_Program = null;

    while true {
        print("> ");
        line := read_console_line();
        if !line continue;
        if line == ".exit" break;

        error, error_message, tokens := tokenize(line,, temp);
        if error {
            print("%\n", error_message);
            continue;
        }

        ast := build_ast(line, tokens,, temp);
        if ast.has_error {
            print("Syntax error: %\n", ast.error_message);
            continue;
        }

        optimize_ast(ast);

        if bytecode {
            for bytecode.functions if it.name == "main" {
                it.instructions.count = 0;
                break;
            }
        }

        bytecode = generate_bytecode(ast, bytecode);
        if bytecode.has_error {
            print("Compile error: %\n", bytecode.error_message);
            continue;
        }

        optimize_bytecode(bytecode);

        if !vm {
            vm = run_bytecode(bytecode, false, permissions = permissions, execute_main_function = false);
        }

        result := execute_main(vm, bytecode);

        if vm.has_exception {
            print("Uncaught exception: ");
            print(vm, .{}, .[vm.exception]);

            if vm.has_stack_trace {
                print("%\n", vm.stack_trace);
            }

            vm.has_exception   = false;
            vm.exception       = .{};
            vm.has_stack_trace = false;
            vm.stack_trace     = "";
        } else if result.type != .UNDEFINED {
            print(vm, .{}, .[result]);
        }

        reset_temporary_storage();
    }
}
