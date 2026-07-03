main :: () {
    #if DEBUG_MEMORY defer report_memory_leaks();

    args := get_command_line_arguments();
    if args.count < 2 return;

    defer array_reset(*args);

    dump_bytecode := false;
    profile := false;
    optimize := true;
    file_path := "";
    net_permission := false;

    for i: 1..args.count-1 {
        if args[i] == "-dump" {
            dump_bytecode = true;
        } else if args[i] == "-profile" {
            profile = true;
        } else if args[i] == "-no-opt" {
            optimize = false;
        } else if args[i] == "-net" {
            net_permission = true;
        } else {
            file_path = args[i];
        }
    }

    if file_path == "" return;

    code, success := read_entire_file(file_path,, temp);
    if !success return;

    error, error_message, tokens := tokenize(code,, temp);
    if error {
        log_error(error_message);
        exit(1);
    }

    ast := build_ast(code, tokens,, temp);

    if optimize optimize_ast(ast);

    bc := generate_bytecode(ast);

    if optimize optimize_bytecode(bc);

    if dump_bytecode {
        print(bc);
    }

    vm := run_bytecode(bc, profile, permissions = .NETWORK);

    if profile {
        print("\nProfiling results:\n");

        total_instructions := 0;
        for i: 0..255 total_instructions += vm.profiler.instruction_counts[i];

        print("Total instructions: %\n", total_instructions);
        print("\n% % %\n", pad_string("Instruction", 20), pad_string("Count", 15), pad_string("Percent", 10));

        Profile_Entry :: struct {
            op_code: Op_Code;
            count:   int;
            percent: float64;
        }

        entries: [..] Profile_Entry;
        defer array_free(entries);

        for i: 0..255 {
            if vm.profiler.instruction_counts[i] > 0 {
                entry: Profile_Entry;
                entry.op_code = cast(Op_Code) i;
                entry.count   = vm.profiler.instruction_counts[i];
                entry.percent = (cast(float64) entry.count / cast(float64) total_instructions) * 100.0;
                array_add(*entries, entry);
            }
        }

        for i: 0..entries.count-1 {
            for j: i+1..entries.count-1 {
                if entries[j].count > entries[i].count {
                    temp := entries[i];
                    entries[i] = entries[j];
                    entries[j] = temp;
                }
            }
        }

        for entries {
            s_op_code := pad_string(tprint("%", it.op_code), 20);
            s_count   := pad_string(tprint("%", it.count), 15);
            s_percent := pad_string(tprint("%", formatFloat(it.percent, trailing_width=2)), 10);

            print("% % %\n", s_op_code, s_count, s_percent);
        }
    }

    if vm.has_exception {
        print("Uncaught exception: ");
        print(vm, .{}, .[vm.exception]);
        exit(1);
    }

    reset_temporary_storage();

    deinit(bc);
    deinit(vm);
}

pad_string :: (s: string, width: int) -> string {
    if s.count >= width return s;

    res := tprint("%", s);
    while res.count < width {
        res = tprint("% ", res);
    }
    return res;
}

DEBUG_MEMORY :: false;

#import "Basic" () (MEMORY_DEBUGGER = DEBUG_MEMORY, TEMP_ALLOCATOR_OVERWRITE_MEMORY = false);
#import "File";
#import "String";
#import,file "../module.jai";
