#module_parameters () (TRACE_ALLOCATIONS := false, TRACE_GARBAGE_COLLECTION := false);

run :: (code: string, optimize := true, permissions: Permission = 0, silence_console_output := false) -> *Vm {
    tokens: [] Token;
    ast:    *Ast_Program;
    has_error: bool;
    error_message: string;

    {
        push_allocator(temp);
        has_error, error_message, tokens = tokenize(code);
        if has_error {
            vm := New(Vm);
            throw_exception(vm, copy_string(error_message));
            return vm;
        }

        ast = build_ast(code, tokens);
        if ast.has_error {
            vm := New(Vm);
            throw_exception(vm, copy_string(ast.error_message));
            return vm;
        }

        if optimize optimize_ast(ast);
    }

    bytecode := generate_bytecode(ast);
    if bytecode.has_error {
        vm := New(Vm);
        throw_exception(vm, copy_string(bytecode.error_message));
        return vm;
    }

    if optimize optimize_bytecode(bytecode);

    vm := run_bytecode(bytecode, permissions = permissions, execute_main_function = false);
    vm.silence_console_output = silence_console_output;
    execute_main(vm, bytecode);
    collect_garbage_major(vm);

    return vm;
}

get_global :: (vm: *Vm, name: string) -> Value {
    found, index := get_global_index(vm, name);
    if !found return .{ type = .UNDEFINED };

    return vm.current_realm.globals[index];
}

set_global :: (vm: *Vm, name: string, val: Value) {
    found, index := get_global_index(vm, name);
    if !found return;

    vm.current_realm.globals[index] = val;
}

create_realm :: (vm: *Vm) -> *Realm {
    realm := New(Realm);
    realm.globals = NewArray(vm.program.globals.count, Value);
    array_add(*vm.realms, realm);

    old_realm := vm.current_realm;
    vm.current_realm = realm;
    init_common_vm_globals(vm);
    vm.current_realm = old_realm;

    return realm;
}

switch_realm :: (vm: *Vm, realm: *Realm) -> *Realm {
    old := vm.current_realm;
    vm.current_realm = realm;
    return old;
}

Permission :: enum_flags {
    NETWORK;
    FILESYSTEM;
}

#load "ast.jai";
#load "ast_rewriter.jai";
#load "bytecode_generator.jai";
#load "bytecode_rewriter.jai";
#load "bytecode_runner.jai";
#load "gc.jai";
#load "object.jai";
#load "tokenizer.jai";

#load "extensions/array.jai";
#load "extensions/boolean.jai";
#load "extensions/date.jai";
#load "extensions/fetch.jai";
#load "extensions/file.jai";
#load "extensions/global_this.jai";
#load "extensions/http.jai";
#load "extensions/json.jai";
#load "extensions/map.jai";
#load "extensions/math.jai";
#load "extensions/number.jai";
#load "extensions/object.jai";
#load "extensions/print.jai";
#load "extensions/console.jai";
#load "extensions/promise.jai";
#load "extensions/router.jai";
#load "extensions/set.jai";
#load "extensions/string.jai";
#load "extensions/typed_array.jai";
#load "extensions/timer.jai";
#load "extensions/error.jai";
#load "extensions/regexp.jai";
#load "extensions/symbol.jai";

#scope_module

#import "Basic";
#import "File";
#import "File_Utilities";
#import "Hash_Table";
#import "Math";
#import "Random";
#import "Socket";
#import "String";
#import "Thread";

#import,dir "../Http_Server";
#import,dir "../Http_Client";

Uniform :: #import,dir "../Uniform";
