init_vm_atomics :: (vm: *Vm) {
    found, index := get_global_index(vm, "Atomics");
    if found {
        atomics_object := allocate_object(vm);
        atomics_object.prototype = vm.object_prototype;

        set_object_property(vm, atomics_object, "@@Symbol.toStringTag", Value.{ type = .STRING, s = "Atomics" });

        vm.current_realm.globals[index] = .{ type = .OBJECT, object = atomics_object };
    }
}
