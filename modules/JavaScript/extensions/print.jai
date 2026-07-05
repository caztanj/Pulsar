init_vm_print :: (vm: *Vm) {
    found, index := get_global_index(vm, "print");

    if found {
        vm.current_realm.globals[index].type            = .NATIVE_FUNCTION;
        vm.current_realm.globals[index].native_function = print;
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