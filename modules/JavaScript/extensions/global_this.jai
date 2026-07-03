init_vm_global_this :: (vm: *Vm) {
    found, global_this_index := get_global_index(vm, "globalThis");

    if found {
        proxy      := allocate_object(vm);
        proxy.kind  = .GLOBAL_PROXY;

        vm.current_realm.globals[global_this_index].type   = .OBJECT;
        vm.current_realm.globals[global_this_index].object = proxy;
    }
}
