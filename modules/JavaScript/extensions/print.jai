init_vm_print :: (vm: *Vm) {
    found, index := get_global_index(vm, "print");

    if found {
        vm.current_realm.globals[index].type            = .NATIVE_FUNCTION;
        vm.current_realm.globals[index].native_function = print;
    }

    found=, console_index := get_global_index(vm, "console");
    if found {
        console_object := allocate_object(vm);

        vm.current_realm.globals[console_index].type   = .OBJECT;
        vm.current_realm.globals[console_index].object = console_object;

        add_static_method(vm, console_object, "log",   print);
        add_static_method(vm, console_object, "error", print);
        add_static_method(vm, console_object, "warn",  print);
        add_static_method(vm, console_object, "info",  print);
        add_static_method(vm, console_object, "debug", print);
    }
}

print :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool = false) -> Value {
    for arguments {
        if #complete it.type == {
            case .UNDEFINED;       print("undefined");
            case .NULL;            print("null");
            case .NUMBER;          print("%", it.number);
            case .OBJECT;          print("[object Object]");
            case .ARRAY;           print("[object Array]");
            case .BOOLEAN;         print("%", it.boolean);
            case .FUNCTION;        print("[object Function]");
            case .NATIVE_FUNCTION; print("[object NativeFunction]");
            case .STRING;          print("%", it.s);
            case .GENERATOR;       print("[object Generator]");
        }

        if it_index < arguments.count - 1 print(" ");
    }

    print("\n");

    return .{};
}