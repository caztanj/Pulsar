optimize_bytecode :: (program: *Bytecode_Program) {
    for program.functions optimize_function_bytecode(it);
}

optimize_function_bytecode :: (function: *Bytecode_Function) {
    if function.instructions.count == 0 return;

    remove_dead_instructions(function);
    jump_threading(function);
}

remove_dead_instructions :: (function: *Bytecode_Function) {
    i := 0;

    removed_indices: [..] int;
    removed_indices.allocator = temp;

    while i < function.instructions.count {
        instruction := *function.instructions[i];

        should_remove :=  instruction.op_code == .MOVE        && instruction.dest == instruction.arg1;
        should_remove ||= instruction.op_code == .LOAD_LOCAL  && instruction.dest == cast(u8) instruction.imm;
        should_remove ||= instruction.op_code == .STORE_LOCAL && instruction.arg1 == cast(u8) instruction.imm;
        should_remove ||= instruction.op_code == .JUMP        && instruction.imm == i + 1;

        if should_remove {
            array_add(*removed_indices, i);
            array_ordered_remove_by_index(*function.instructions, i);

            continue;
        }

        i += 1;
    }

    if removed_indices.count > 0 {
        for * function.instructions {
            is_jump :=  it.op_code == .JUMP;
            is_jump ||= it.op_code == .JUMP_IF_FALSE;
            is_jump ||= it.op_code == .JUMP_IF_TRUE;
            is_jump ||= it.op_code == .JUMP_IF_NOT_NULLISH;
            is_jump ||= it.op_code == .JUMP_IF_LESS_THAN;
            is_jump ||= it.op_code == .JUMP_IF_LOCAL_LESS_THAN_CONST;
            is_jump ||= it.op_code == .ITERATOR_NEXT;
            is_jump ||= it.op_code == .TRY_CONTEXT;

            if is_jump {
                old_target := it.imm;
                new_target := old_target;

                for removed_indices {
                    if it < old_target {
                        new_target -= 1;
                    }
                }

                it.imm = new_target;
            }
        }
    }
}

jump_threading :: (function: *Bytecode_Function) {
    for * function.instructions {
        is_jump :=  it.op_code == .JUMP;
        is_jump ||= it.op_code == .JUMP_IF_FALSE;
        is_jump ||= it.op_code == .JUMP_IF_TRUE;
        is_jump ||= it.op_code == .JUMP_IF_NOT_NULLISH;
        is_jump ||= it.op_code == .JUMP_IF_LESS_THAN;
        is_jump ||= it.op_code == .JUMP_IF_LOCAL_LESS_THAN_CONST;
        is_jump ||= it.op_code == .ITERATOR_NEXT;
        is_jump ||= it.op_code == .TRY_CONTEXT;

        if is_jump {
            target := it.imm;

            for 0..9 {
                if target >= function.instructions.count break;

                target_instruction := function.instructions[target];

                if target_instruction.op_code == .JUMP target = target_instruction.imm;
                else break;
            }

            it.imm = target;
        }
    }
}
