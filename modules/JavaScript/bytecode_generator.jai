
get_property_index :: (generator: *Bytecode_Generator, name: string) -> int {
    return get_property_index_standalone(generator.program, name);
}

emit_instruction :: (generator: *Bytecode_Generator, instruction: Instruction) {
    assert(generator.current_function != null);
    array_add(*generator.current_function.instructions, instruction);
}

deinit :: (program: *Bytecode_Program) {
    if !program return;

    for program.functions {
        array_free(it.instructions);
        array_free(it.locals);

        if it.name.data free(it.name.data);

        free(it);
    }

    array_free(program.functions);
    array_free(program.constants);
    array_free(program.globals);
    array_free(program.property_names);

    deinit(*program.property_names_hash);

    free(program);
}

print :: (program: *Bytecode_Program) {
    print("Constants (%):\n", program.constants.count);
    for program.constants print("  [%] %\n", it_index, it);

    print("Globals (%):\n", program.globals.count);
    for program.globals print("  [%] %\n", it_index, it);

    print("Property Names (%):\n", program.property_names.count);
    for program.property_names print("  [%] %\n", it_index, it);

    print("Functions (%):\n", program.functions.count);
    for func: program.functions {
        print("  Function [%] '%' (arguments: %, locals: %):\n", it_index, func.name, func.arguments_count, func.locals_count);

        if func.locals.count > 0 {
            print("    Locals:\n");
            for func.locals print("      [%] %\n", it_index, it);
        }

        for instruction, i: func.instructions {
            print("    [%]", i);

            if #complete instruction.op_code == {
                case .LOAD_CONST;         print(" LOAD_CONST         dest: R%, imm: % (value: %)", instruction.dest, instruction.imm, program.constants[instruction.imm]);
                case .LOAD_GLOBAL;        print(" LOAD_GLOBAL        dest: R%, imm: % (name: %)", instruction.dest, instruction.imm, program.globals[instruction.imm]);
                case .STORE_GLOBAL;       print(" STORE_GLOBAL       arg1: R%, imm: % (name: %)", instruction.arg1, instruction.imm, program.globals[instruction.imm]);
                case .LOAD_LOCAL;         print(" LOAD_LOCAL         dest: R%, imm: %", instruction.dest, instruction.imm);
                case .STORE_LOCAL;        print(" STORE_LOCAL        arg1: R%, imm: %", instruction.arg1, instruction.imm);
                case .ADD;                print(" ADD                dest: R%, arg1: R%, arg2: R%", instruction.dest, instruction.arg1, instruction.arg2);
                case .SUB;                print(" SUB                dest: R%, arg1: R%, arg2: R%", instruction.dest, instruction.arg1, instruction.arg2);
                case .MUL;                print(" MUL                dest: R%, arg1: R%, arg2: R%", instruction.dest, instruction.arg1, instruction.arg2);
                case .DIV;                print(" DIV                dest: R%, arg1: R%, arg2: R%", instruction.dest, instruction.arg1, instruction.arg2);
                case .MOD;                print(" MOD                dest: R%, arg1: R%, arg2: R%", instruction.dest, instruction.arg1, instruction.arg2);
                case .CALL;
                    arguments_count := instruction.imm & 0xFFFF;
                    first_argument_register := instruction.imm >> 16;
                                          print(" CALL               dest: R%, callee: R%, this: R%, arguments: R%..R%", instruction.dest, instruction.arg1, instruction.arg2, first_argument_register, first_argument_register + arguments_count - 1);
                case .NEW_CALL;
                    arguments_count := instruction.imm & 0xFFFF;
                    first_argument_register := instruction.imm >> 16;
                                          print(" NEW_CALL            dest: R%, callee: R%, this: R%, arguments: R%..R%", instruction.dest, instruction.arg1, instruction.arg2, first_argument_register, first_argument_register + arguments_count - 1);
                case .RETURN;             print(" RETURN             arg1: R%", instruction.arg1);
                case .NEW_OBJECT;         print(" NEW_OBJECT         dest: R%", instruction.dest);
                case .SET_FIELD;          print(" SET_FIELD          dest: R%, arg1: R%, imm: % (name: %)", instruction.dest, instruction.arg1, instruction.imm, program.property_names[instruction.imm]);
                case .GET_FIELD;          print(" GET_FIELD          dest: R%, arg1: R%, imm: % (name: %)", instruction.dest, instruction.arg1, instruction.imm, program.property_names[instruction.imm]);
                case .NEW_ARRAY;          print(" NEW_ARRAY          dest: R%, imm: % (elements)", instruction.dest, instruction.imm);
                case .ARRAY_GET;          print(" ARRAY_GET          dest: R%, arg1: R%, arg2: R%", instruction.dest, instruction.arg1, instruction.arg2);
                case .ARRAY_SET;          print(" ARRAY_SET          arg1: R%, arg2: R%, imm: % (index)", instruction.arg1, instruction.arg2, instruction.imm);
                case .LOAD_FUNC;          print(" LOAD_FUNC          dest: R%, imm: % (name: %)", instruction.dest, instruction.imm, program.functions[instruction.imm].name);
                case .EQUAL;              print(" EQUAL              dest: R%, arg1: R%, arg2: R%", instruction.dest, instruction.arg1, instruction.arg2);
                case .NOT_EQUAL;          print(" NOT_EQUAL          dest: R%, arg1: R%, arg2: R%", instruction.dest, instruction.arg1, instruction.arg2);
                case .LESS_THAN;          print(" LESS_THAN          dest: R%, arg1: R%, arg2: R%", instruction.dest, instruction.arg1, instruction.arg2);
                case .GREATER_THAN;       print(" GREATER_THAN       dest: R%, arg1: R%, arg2: R%", instruction.dest, instruction.arg1, instruction.arg2);
                case .LESS_THAN_EQUAL;    print(" LESS_THAN_EQUAL    dest: R%, arg1: R%, arg2: R%", instruction.dest, instruction.arg1, instruction.arg2);
                case .GREATER_THAN_EQUAL; print(" GREATER_THAN_EQUAL dest: R%, arg1: R%, arg2: R%", instruction.dest, instruction.arg1, instruction.arg2);
                case .STRICT_EQUAL;       print(" STRICT_EQUAL       dest: R%, arg1: R%, arg2: R%", instruction.dest, instruction.arg1, instruction.arg2);
                case .STRICT_NOT_EQUAL;   print(" STRICT_NOT_EQUAL   dest: R%, arg1: R%, arg2: R%", instruction.dest, instruction.arg1, instruction.arg2);
                case .INSTANCEOF;         print(" INSTANCEOF         dest: R%, arg1: R%, arg2: R%", instruction.dest, instruction.arg1, instruction.arg2);
                case .IN;                 print(" IN                 dest: R%, arg1: R%, arg2: R%", instruction.dest, instruction.arg1, instruction.arg2);
                case .BITWISE_AND;        print(" BITWISE_AND        dest: R%, arg1: R%, arg2: R%", instruction.dest, instruction.arg1, instruction.arg2);
                case .BITWISE_OR;         print(" BITWISE_OR         dest: R%, arg1: R%, arg2: R%", instruction.dest, instruction.arg1, instruction.arg2);
                case .BITWISE_XOR;        print(" BITWISE_XOR        dest: R%, arg1: R%, arg2: R%", instruction.dest, instruction.arg1, instruction.arg2);
                case .JUMP;               print(" JUMP               imm: %", instruction.imm);
                case .JUMP_IF_FALSE;      print(" JUMP_IF_FALSE      arg1: R%, imm: %", instruction.arg1, instruction.imm);
                case .JUMP_IF_TRUE;       print(" JUMP_IF_TRUE       arg1: R%, imm: %", instruction.arg1, instruction.imm);
                case .MOVE;               print(" MOVE               dest: R%, arg1: R%", instruction.dest, instruction.arg1);
                case .LOGICAL_NOT;        print(" LOGICAL_NOT        dest: R%, arg1: R%", instruction.dest, instruction.arg1);
                case .TYPEOF;             print(" TYPEOF             dest: R%, arg1: R%", instruction.dest, instruction.arg1);
                case .THROW;              print(" THROW              arg1: R%", instruction.arg1);
                case .YIELD;              print(" YIELD              dest: R%, arg1: R%", instruction.dest, instruction.arg1);
                case .AWAIT;              print(" AWAIT              dest: R%, arg1: R%", instruction.dest, instruction.arg1);
                case .IMPORT;             print(" IMPORT             dest: R%, imm: % (source: %)", instruction.dest, instruction.imm, program.constants[instruction.imm]);
                case .EXPORT;             print(" EXPORT             arg1: R%, imm: % (name: %)", instruction.arg1, instruction.imm, ifx instruction.imm == -1 then "default" else program.property_names[instruction.imm]);
                case .LOAD_UPVALUE;       print(" LOAD_UPVALUE       dest: R%, imm: %", instruction.dest, instruction.imm);
                case .STORE_UPVALUE;      print(" STORE_UPVALUE      arg1: R%, imm: %", instruction.arg1, instruction.imm);
                case .LOAD_THIS;          print(" LOAD_THIS          dest: R%", instruction.dest);
                case .TRY_CONTEXT;        print(" TRY_CONTEXT        arg1: R% (catch_reg), imm: % (catch_pc)", instruction.arg1, instruction.imm);
                case .POP_TRY_CONTEXT;    print(" POP_TRY_CONTEXT");
                case .ITERATOR_NEXT;      print(" ITERATOR_NEXT      dest: R%, arg1: R%, imm: % (jump_target)", instruction.dest, instruction.arg1, instruction.imm);
                case .ITERATOR_CLOSE;     print(" ITERATOR_CLOSE     arg1: R%", instruction.arg1);
                case .COMPUTED_SET;       print(" COMPUTED_SET       dest: R% (obj), arg1: R% (prop), arg2: R% (val)", instruction.dest, instruction.arg1, instruction.arg2);
                case .EXPONENTIATION;     print(" EXPONENTIATION     dest: R%, arg1: R%, arg2: R%", instruction.dest, instruction.arg1, instruction.arg2);
                case .JUMP_IF_NOT_NULLISH; print(" JUMP_IF_NOT_NULLISH arg1: R%, imm: %", instruction.arg1, instruction.imm);
                case .UNARY_MINUS;        print(" UNARY_MINUS        dest: R%, arg1: R%", instruction.dest, instruction.arg1);
                case .ADD_CONST;          print(" ADD_CONST          dest: R%, arg1: R%, imm: % (value: %)", instruction.dest, instruction.arg1, instruction.imm, program.constants[instruction.imm]);
                case .SUB_CONST;          print(" SUB_CONST          dest: R%, arg1: R%, imm: % (value: %)", instruction.dest, instruction.arg1, instruction.imm, program.constants[instruction.imm]);
                case .SET_PROTOTYPE;      print(" SET_PROTOTYPE      dest: R%, arg1: R%", instruction.dest, instruction.arg1);
                case .SUPER_CALL;         print(" SUPER_CALL         dest: R%, arg1: R%, arg2: R%", instruction.dest, instruction.arg1, instruction.arg2);
                case .ADD_REG_REG;        print(" ADD_REG_REG        dest: R%, arg1: R%, arg2: R%", instruction.dest, instruction.arg1, instruction.arg2);
                case .JUMP_IF_LESS_THAN;  print(" JUMP_IF_LESS_THAN  arg1: R%, arg2: R%, imm: %", instruction.arg1, instruction.arg2, instruction.imm);
                case .INC_LOCAL;          print(" INC_LOCAL          imm: R%", instruction.imm);
                case .DEC_LOCAL;          print(" DEC_LOCAL          imm: R%", instruction.imm);
                case .ADD_LOCAL_LOCAL;    print(" ADD_LOCAL_LOCAL    dest: R%, arg1: R%", instruction.dest, instruction.arg1);
                case .SUB_LOCAL_LOCAL;    print(" SUB_LOCAL_LOCAL    dest: R%, arg1: R%", instruction.dest, instruction.arg1);
                case .JUMP_IF_LOCAL_LESS_THAN_CONST; print(" JUMP_IF_LOCAL_LESS_THAN_CONST dest: R%, imm_const: %, imm_jump: %", instruction.dest, instruction.arg1, instruction.imm);
                case .ARRAY_SLICE;        print(" ARRAY_SLICE        dest: R%, arg1: R%, imm: % (start)", instruction.dest, instruction.arg1, instruction.imm);
                case .ARRAY_PUSH;         print(" ARRAY_PUSH         arg1: R%, arg2: R%", instruction.arg1, instruction.arg2);
                case .OBJECT_SPREAD;      print(" OBJECT_SPREAD      dest: R%, arg1: R%", instruction.dest, instruction.arg1);
                case .ARRAY_APPEND;       print(" ARRAY_APPEND       arg1: R%, arg2: R%", instruction.arg1, instruction.arg2);
                case .NEW_CALL_APPLY;     print(" NEW_CALL_APPLY     dest: R%, callee: R%, args_array: R%", instruction.dest, instruction.arg1, instruction.arg2);
                case .CALL_APPLY;         print(" CALL_APPLY         dest: R%, callee: R%, this: R%, args_array: R% (imm)", instruction.dest, instruction.arg1, instruction.arg2, instruction.imm);
            }

            print("\n");
        }
    }
}

collect_identifiers :: (node: *Ast_Node, identifiers: *[..] string) {
    if !node return;

    if node.kind == {
        case .IDENTIFIER;
            identifier := cast(*Ast_Identifier) node;
            array_add(identifiers, identifier.name);

        case .ARRAY_LITERAL;
            array_literal := cast(*Ast_Array_Literal) node;
            for array_literal.elements collect_identifiers(it, identifiers);

        case .OBJECT_LITERAL;
            object_literal := cast(*Ast_Object_Literal) node;
            for object_literal.properties collect_identifiers(it.value, identifiers);
    }
}

collect_globals :: (generator: *Bytecode_Generator, node: *Ast_Node) {
    if !node return;

    if node.kind == {
        case .VARIABLE_DECLARATION;
            variable_declaration := cast(*Ast_Variable_Declaration) node;

            identifiers: [..] string;
            identifiers.allocator = temp;

            for variable_declaration.declarations collect_identifiers(it.identifier, *identifiers);

            for identifiers {
                found := false;

                for global: generator.program.globals if global == it {
                    found = true;
                    break;
                }

                if !found array_add(*generator.program.globals, it);
            }

        case .IDENTIFIER;
            identifier := cast(*Ast_Identifier) node;

            is_local := false;
            for generator.locals if it == identifier.name {
                is_local = true;
                break;
            }

            if !is_local {
                found := false;

                for generator.program.globals if it == identifier.name {
                    found = true;
                    break;
                }

                if !found array_add(*generator.program.globals, identifier.name);
            }

        case .PROGRAM;
            program := cast(*Ast_Program) node;
            for program.statements collect_globals(generator, it);

        case .BLOCK_STATEMENT;
            block_statement := cast(*Ast_Block_Statement) node;
            for block_statement.body collect_globals(generator, it);

        case .FUNCTION_DECLARATION;
            function_declaration := cast(*Ast_Function_Declaration) node;

            if generator.current_function.name == "main" || (generator.current_function.name.count > 0 && generator.current_function.name[0] == "/") {
                found := false;

                for generator.program.globals {
                    if it == function_declaration.identifier.name {
                        found = true;
                        break;
                    }
                }

                if !found array_add(*generator.program.globals, function_declaration.identifier.name);
            }

        case .EXPRESSION_STATEMENT;
            expression_statement := cast(*Ast_Expression_Statement) node;
            collect_globals(generator, expression_statement.expression);

        case .ASSIGNMENT_EXPRESSION;
            assignment_expression := cast(*Ast_Assignment_Expression) node;

            collect_globals(generator, assignment_expression.left);
            collect_globals(generator, assignment_expression.right);

        case .BINARY_EXPRESSION;
            binary_expression := cast(*Ast_Binary_Expression) node;

            collect_globals(generator, binary_expression.left);
            collect_globals(generator, binary_expression.right);

        case .CALL_EXPRESSION;
            call_expression := cast(*Ast_Call_Expression) node;

            collect_globals(generator, call_expression.callee);

            for call_expression.arguments collect_globals(generator, it);

        case .NEW_EXPRESSION;
            new_expression := cast(*Ast_New_Expression) node;

            collect_globals(generator, new_expression.callee);

            for new_expression.arguments collect_globals(generator, it);

        case .MEMBER_EXPRESSION;
            member_expression := cast(*Ast_Member_Expression) node;
            collect_globals(generator, member_expression.object);

        case .IF_STATEMENT;
            if_statement := cast(*Ast_If_Statement) node;

            collect_globals(generator, if_statement.condition);
            collect_globals(generator, if_statement.then_branch);
            collect_globals(generator, if_statement.else_branch);

        case .WHILE_STATEMENT;
            while_statement := cast(*Ast_While_Statement) node;

            collect_globals(generator, while_statement.condition);
            collect_globals(generator, while_statement.body);

        case .RETURN_STATEMENT;
            return_statement := cast(*Ast_Return_Statement) node;
            collect_globals(generator, return_statement.argument);

        case .EXPORT_STATEMENT;
            export_statement := cast(*Ast_Export_Statement) node;
            collect_globals(generator, export_statement.declaration);

        case .TRY_STATEMENT;
            try_statement := cast(*Ast_Try_Statement) node;

            collect_globals(generator, cast(*Ast_Node) try_statement.try_block);

            if try_statement.catch_block   collect_globals(generator, cast(*Ast_Node) try_statement.catch_block);
            if try_statement.finally_block collect_globals(generator, cast(*Ast_Node) try_statement.finally_block);

        case .FOR_OF_STATEMENT;
            for_of_statement := cast(*Ast_For_Of_Statement) node;

            collect_globals(generator, for_of_statement.left);
            collect_globals(generator, for_of_statement.right);
            collect_globals(generator, for_of_statement.body);

        case .BREAK_STATEMENT;
        case .CONTINUE_STATEMENT;

        case .LOGICAL_EXPRESSION;
            logical_expression := cast(*Ast_Logical_Expression) node;

            collect_globals(generator, logical_expression.left);
            collect_globals(generator, logical_expression.right);

        case .UPDATE_EXPRESSION;
            update_expression := cast(*Ast_Update_Expression) node;
            collect_globals(generator, update_expression.argument);

        case .UNARY_EXPRESSION;
            unary_expression := cast(*Ast_Unary_Expression) node;
            collect_globals(generator, unary_expression.right);

        case .FOR_STATEMENT;
            for_statement := cast(*Ast_For_Statement) node;

            collect_globals(generator, for_statement.init);
            collect_globals(generator, for_statement.condition);
            collect_globals(generator, cast(*Ast_Node) for_statement.update);
            collect_globals(generator, for_statement.body);

        case .ARRAY_LITERAL;
            array_literal := cast(*Ast_Array_Literal) node;
            for array_literal.elements collect_globals(generator, it);

        case .OBJECT_LITERAL;
            object_literal := cast(*Ast_Object_Literal) node;
            for object_literal.properties collect_globals(generator, it.value);

        case .SWITCH_STATEMENT;
            switch_statement := cast(*Ast_Switch_Statement) node;

            collect_globals(generator, switch_statement.discriminant);

            for switch_statement.cases {
                if  it.test       collect_globals(generator, it.test);
                for it.consequent collect_globals(generator, it);
            }
    }
}

generate_bytecode :: (ast: *Ast_Program, program: *Bytecode_Program = null) -> *Bytecode_Program {
    generator: Bytecode_Generator;
    generator.locals.allocator = temp;
    generator.loop_stack.allocator = temp;

    if program {
        generator.program = program;
    } else {
        generator.program = New(Bytecode_Program);

        array_add(*generator.program.globals, "globalThis");
        array_add(*generator.program.globals, "Promise");
        array_add(*generator.program.globals, "Realm");
        array_add(*generator.program.globals, "print");
        array_add(*generator.program.globals, "true");
        array_add(*generator.program.globals, "false");
        array_add(*generator.program.globals, "undefined");
        array_add(*generator.program.globals, "null");
        array_add(*generator.program.globals, "Infinity");
        array_add(*generator.program.globals, "NaN");
        array_add(*generator.program.globals, "Number");
        array_add(*generator.program.globals, "Array");
        array_add(*generator.program.globals, "String");
        array_add(*generator.program.globals, "Boolean");
        array_add(*generator.program.globals, "JSON");
        array_add(*generator.program.globals, "Map");
        array_add(*generator.program.globals, "Set");
        array_add(*generator.program.globals, "HttpServer");
        array_add(*generator.program.globals, "fetch");
    }

    main_function: *Bytecode_Function;
    if program {
        for program.functions {
            if it.name == "main" {
                main_function = it;
                break;
            }
        }
    }

    if !main_function {
        main_function = New(Bytecode_Function);

        main_function.name = copy_string("main");
        main_function.flags |= .TOP_LEVEL;

        array_add(*generator.program.functions, main_function);
    }

    generator.current_function = main_function;

    for ast.statements collect_globals(*generator, it);
    for ast.statements emit_statement(*generator, it);

    main_function.locals_count = generator.next_register;

    if generator.has_error {
        generator.program.has_error = true;
        generator.program.error_message = generator.error_message;
    }

    return generator.program;
}

generate_module_bytecode :: (ast: *Ast_Program, program: *Bytecode_Program, name: string) -> *Bytecode_Function {
    generator: Bytecode_Generator;

    generator.program = program;
    generator.locals.allocator = temp;
    generator.loop_stack.allocator = temp;

    module_function := New(Bytecode_Function);

    module_function.name = copy_string(name);
    module_function.flags |= .TOP_LEVEL;

    array_add(*generator.program.functions, module_function);

    generator.current_function = module_function;

    for ast.statements collect_globals(*generator, it);
    for ast.statements emit_statement(*generator, it);

    module_function.locals_count = generator.next_register;

    if generator.has_error {
        generator.program.has_error = true;
        generator.program.error_message = generator.error_message;
    }

    return module_function;
}

get_local_index :: (generator: *Bytecode_Generator, name: string) -> int {
    for generator.locals {
        if it == name {
            return it_index;
        }
    }

    return -1;
}

resolve_variable :: (generator: *Bytecode_Generator, name: string) -> Variable_Location {
    index := -1;
    level := 0;

    current := generator;
    while current {
        for current.locals {
            if it == name {
                index = it_index;
                break;
            }
        }

        if index != -1 break;

        current = current.parent;
        level  += 1;
    }

    if index != -1 {
        if level == 0 return .{ .LOCAL, index, 0 };
        else          return .{ .UPVALUE, index, level };
    }

    for generator.program.globals {
        if it == name return .{ .GLOBAL, it_index, 0 };
    }

    return .{ .NOT_FOUND, -1, 0 };
}

store_local_or_global :: (generator: *Bytecode_Generator, name: string, register: u8) {
    location := resolve_variable(generator, name);

    instruction := Instruction.{
        arg1 = register,
    };

    if location.type == {
        case .LOCAL;
            instruction.op_code = .STORE_LOCAL;
            instruction.imm = cast(s32) location.index;
            emit_instruction(generator, instruction);

        case .UPVALUE;
            instruction.op_code = .STORE_UPVALUE;
            instruction.imm = (cast(s32) location.level << 16) | cast(s32) location.index;
            emit_instruction(generator, instruction);

        case .GLOBAL;
            instruction.op_code = .STORE_GLOBAL;
            instruction.imm = cast(s32) location.index;
            emit_instruction(generator, instruction);

        case .NOT_FOUND;
            is_global := generator.current_function && (generator.current_function.flags & .TOP_LEVEL);

            if is_global {
                array_add(*generator.program.globals, name);

                instruction.op_code = .STORE_GLOBAL;
                instruction.imm = cast(s32) (generator.program.globals.count - 1);
                emit_instruction(generator, instruction);
            } else {
                array_add(*generator.locals, name);
                index := generator.locals.count - 1;

                instruction.op_code = .STORE_LOCAL;
                instruction.imm = cast(s32) index;

                if generator.current_function {
                    emit_instruction(generator, instruction);
                    if index >= generator.current_function.locals_count generator.current_function.locals_count = index + 1;
                }
            }
    }
}

load_const :: (generator: *Bytecode_Generator, register: u8, value: Value) {
    index := generator.program.constants.count;

    array_add(*generator.program.constants, value);

    instruction := Instruction.{
        op_code = .LOAD_CONST,
        dest    = register,
        imm     = cast(s32) index,
    };

    emit_instruction(generator, instruction);
}

emit_store :: (generator: *Bytecode_Generator, left: *Ast_Node, value_register: u8) {
    if left.kind == {
        case .IDENTIFIER;
            identifier := cast(*Ast_Identifier) left;
            store_local_or_global(generator, identifier.name, value_register);

        case .MEMBER_EXPRESSION;
            member_expression := cast(*Ast_Member_Expression) left;
            object_register := emit_expression(generator, member_expression.object);

            if member_expression.computed {
                property_register := emit_expression(generator, member_expression.property);

                instruction := Instruction.{
                    op_code = .COMPUTED_SET,
                    dest    = object_register,
                    arg1    = property_register,
                    arg2    = value_register,
                };

                emit_instruction(generator, instruction);
            } else {
                identifier := cast(*Ast_Identifier) member_expression.property;
                index      := get_property_index(generator, identifier.name);

                instruction := Instruction.{
                    op_code = .SET_FIELD,
                    dest    = object_register,
                    arg1    = value_register,
                    imm     = cast(s32) index,
                };

                emit_instruction(generator, instruction);
            }

        case .ARRAY_LITERAL;
            array_literal := cast(*Ast_Array_Literal) left;

            for array_literal.elements {
                if !it continue;

                if it.kind == .SPREAD_ELEMENT {
                    spread_element := cast(*Ast_Spread_Element) it;

                    slice_register := generator.next_register;

                    generator.next_register += 1;

                    instruction := Instruction.{
                        op_code = .ARRAY_SLICE,
                        dest    = slice_register,
                        arg1    = value_register,
                        imm     = cast(s32) it_index,
                    };

                    emit_instruction(generator, instruction);

                    emit_store(generator, spread_element.argument, slice_register);

                    break;
                } else {
                    index_register := generator.next_register;

                    generator.next_register += 1;

                    load_const(generator, index_register, .{ type = .NUMBER, number = cast(float64) it_index });

                    element_value_register := generator.next_register;

                    generator.next_register += 1;

                    instruction := Instruction.{
                        op_code = .ARRAY_GET,
                        dest    = element_value_register,
                        arg1    = value_register,
                        arg2    = index_register,
                    };

                    emit_instruction(generator, instruction);

                    emit_store(generator, it, element_value_register);
                }
            }

        case .OBJECT_LITERAL;
            object_literal := cast(*Ast_Object_Literal) left;

            for object_literal.properties {
                key_register := generator.next_register;

                generator.next_register += 1;

                load_const(generator, key_register, .{ type = .STRING, s = it.key });

                element_value_register := generator.next_register;

                generator.next_register += 1;

                instruction := Instruction.{
                    op_code = .ARRAY_GET,
                    dest    = element_value_register,
                    arg1    = value_register,
                    arg2    = key_register,
                };

                emit_instruction(generator, instruction);

                emit_store(generator, it.value, element_value_register);
            }
    }
}

emit_statement :: (generator: *Bytecode_Generator, node: *Ast_Node) {
    if !node return;

    if #complete node.kind == {
        case .VARIABLE_DECLARATOR;
        case .VARIABLE_DECLARATION;
            variable_declaration := cast(*Ast_Variable_Declaration) node;

            for variable_declaration.declarations {
                register: u8;

                if it.init {
                    register = emit_expression(generator, it.init);
                } else {
                    register = generator.next_register;
                    generator.next_register += 1;
                    load_const(generator, register, .{ type = .UNDEFINED });
                }

                emit_store(generator, it.identifier, register);
            }

        case .FUNCTION_DECLARATION;
            function_declaration := cast(*Ast_Function_Declaration) node;

            is_global := generator.current_function && (generator.current_function.flags & .TOP_LEVEL);

            if !is_global {
                found := false;

                for generator.locals {
                    if it == function_declaration.identifier.name {
                        found = true;
                        break;
                    }
                }

                if !found {
                    array_add(*generator.locals, function_declaration.identifier.name);

                    if generator.locals.count > generator.current_function.locals_count {
                        generator.current_function.locals_count = generator.locals.count;
                        generator.next_register = cast(u8) generator.locals.count;
                    }
                }
            }

            nested_generator := Bytecode_Generator.{
                program              = generator.program,
                parent               = generator,
                next_register        = cast(u8) function_declaration.parameters.count,
                locals.allocator     = temp,
                loop_stack.allocator = temp,
            };

            bytecode_function := New(Bytecode_Function);

            bytecode_function.name            = copy_string(function_declaration.identifier.name);
            bytecode_function.arguments_count = function_declaration.parameters.count;
            if function_declaration.is_generator bytecode_function.flags |= .GENERATOR;
            if function_declaration.is_async bytecode_function.flags |= .ASYNC;

            for function_declaration.parameters {
                if it.kind == .SPREAD_ELEMENT {
                    spread     := cast(*Ast_Spread_Element) it;
                    identifier := cast(*Ast_Identifier) spread.argument;

                    array_add(*nested_generator.locals, identifier.name);

                    bytecode_function.flags |= .REST_PARAMETER;
                } else {
                    identifier := cast(*Ast_Identifier) it;
                    array_add(*nested_generator.locals, identifier.name);
                }
            }

            nested_generator.current_function = bytecode_function;

            for function_declaration.body.body emit_statement(*nested_generator, it);

            bytecode_function.locals_count = nested_generator.next_register;

            for nested_generator.locals array_add(*bytecode_function.locals, it);

            array_add(*generator.program.functions, bytecode_function);

            function_index := generator.program.functions.count - 1;

            register := generator.next_register;

            generator.next_register += 1;

            instruction := Instruction.{
                op_code = .LOAD_FUNC,
                dest    = register,
                imm     = cast(s32) function_index,
            };

            emit_instruction(generator, instruction);

            store_local_or_global(generator, function_declaration.identifier.name, register);

        case .RETURN_STATEMENT;
            return_statement := cast(*Ast_Return_Statement) node;

            register: u8 = 0;

            if return_statement.argument register = emit_expression(generator, return_statement.argument);

            instruction := Instruction.{
                op_code = .RETURN,
                arg1    = register,
            };

            emit_instruction(generator, instruction);

        case .EXPRESSION_STATEMENT;
            expression_statement := cast(*Ast_Expression_Statement) node;
            emit_expression(generator, expression_statement.expression);

        case .BLOCK_STATEMENT;
            block_statement := cast(*Ast_Block_Statement) node;
            for block_statement.body emit_statement(generator, it);

        case .IF_STATEMENT;
            if_statement := cast(*Ast_If_Statement) node;

            condition_register := emit_expression(generator, if_statement.condition);

            jump_if_false_instruction := Instruction.{
                op_code = .JUMP_IF_FALSE,
                arg1    = condition_register,
            };

            jump_if_false_index := generator.current_function.instructions.count;

            array_add(*generator.current_function.instructions, jump_if_false_instruction);

            emit_statement(generator, if_statement.then_branch);

            if if_statement.else_branch {
                jump_instruction := Instruction.{
                    op_code = .JUMP,
                };

                jump_index := generator.current_function.instructions.count;

                array_add(*generator.current_function.instructions, jump_instruction);

                generator.current_function.instructions[jump_if_false_index].imm = cast(s32) generator.current_function.instructions.count;

                emit_statement(generator, if_statement.else_branch);

                generator.current_function.instructions[jump_index].imm = cast(s32) generator.current_function.instructions.count;
            } else {
                generator.current_function.instructions[jump_if_false_index].imm = cast(s32) generator.current_function.instructions.count;
            }

        case .WHILE_STATEMENT;
            while_statement := cast(*Ast_While_Statement) node;

            loop_context := Loop_Context.{
                continue_jumps.allocator = temp,
                break_jumps.allocator    = temp,
                continue_target          = generator.current_function.instructions.count,
            };

            array_add(*generator.loop_stack, loop_context);

            loop_start_index := generator.current_function.instructions.count;

            jump_if_false_index := -1;

            if while_statement.condition.kind == .BINARY_EXPRESSION {
                binary_expression := cast(*Ast_Binary_Expression) while_statement.condition;

                if binary_expression.op == "<" {
                    left  := emit_expression(generator, binary_expression.left);
                    right := emit_expression(generator, binary_expression.right);
                }
            }

            condition_register := emit_expression(generator, while_statement.condition);

            jump_if_false_instruction := Instruction.{
                op_code = .JUMP_IF_FALSE,
                arg1    = condition_register,
            };

            jump_if_false_index = generator.current_function.instructions.count;

            array_add(*generator.current_function.instructions, jump_if_false_instruction);

            emit_statement(generator, while_statement.body);

            jump_back_instruction := Instruction.{
                op_code = .JUMP,
                imm     = cast(s32) loop_start_index,
            };

            array_add(*generator.current_function.instructions, jump_back_instruction);

            end_pc := generator.current_function.instructions.count;

            generator.current_function.instructions[jump_if_false_index].imm = cast(s32) end_pc;

            loop_context_finished := *generator.loop_stack[generator.loop_stack.count - 1];

            for loop_context_finished.break_jumps generator.current_function.instructions[it].imm = cast(s32) end_pc;

            array_reset(*loop_context_finished.break_jumps);
            array_reset(*loop_context_finished.continue_jumps);

            generator.loop_stack.count -= 1;

        case .FOR_STATEMENT;
            for_statement := cast(*Ast_For_Statement) node;

            if for_statement.init emit_statement(generator, for_statement.init);

            loop_start_index := generator.current_function.instructions.count;

            jump_if_false_index := -1;

            if for_statement.condition && for_statement.condition.kind == .BINARY_EXPRESSION {
                binary_expression := cast(*Ast_Binary_Expression) for_statement.condition;

                if binary_expression.op == "<" && binary_expression.left.kind == .IDENTIFIER && binary_expression.right.kind == .LITERAL_NUMBER {
                    identifier := cast(*Ast_Identifier) binary_expression.left;

                    local_index := -1;

                    for generator.locals {
                        if it == identifier.name {
                            local_index = it_index;
                            break;
                        }
                    }

                    if local_index != -1 {
                        literal_number := cast(*Ast_Literal_Number) binary_expression.right;

                        const_index := -1;

                        for generator.program.constants {
                            if it.type == .NUMBER && it.number == literal_number.value {
                                const_index = it_index;
                                break;
                            }
                        }

                        if const_index == -1 {
                            const_index = generator.program.constants.count;
                            array_add(*generator.program.constants, .{ type = .NUMBER, number = literal_number.value });
                        }

                        if const_index <= 255 {
                            jump_to_body_instruction := Instruction.{
                                op_code = .JUMP_IF_LOCAL_LESS_THAN_CONST,
                                dest    = cast(u8) local_index,
                                arg1    = cast(u8) const_index,
                            };

                            jump_to_body_index := generator.current_function.instructions.count;

                            array_add(*generator.current_function.instructions, jump_to_body_instruction);

                            jump_to_end_instruction := Instruction.{
                                op_code = .JUMP,
                            };

                            jump_to_end_index := generator.current_function.instructions.count;

                            array_add(*generator.current_function.instructions, jump_to_end_instruction);

                            jump_if_false_index = jump_to_end_index;

                            generator.current_function.instructions[jump_to_body_index].imm = cast(s32) generator.current_function.instructions.count;
                        }
                    }
                }
            }

            if jump_if_false_index == -1 && for_statement.condition {
                if for_statement.condition.kind == .BINARY_EXPRESSION {
                    binary_expression := cast(*Ast_Binary_Expression) for_statement.condition;

                    if binary_expression.op == "<" && binary_expression.left.kind == .IDENTIFIER && binary_expression.right.kind == .IDENTIFIER {
                        left_register  := emit_expression(generator, binary_expression.left);
                        right_register := emit_expression(generator, binary_expression.right);

                        jump_to_body_instruction := Instruction.{
                            op_code = .JUMP_IF_LESS_THAN,
                            arg1    = left_register,
                            arg2    = right_register,
                        };

                        jump_to_body_index := generator.current_function.instructions.count;

                        array_add(*generator.current_function.instructions, jump_to_body_instruction);

                        jump_to_end_instruction := Instruction.{
                            op_code = .JUMP,
                        };

                        jump_to_end_index := generator.current_function.instructions.count;

                        array_add(*generator.current_function.instructions, jump_to_end_instruction);

                        jump_if_false_index = jump_to_end_index;

                        generator.current_function.instructions[jump_to_body_index].imm = cast(s32) generator.current_function.instructions.count;
                    } else {
                        condition_register := emit_expression(generator, for_statement.condition);

                        jump_if_false_instruction := Instruction.{
                            op_code = .JUMP_IF_FALSE,
                            arg1    = condition_register,
                        };

                        jump_if_false_index = generator.current_function.instructions.count;

                        array_add(*generator.current_function.instructions, jump_if_false_instruction);
                    }
                } else {
                    condition_register := emit_expression(generator, for_statement.condition);

                    jump_if_false_instruction := Instruction.{
                        op_code = .JUMP_IF_FALSE,
                        arg1    = condition_register,
                    };

                    jump_if_false_index = generator.current_function.instructions.count;

                    array_add(*generator.current_function.instructions, jump_if_false_instruction);
                }
            }

            loop_context := Loop_Context.{
                continue_jumps.allocator = temp,
                break_jumps.allocator    = temp,
            };

            array_add(*generator.loop_stack, loop_context);

            emit_statement(generator, for_statement.body);

            continue_target := generator.current_function.instructions.count;

            if for_statement.update emit_expression(generator, for_statement.update);

            jump_back_instruction := Instruction.{
                op_code = .JUMP,
                imm     = cast(s32) loop_start_index,
            };

            array_add(*generator.current_function.instructions, jump_back_instruction);

            end_pc := generator.current_function.instructions.count;

            if jump_if_false_index != -1 generator.current_function.instructions[jump_if_false_index].imm = cast(s32) end_pc;

            loop_context_finished := generator.loop_stack[generator.loop_stack.count - 1];

            generator.loop_stack.count -= 1;

            for loop_context_finished.break_jumps    generator.current_function.instructions[it].imm = cast(s32) end_pc;
            for loop_context_finished.continue_jumps generator.current_function.instructions[it].imm = cast(s32) continue_target;

            array_reset(*loop_context_finished.break_jumps);
            array_reset(*loop_context_finished.continue_jumps);

        case .FOR_OF_STATEMENT;
            for_of_statement := cast(*Ast_For_Of_Statement) node;

            iterable_register := emit_expression(generator, for_of_statement.right);

            value_register := generator.next_register;

            generator.next_register += 1;

            loop_start_pc := generator.current_function.instructions.count;

            loop_context := Loop_Context.{
                continue_jumps.allocator = temp,
                break_jumps.allocator    = temp,
                continue_target          = loop_start_pc,
            };

            array_add(*generator.loop_stack, loop_context);

            next_instruction := Instruction.{
                op_code = .ITERATOR_NEXT,
                dest    = value_register,
                arg1    = iterable_register,
            };

            next_instruction_index := generator.current_function.instructions.count;

            array_add(*generator.current_function.instructions, next_instruction);

            if for_of_statement.left.kind == .VARIABLE_DECLARATION {
                variable_declaration := cast(*Ast_Variable_Declaration) for_of_statement.left;
                if variable_declaration.declarations.count > 0 emit_store(generator, variable_declaration.declarations[0].identifier, value_register);
            } else {
                emit_store(generator, for_of_statement.left, value_register);
            }

            emit_statement(generator, for_of_statement.body);

            jump_back_instruction := Instruction.{
                op_code = .JUMP,
                imm     = cast(s32) loop_start_pc,
            };

            array_add(*generator.current_function.instructions, jump_back_instruction);

            end_pc := generator.current_function.instructions.count;

            generator.current_function.instructions[next_instruction_index].imm = cast(s32) end_pc;

            loop_context_finished := generator.loop_stack[generator.loop_stack.count - 1];

            generator.loop_stack.count -= 1;

            for loop_context_finished.break_jumps    generator.current_function.instructions[it].imm = cast(s32) end_pc;
            for loop_context_finished.continue_jumps generator.current_function.instructions[it].imm = cast(s32) loop_start_pc;

            array_reset(*loop_context_finished.break_jumps);
            array_reset(*loop_context_finished.continue_jumps);

            close_instruction := Instruction.{
                op_code = .ITERATOR_CLOSE,
                arg1    = iterable_register,
            };

            array_add(*generator.current_function.instructions, close_instruction);

        case .THROW_STATEMENT;
            throw_statement := cast(*Ast_Throw_Statement) node;

            argument_register := emit_expression(generator, throw_statement.argument);

            instruction := Instruction.{
                op_code = .THROW,
                arg1    = argument_register,
            };

            emit_instruction(generator, instruction);

        case .IMPORT_STATEMENT;
            import_statement := cast(*Ast_Import_Statement) node;

            source_index := generator.program.constants.count;

            array_add(*generator.program.constants, .{ type = .STRING, s = import_statement.source.value });

            module_register := generator.next_register;

            generator.next_register += 1;

            instruction := Instruction.{
                op_code = .IMPORT,
                dest    = module_register,
                imm     = cast(s32) source_index,
            };

            if generator.current_function        array_add(*generator.current_function.instructions, instruction);
            if import_statement.namespace_import store_local_or_global(generator, import_statement.namespace_import.name, module_register);

            if import_statement.default_import {
                property_index := get_property_index(generator, "default");

                default_register := generator.next_register;

                generator.next_register += 1;

                get_field_instruction := Instruction.{
                    op_code = .GET_FIELD,
                    dest    = default_register,
                    arg1    = module_register,
                    imm     = cast(s32) property_index,
                };

                emit_instruction(generator, get_field_instruction);

                store_local_or_global(generator, import_statement.default_import.name, default_register);
            }

            for import_statement.specifiers {
                property_index := get_property_index(generator, it.imported.name);

                value_register := generator.next_register;

                generator.next_register += 1;

                get_field_instruction := Instruction.{
                    op_code = .GET_FIELD,
                    dest    = value_register,
                    arg1    = module_register,
                    imm     = cast(s32) property_index,
                };

                emit_instruction(generator, get_field_instruction);

                store_local_or_global(generator, it.local.name, value_register);
            }

        case .EXPORT_STATEMENT;
            export_statement := cast(*Ast_Export_Statement) node;

            if export_statement.is_default {
                value_register := emit_expression(generator, export_statement.declaration);

                export_instruction := Instruction.{
                    op_code = .EXPORT,
                    arg1    = value_register,
                    imm     = -1,
                };

                emit_instruction(generator, export_instruction);
            } else if export_statement.source {
                source_index := generator.program.constants.count;

                array_add(*generator.program.constants, .{ type = .STRING, s = export_statement.source.value });

                module_register := generator.next_register;

                generator.next_register += 1;

                import_instruction := Instruction.{
                    op_code = .IMPORT,
                    dest    = module_register,
                    imm     = cast(s32) source_index,
                };

                emit_instruction(generator, import_instruction);

                if export_statement.specifiers.count == 0 {
                    export_instruction := Instruction.{
                        op_code = .EXPORT,
                        arg1    = module_register,
                        imm     = -2,
                    };

                    emit_instruction(generator, export_instruction);
                } else {
                    for export_statement.specifiers {
                        property_index := get_property_index(generator, it.local.name);

                        value_register := generator.next_register;

                        generator.next_register += 1;

                        get_field_instruction := Instruction.{
                            op_code = .GET_FIELD,
                            dest    = value_register,
                            arg1    = module_register,
                            imm     = cast(s32) property_index,
                        };

                        emit_instruction(generator, get_field_instruction);

                        exported_index := get_property_index(generator, it.exported.name);

                        export_instruction := Instruction.{
                            op_code = .EXPORT,
                            arg1    = value_register,
                            imm     = cast(s32) exported_index,
                        };

                        emit_instruction(generator, export_instruction);
                    }
                }
            } else if export_statement.specifiers.count > 0 {
                for export_statement.specifiers {
                    value_register := emit_expression(generator, xx it.local);

                    exported_index := get_property_index(generator, it.exported.name);

                    export_instruction := Instruction.{
                        op_code = .EXPORT,
                        arg1    = value_register,
                        imm     = cast(s32) exported_index,
                    };

                    emit_instruction(generator, export_instruction);
                }
            } else {
                emit_statement(generator, export_statement.declaration);

                if export_statement.declaration.kind == .VARIABLE_DECLARATION {
                    variable_declaration := cast(*Ast_Variable_Declaration) export_statement.declaration;

                    for variable_declaration.declarations {
                        if it.identifier.kind == .IDENTIFIER {
                            identifier_register := emit_expression(generator, it.identifier);

                            prop_index := get_property_index(generator, (cast(*Ast_Identifier) it.identifier).name);

                            export_instruction := Instruction.{
                                op_code = .EXPORT,
                                arg1    = identifier_register,
                                imm     = cast(s32) prop_index,
                            };

                            emit_instruction(generator, export_instruction);
                        }
                    }
                } else if export_statement.declaration.kind == .FUNCTION_DECLARATION {
                    function_declaration := cast(*Ast_Function_Declaration) export_statement.declaration;

                    identifier_register := emit_expression(generator, xx function_declaration.identifier);

                    prop_index := get_property_index(generator, function_declaration.identifier.name);

                    export_instruction := Instruction.{
                        op_code = .EXPORT,
                        arg1    = identifier_register,
                        imm     = cast(s32) prop_index,
                    };

                    emit_instruction(generator, export_instruction);
                }
            }

        case .UNARY_EXPRESSION;
            emit_expression(generator, node);

        case .YIELD_EXPRESSION;
            emit_expression(generator, node);

        case .AWAIT_EXPRESSION;
            emit_expression(generator, node);

        case .UPDATE_EXPRESSION;
            emit_expression(generator, node);

        case .LOGICAL_EXPRESSION;
            emit_expression(generator, node);

        case .TRY_STATEMENT;
            try_statement := cast(*Ast_Try_Statement) node;

            catch_pc := -1;
            catch_register: u8 = 255;

            if try_statement.catch_block {
                try_context_index := generator.current_function.instructions.count;

                try_context_instruction := Instruction.{
                    op_code = .TRY_CONTEXT,
                };

                array_add(*generator.current_function.instructions, try_context_instruction);

                if try_statement.catch_parameter {
                    catch_register = generator.next_register;

                    generator.next_register += 1;

                    array_add(*generator.locals, try_statement.catch_parameter.name);

                    if generator.locals.count > generator.current_function.locals_count generator.current_function.locals_count = generator.locals.count;
                }

                emit_statement(generator, cast(*Ast_Node) try_statement.try_block);

                pop_instruction := Instruction.{
                    op_code = .POP_TRY_CONTEXT,
                };

                array_add(*generator.current_function.instructions, pop_instruction);

                jump_over_catch_instruction := Instruction.{ op_code = .JUMP };

                jump_over_catch_index := generator.current_function.instructions.count;

                array_add(*generator.current_function.instructions, jump_over_catch_instruction);

                catch_pc = generator.current_function.instructions.count;

                generator.current_function.instructions[try_context_index].imm = cast(s32) catch_pc;
                generator.current_function.instructions[try_context_index].arg1 = catch_register;

                if try_statement.catch_parameter store_local_or_global(generator, try_statement.catch_parameter.name, catch_register);

                emit_statement(generator, cast(*Ast_Node) try_statement.catch_block);

                generator.current_function.instructions[jump_over_catch_index].imm = cast(s32) generator.current_function.instructions.count;
            } else {
                emit_statement(generator, cast(*Ast_Node) try_statement.try_block);
            }

            if try_statement.finally_block {
                emit_statement(generator, cast(*Ast_Node) try_statement.finally_block);
            }

        case .SWITCH_STATEMENT;
            switch_statement := cast(*Ast_Switch_Statement) node;

            discriminant_register := emit_expression(generator, switch_statement.discriminant);

            loop_context := Loop_Context.{
                is_switch                = true,
                continue_jumps.allocator = temp,
                break_jumps.allocator    = temp,
            };

            array_add(*generator.loop_stack, loop_context);

            case_test_jumps: [..] int;
            case_test_jumps.allocator = temp;

            for switch_statement.cases {
                if it.test {
                    test_register := emit_expression(generator, it.test);

                    eq_register := generator.next_register;

                    generator.next_register += 1;

                    equal_instruction := Instruction.{
                        op_code = .STRICT_EQUAL,
                        dest    = eq_register,
                        arg1    = discriminant_register,
                        arg2    = test_register,
                    };

                    array_add(*generator.current_function.instructions, equal_instruction);

                    jump_instruction := Instruction.{
                        op_code = .JUMP_IF_TRUE,
                        arg1    = eq_register,
                    };

                    array_add(*generator.current_function.instructions, jump_instruction);
                    array_add(*case_test_jumps, generator.current_function.instructions.count - 1);
                }
            }

            jump_to_default_or_end_index := generator.current_function.instructions.count;

            jump_instruction := Instruction.{
                op_code = .JUMP,
            };

            array_add(*generator.current_function.instructions, jump_instruction);

            case_pcs: [..] int;
            case_pcs.allocator = temp;

            default_pc := -1;

            for switch_statement.cases {
                current_pc := generator.current_function.instructions.count;

                array_add(*case_pcs, current_pc);

                if !it.test default_pc = current_pc;

                for it.consequent emit_statement(generator, it);
            }

            end_pc := generator.current_function.instructions.count;

            case_index := 0;
            for switch_statement.cases {
                if it.test {
                    generator.current_function.instructions[case_test_jumps[case_index]].imm = cast(s32) case_pcs[it_index];
                    case_index += 1;
                }
            }

            if default_pc != -1 generator.current_function.instructions[jump_to_default_or_end_index].imm = cast(s32) default_pc;
            else                generator.current_function.instructions[jump_to_default_or_end_index].imm = cast(s32) end_pc;

            loop_context_finished := *generator.loop_stack[generator.loop_stack.count - 1];

            for loop_context_finished.break_jumps generator.current_function.instructions[it].imm = cast(s32) end_pc;

            array_reset(*loop_context_finished.break_jumps);
            array_reset(*loop_context_finished.continue_jumps);

            generator.loop_stack.count -= 1;

        case .BREAK_STATEMENT;
            if generator.loop_stack.count == 0 {
                generator.has_error = true;
                generator.error_message = "Error: break statement outside of loop or switch\n";

                return;
            }

            instruction := Instruction.{
                op_code = .JUMP,
            };

            pc := generator.current_function.instructions.count;

            array_add(*generator.current_function.instructions, instruction);
            array_add(*generator.loop_stack[generator.loop_stack.count - 1].break_jumps, pc);

        case .CONTINUE_STATEMENT;
            found_loop := false;

            i := generator.loop_stack.count - 1;
            while i >= 0 {
                if !generator.loop_stack[i].is_switch {
                    loop_context := *generator.loop_stack[i];

                    instruction := Instruction.{
                        op_code = .JUMP,
                    };

                    if loop_context.continue_target != -1 {
                        instruction.imm = cast(s32) loop_context.continue_target;
                    } else {
                        pc := generator.current_function.instructions.count;
                        array_add(*loop_context.continue_jumps, pc);
                    }

                    array_add(*generator.current_function.instructions, instruction);

                    found_loop = true;

                    break;
                }

                i -= 1;
            }

            if !found_loop {
                generator.has_error = true;
                generator.error_message = "Error: continue statement outside of loop\n";

                return;
            }

        case .PROGRAM;
        case .CASE_CLAUSE;
        case .MEMBER_EXPRESSION;
        case .BINARY_EXPRESSION;
        case .LITERAL_NUMBER;
        case .LITERAL_STRING;
        case .IDENTIFIER;
        case .OBJECT_LITERAL;
        case .CALL_EXPRESSION;
        case .NEW_EXPRESSION;
        case .ASSIGNMENT_EXPRESSION;
        case .ARRAY_LITERAL;
        case .FUNCTION_EXPRESSION;
        case .ARROW_FUNCTION_EXPRESSION;
        case .THIS_EXPRESSION;
        case .CONDITIONAL_EXPRESSION;
        case .TEMPLATE_LITERAL;
        case .SPREAD_ELEMENT;
        case .CLASS_EXPRESSION;
        case .METHOD_DEFINITION;
        case .SUPER_EXPRESSION;
            emit_expression(generator, node);

        case .CLASS_DECLARATION;
            emit_class_declaration(generator, cast(*Ast_Class_Declaration) node);
        case .CLASS_BODY;
    }
}

emit_expression :: (generator: *Bytecode_Generator, node: *Ast_Node, force_new_register := false, destination_register: s16 = -1) -> u8 {
    if !node return 0;

    if #complete node.kind == {
        case .LITERAL_NUMBER;
            literal_number := cast(*Ast_Literal_Number) node;
            index          := generator.program.constants.count;

            array_add(*generator.program.constants, .{ type = .NUMBER, number = literal_number.value });

            register: u8;

            if destination_register != -1 {
                register = cast(u8) destination_register;
            } else {
                register = generator.next_register;
                generator.next_register += 1;
            }

            instruction := Instruction.{
                op_code = .LOAD_CONST,
                dest    = register,
                imm     = cast(s32) index,
            };

            emit_instruction(generator, instruction);

            return register;

        case .LITERAL_STRING;
            literal_string := cast(*Ast_Literal_String) node;
            index          := generator.program.constants.count;

            array_add(*generator.program.constants, .{ type = .STRING, s = literal_string.value });

            register: u8;

            if destination_register != -1 {
                register = cast(u8) destination_register;
            } else {
                register = generator.next_register;
                generator.next_register += 1;
            }

            instruction := Instruction.{
                op_code = .LOAD_CONST,
                dest    = register,
                imm     = cast(s32) index,
            };

            emit_instruction(generator, instruction);

            return register;

        case .IDENTIFIER;
            identifier := cast(*Ast_Identifier) node;

            location := resolve_variable(generator, identifier.name);

            if location.type == .LOCAL && !force_new_register && destination_register == -1 return cast(u8) location.index;

            register: u8;

            if destination_register != -1 {
                register = cast(u8) destination_register;
            } else {
                register = generator.next_register;
                generator.next_register += 1;
            }

            instruction := Instruction.{
                dest = register,
            };

            if location.type == {
                case .LOCAL;
                    instruction.op_code = .LOAD_LOCAL;
                    instruction.imm = cast(s32) location.index;
                case .UPVALUE;
                    instruction.op_code = .LOAD_UPVALUE;
                    instruction.imm = (cast(s32) location.level << 16) | cast(s32) location.index;
                case .GLOBAL;
                    instruction.op_code = .LOAD_GLOBAL;
                    instruction.imm = cast(s32) location.index;
                case .NOT_FOUND;
                    array_add(*generator.program.globals, identifier.name);
                    instruction.op_code = .LOAD_GLOBAL;
                    instruction.imm = cast(s32) (generator.program.globals.count - 1);
            }

            emit_instruction(generator, instruction);

            return register;

        case .THIS_EXPRESSION;
            register: u8;
            if destination_register != -1 {
                register = cast(u8) destination_register;
            } else {
                register = generator.next_register;
                generator.next_register += 1;
            }

            instruction := Instruction.{
                op_code = .LOAD_THIS,
                dest    = register,
            };

            emit_instruction(generator, instruction);

            return register;

        case .BINARY_EXPRESSION;
            binary_expression := cast(*Ast_Binary_Expression) node;

            if binary_expression.op == "&&" || binary_expression.op == "||" {
                logical_expression := New(Ast_Logical_Expression);

                logical_expression.kind  = .LOGICAL_EXPRESSION;
                logical_expression.left  = binary_expression.left;
                logical_expression.right = binary_expression.right;
                logical_expression.op    = binary_expression.op;

                return emit_expression(generator, xx logical_expression, force_new_register, destination_register);
            }

            left := emit_expression(generator, binary_expression.left);

            right: u8;

            register: u8;
            if destination_register != -1 {
                register = cast(u8) destination_register;
            } else {
                register = generator.next_register;
                generator.next_register += 1;
            }

            instruction := Instruction.{
                dest = register,
                arg1 = left,
            };

            if (binary_expression.op == "-" || binary_expression.op == "+") && binary_expression.right.kind == .LITERAL_NUMBER {
                literal_number := cast(*Ast_Literal_Number) binary_expression.right;

                const_index := -1;

                for generator.program.constants {
                    if it.type == .NUMBER && it.number == literal_number.value {
                        const_index = it_index;
                        break;
                    }
                }

                if const_index == -1 {
                    const_index = generator.program.constants.count;
                    array_add(*generator.program.constants, .{type=.NUMBER, number=literal_number.value});
                }

                if binary_expression.op == "-" instruction.op_code = .SUB_CONST;
                else                           instruction.op_code = .ADD_CONST;

                instruction.imm = cast(s32) const_index;
            } else {
                right = emit_expression(generator, binary_expression.right);

                instruction.arg2 = right;

                if      binary_expression.op == "+"          instruction.op_code = .ADD;
                else if binary_expression.op == "-"          instruction.op_code = .SUB;
                else if binary_expression.op == "*"          instruction.op_code = .MUL;
                else if binary_expression.op == "/"          instruction.op_code = .DIV;
                else if binary_expression.op == "%"          instruction.op_code = .MOD;
                else if binary_expression.op == "=="         instruction.op_code = .EQUAL;
                else if binary_expression.op == "!="         instruction.op_code = .NOT_EQUAL;
                else if binary_expression.op == "<"          instruction.op_code = .LESS_THAN;
                else if binary_expression.op == ">"          instruction.op_code = .GREATER_THAN;
                else if binary_expression.op == "<="         instruction.op_code = .LESS_THAN_EQUAL;
                else if binary_expression.op == ">="         instruction.op_code = .GREATER_THAN_EQUAL;
                else if binary_expression.op == "==="        instruction.op_code = .STRICT_EQUAL;
                else if binary_expression.op == "!=="        instruction.op_code = .STRICT_NOT_EQUAL;
                else if binary_expression.op == "instanceof" instruction.op_code = .INSTANCEOF;
                else if binary_expression.op == "in"         instruction.op_code = .IN;
                else if binary_expression.op == "&"          instruction.op_code = .BITWISE_AND;
                else if binary_expression.op == "|"          instruction.op_code = .BITWISE_OR;
                else if binary_expression.op == "^"          instruction.op_code = .BITWISE_XOR;
                else if binary_expression.op == "**"         instruction.op_code = .EXPONENTIATION;
            }

            emit_instruction(generator, instruction);

            return register;

        case .ARRAY_LITERAL;
            array_literal := cast(*Ast_Array_Literal) node;

            register: u8;

            if destination_register != -1 {
                register = cast(u8) destination_register;
            } else {
                register = generator.next_register;
                generator.next_register += 1;
            }

            instruction := Instruction.{
                op_code = .NEW_ARRAY,
                dest    = register,
                imm     = 0,
            };

            emit_instruction(generator, instruction);

            for array_literal.elements {
                if !it continue;

                if it.kind == .SPREAD_ELEMENT {
                    spread_element  := cast(*Ast_Spread_Element) it;
                    spread_register := emit_expression(generator, spread_element.argument);

                    spread_instruction := Instruction.{
                        op_code = .ARRAY_APPEND,
                        arg1    = register,
                        arg2    = spread_register,
                    };

                    emit_instruction(generator, spread_instruction);
                } else {
                    elements_register := emit_expression(generator, it);

                    push_instruction := Instruction.{
                        op_code = .ARRAY_PUSH,
                        arg1    = register,
                        arg2    = elements_register,
                    };

                    emit_instruction(generator, push_instruction);
                }
            }

            return register;

        case .OBJECT_LITERAL;
            object_literal := cast(*Ast_Object_Literal) node;

            register: u8;

            if destination_register != -1 {
                register = cast(u8) destination_register;
            } else {
                register = generator.next_register;
                generator.next_register += 1;
            }

            instruction := Instruction.{
                op_code = .NEW_OBJECT,
                dest    = register,
            };

            emit_instruction(generator, instruction);

            for object_literal.properties {
                if it.is_spread {
                    spread_element  := cast(*Ast_Spread_Element) it.value;
                    spread_register := emit_expression(generator, spread_element.argument);

                    spread_instruction := Instruction.{
                        op_code = .OBJECT_SPREAD,
                        dest    = register,
                        arg1    = spread_register,
                    };

                    emit_instruction(generator, spread_instruction);
                } else {
                    value_register := emit_expression(generator, it.value);
                    index          := get_property_index(generator, it.key);

                    set_instruction := Instruction.{
                        op_code = .SET_FIELD,
                        dest    = register,
                        arg1    = value_register,
                        imm     = cast(s32) index,
                    };

                    emit_instruction(generator, set_instruction);
                }
            }

            return register;

        case .MEMBER_EXPRESSION;
            member_expression := cast(*Ast_Member_Expression) node;

            object_register := emit_expression(generator, member_expression.object);

            register: u8;

            if destination_register != -1 {
                register = cast(u8) destination_register;
            } else {
                register = generator.next_register;
                generator.next_register += 1;
            }

            if member_expression.computed {
                property_register := emit_expression(generator, member_expression.property);

                instruction := Instruction.{
                    op_code = .ARRAY_GET,
                    dest    = register,
                    arg1    = object_register,
                    arg2    = property_register,
                };

                emit_instruction(generator, instruction);
            } else {
                identifier := cast(*Ast_Identifier) member_expression.property;
                index      := get_property_index(generator, identifier.name);

                instruction := Instruction.{
                    op_code = .GET_FIELD,
                    dest    = register,
                    arg1    = object_register,
                    imm     = cast(s32) index,
                };

                emit_instruction(generator, instruction);
            }

            return register;

        case .CALL_EXPRESSION;
            call_expression := cast(*Ast_Call_Expression) node;

            has_spread := false;
            for call_expression.arguments {
                if it && it.kind == .SPREAD_ELEMENT {
                    has_spread = true;
                    break;
                }
            }

            this_register:   u8 = 255;
            callee_register: u8;

            if call_expression.callee.kind == .MEMBER_EXPRESSION {
                member_expression := cast(*Ast_Member_Expression) call_expression.callee;

                this_register = emit_expression(generator, member_expression.object);

                callee_register = generator.next_register;

                generator.next_register += 1;

                if member_expression.computed {
                    propery_register := emit_expression(generator, member_expression.property);

                    instruction := Instruction.{
                        op_code = .ARRAY_GET,
                        dest    = callee_register,
                        arg1    = this_register,
                        arg2    = propery_register,
                    };

                    emit_instruction(generator, instruction);
                } else {
                    identifier := cast(*Ast_Identifier) member_expression.property;
                    index      := get_property_index(generator, identifier.name);

                    instruction := Instruction.{
                        op_code = .GET_FIELD,
                        dest    = callee_register,
                        arg1    = this_register,
                        imm     = cast(s32) index,
                    };

                    emit_instruction(generator, instruction);
                }
            } else {
                callee_register = emit_expression(generator, call_expression.callee);
            }

            register: u8;

            if destination_register != -1 {
                register = cast(u8) destination_register;
            } else {
                register = generator.next_register;
                generator.next_register += 1;
            }

            if has_spread {
                args_array_register := generator.next_register;

                generator.next_register += 1;

                new_array_instruction := Instruction.{
                    op_code = .NEW_ARRAY,
                    dest    = args_array_register,
                    imm     = 0,
                };

                emit_instruction(generator, new_array_instruction);

                for call_expression.arguments {
                    if !it continue;

                    if it.kind == .SPREAD_ELEMENT {
                        spread_element  := cast(*Ast_Spread_Element) it;
                        spread_register := emit_expression(generator, spread_element.argument);

                        append_instruction := Instruction.{
                            op_code = .ARRAY_APPEND,
                            arg1    = args_array_register,
                            arg2    = spread_register,
                        };

                        emit_instruction(generator, append_instruction);
                    } else {
                        argument_register := emit_expression(generator, it);

                        push_instruction := Instruction.{
                            op_code = .ARRAY_PUSH,
                            arg1    = args_array_register,
                            arg2    = argument_register,
                        };

                        emit_instruction(generator, push_instruction);
                    }
                }

                call_instruction := Instruction.{
                    op_code = .CALL_APPLY,
                    dest    = register,
                    arg1    = callee_register,
                    arg2    = this_register,
                    imm     = cast(s32) args_array_register,
                };

                emit_instruction(generator, call_instruction);
            } else {
                first_argument := generator.next_register;

                generator.next_register += cast(u8) call_expression.arguments.count;

                for call_expression.arguments emit_expression(generator, it, false, cast(s16) (first_argument + it_index));

                instruction := Instruction.{
                    op_code = .CALL,
                    dest    = register,
                    arg1    = callee_register,
                    arg2    = this_register,
                    imm     = ((cast(s32) first_argument) << 16) | cast(s32) call_expression.arguments.count,
                };

                emit_instruction(generator, instruction);
            }

            return register;

        case .NEW_EXPRESSION;
            new_expression := cast(*Ast_New_Expression) node;

            has_spread := false;
            for new_expression.arguments {
                if it && it.kind == .SPREAD_ELEMENT {
                    has_spread = true;
                    break;
                }
            }

            callee_register := emit_expression(generator, new_expression.callee);

            register: u8;

            if destination_register != -1 {
                register = cast(u8) destination_register;
            } else {
                register = generator.next_register;
                generator.next_register += 1;
            }

            if has_spread {
                arguments_array_register := generator.next_register;

                generator.next_register += 1;

                new_array_instruction := Instruction.{
                    op_code = .NEW_ARRAY,
                    dest    = arguments_array_register,
                    imm     = 0,
                };

                emit_instruction(generator, new_array_instruction);

                for new_expression.arguments {
                    if !it continue;

                    if it.kind == .SPREAD_ELEMENT {
                        spread_element  := cast(*Ast_Spread_Element) it;
                        spread_register := emit_expression(generator, spread_element.argument);

                        append_instruction := Instruction.{
                            op_code = .ARRAY_APPEND,
                            arg1    = arguments_array_register,
                            arg2    = spread_register,
                        };

                        emit_instruction(generator, append_instruction);
                    } else {
                        argument_register := emit_expression(generator, it);

                        push_instruction := Instruction.{
                            op_code = .ARRAY_PUSH,
                            arg1    = arguments_array_register,
                            arg2    = argument_register,
                        };

                        emit_instruction(generator, push_instruction);
                    }
                }

                call_instruction := Instruction.{
                    op_code = .NEW_CALL_APPLY,
                    dest    = register,
                    arg1    = callee_register,
                    arg2    = arguments_array_register,
                };

                emit_instruction(generator, call_instruction);
            } else {
                first_argument_new := generator.next_register;

                generator.next_register += cast(u8) new_expression.arguments.count;

                for new_expression.arguments emit_expression(generator, it, false, cast(s16) (first_argument_new + it_index));

                instruction := Instruction.{
                    op_code = .NEW_CALL,
                    dest    = register,
                    arg1    = callee_register,
                    arg2    = 255,
                    imm     = ((cast(s32) first_argument_new) << 16) | cast(s32) new_expression.arguments.count,
                };

                emit_instruction(generator, instruction);
            }

            return register;

        case .FUNCTION_EXPRESSION;
            function_expression := cast(*Ast_Function_Expression) node;

            nested_generator := Bytecode_Generator.{
                program              = generator.program,
                parent               = generator,
                next_register        = cast(u8) function_expression.parameters.count,
                locals.allocator     = temp,
                loop_stack.allocator = temp,
            };

            bytecode_function := New(Bytecode_Function);

            bytecode_function.name            = copy_string("anonymous");
            bytecode_function.arguments_count = function_expression.parameters.count;
            if function_expression.is_generator bytecode_function.flags |= .GENERATOR;
            if function_expression.is_async bytecode_function.flags |= .ASYNC;

            for function_expression.parameters {
                if it.kind == .SPREAD_ELEMENT {
                    spread_element := cast(*Ast_Spread_Element) it;
                    identifier     := cast(*Ast_Identifier) spread_element.argument;

                    array_add(*nested_generator.locals, identifier.name);

                    bytecode_function.flags |= .REST_PARAMETER;
                } else {
                    identifier := cast(*Ast_Identifier) it;
                    array_add(*nested_generator.locals, identifier.name);
                }
            }

            nested_generator.current_function = bytecode_function;

            for function_expression.body.body emit_statement(*nested_generator, it);

            bytecode_function.locals_count = nested_generator.next_register;

            for nested_generator.locals array_add(*bytecode_function.locals, it);

            array_add(*generator.program.functions, bytecode_function);

            function_index := generator.program.functions.count - 1;

            register: u8;

            if destination_register != -1 {
                register = cast(u8) destination_register;
            } else {
                register = generator.next_register;
                generator.next_register += 1;
            }

            instruction := Instruction.{
                op_code = .LOAD_FUNC,
                dest    = register,
                imm     = cast(s32) function_index,
            };

            emit_instruction(generator, instruction);

            return register;

        case .ARROW_FUNCTION_EXPRESSION;
            arrow_expression := cast(*Ast_Arrow_Function_Expression) node;

            nested_generator := Bytecode_Generator.{
                program              = generator.program,
                parent               = generator,
                next_register        = cast(u8) arrow_expression.parameters.count,
                locals.allocator     = temp,
                loop_stack.allocator = temp,
            };

            bytecode_function := New(Bytecode_Function);

            bytecode_function.name            = copy_string("anonymous");
            bytecode_function.arguments_count = arrow_expression.parameters.count;
            bytecode_function.flags |= .ARROW;
            if arrow_expression.is_async bytecode_function.flags |= .ASYNC;

            for arrow_expression.parameters {
                if it.kind == .SPREAD_ELEMENT {
                    spread_element := cast(*Ast_Spread_Element) it;
                    identifier     := cast(*Ast_Identifier) spread_element.argument;

                    array_add(*nested_generator.locals, identifier.name);

                    bytecode_function.flags |= .REST_PARAMETER;
                } else {
                    identifier := cast(*Ast_Identifier) it;
                    array_add(*nested_generator.locals, identifier.name);
                }
            }

            nested_generator.current_function = bytecode_function;

            if arrow_expression.body.kind == .BLOCK_STATEMENT {
                block_statement := cast(*Ast_Block_Statement) arrow_expression.body;

                for block_statement.body emit_statement(*nested_generator, it);
            } else {
                register := emit_expression(*nested_generator, arrow_expression.body);

                instruction := Instruction.{
                    op_code = .RETURN,
                    arg1    = register,
                };

                array_add(*bytecode_function.instructions, instruction);
            }

            bytecode_function.locals_count = nested_generator.next_register;

            for nested_generator.locals array_add(*bytecode_function.locals, it);

            array_add(*generator.program.functions, bytecode_function);

            function_index := generator.program.functions.count - 1;

            register: u8;

            if destination_register != -1 {
                register = cast(u8) destination_register;
            } else {
                register = generator.next_register;
                generator.next_register += 1;
            }

            instruction := Instruction.{
                op_code = .LOAD_FUNC,
                dest    = register,
                imm     = cast(s32) function_index,
            };

            emit_instruction(generator, instruction);

            return register;

        case .TEMPLATE_LITERAL;
            template_literal := cast(*Ast_Template_Literal) node;

            result_register: u8;

            first := true;

            for template_literal.quasis {
                if it.count > 0 || (it_index == 0 && template_literal.expressions.count > 0) || (template_literal.quasis.count == 1 && template_literal.expressions.count == 0) {
                    quasi_index := generator.program.constants.count;

                    array_add(*generator.program.constants, .{ type = .STRING, s = it });

                    quasi_reg := generator.next_register;

                    generator.next_register += 1;

                    quasi_instruction := Instruction.{
                        op_code = .LOAD_CONST,
                        dest    = quasi_reg,
                        imm     = cast(s32) quasi_index,
                    };

                    emit_instruction(generator, quasi_instruction);

                    if first {
                        result_register = quasi_reg;
                        first           = false;
                    } else {
                        concat_register := generator.next_register;

                        generator.next_register += 1;

                        concat_instruction := Instruction.{
                            op_code = .ADD,
                            dest    = concat_register,
                            arg1    = result_register,
                            arg2    = quasi_reg,
                        };

                        emit_instruction(generator, concat_instruction);

                        result_register = concat_register;
                    }
                }

                if it_index < template_literal.expressions.count {
                    expression_register := emit_expression(generator, template_literal.expressions[it_index]);

                    if first {
                        result_register = expression_register;
                        first           = false;
                    } else {
                        concat_register := generator.next_register;

                        generator.next_register += 1;

                        concat_instruction := Instruction.{
                            op_code = .ADD,
                            dest    = concat_register,
                            arg1    = result_register,
                            arg2    = expression_register,
                        };

                        emit_instruction(generator, concat_instruction);

                        result_register = concat_register;
                    }
                }
            }

            if first {
                quasi_index := generator.program.constants.count;

                array_add(*generator.program.constants, .{ type = .STRING, s = "" });

                result_register = generator.next_register;

                generator.next_register += 1;

                quasi_instruction := Instruction.{
                    op_code = .LOAD_CONST,
                    dest    = result_register,
                    imm     = cast(s32) quasi_index,
                };

                emit_instruction(generator, quasi_instruction);
            }

            return result_register;

        case .SPREAD_ELEMENT;
            return 255;

        case .UNARY_EXPRESSION;
            unary_expression := cast(*Ast_Unary_Expression) node;

            right := emit_expression(generator, unary_expression.right);

            register: u8;

            if destination_register != -1 {
                register = cast(u8) destination_register;
            } else {
                register = generator.next_register;
                generator.next_register += 1;
            }

            instruction := Instruction.{
                dest = register,
                arg1 = right,
            };

            if unary_expression.op == "!" {
                instruction.op_code = .LOGICAL_NOT;
            } else if unary_expression.op == "typeof" {
                instruction.op_code = .TYPEOF;
            } else if unary_expression.op == "-" {
                instruction.op_code = .UNARY_MINUS;
            } else if unary_expression.op == "+" {
                instruction.op_code = .MOVE;
                instruction.arg1 = right;
            }

            emit_instruction(generator, instruction);

            return register;

        case .YIELD_EXPRESSION;
            yield_expression := cast(*Ast_Yield_Expression) node;

            argument_register: u8 = 0;
            if yield_expression.argument argument_register = emit_expression(generator, yield_expression.argument);

            register: u8;

            if destination_register != -1 {
                register = cast(u8) destination_register;
            } else {
                register = generator.next_register;
                generator.next_register += 1;
            }

            instruction := Instruction.{
                op_code = .YIELD,
                dest    = register,
                arg1    = argument_register,
            };

            emit_instruction(generator, instruction);

            return register;

        case .AWAIT_EXPRESSION;
            await_expression := cast(*Ast_Yield_Expression) node;

            argument_register := emit_expression(generator, await_expression.argument);

            register: u8;

            if destination_register != -1 {
                register = cast(u8) destination_register;
            } else {
                register = generator.next_register;
                generator.next_register += 1;
            }

            instruction := Instruction.{
                op_code = .AWAIT,
                dest    = register,
                arg1    = argument_register,
            };

            emit_instruction(generator, instruction);

            return register;

        case .ASSIGNMENT_EXPRESSION;
            assignment_expression := cast(*Ast_Assignment_Expression) node;

            if assignment_expression.op == "=" {
                value_register := emit_expression(generator, assignment_expression.right);

                emit_store(generator, assignment_expression.left, value_register);

                return value_register;
            } else if assignment_expression.op == "+=" && assignment_expression.right.kind == .LITERAL_NUMBER {
                literal_number := cast(*Ast_Literal_Number) assignment_expression.right;

                left_register := emit_expression(generator, assignment_expression.left);

                const_index := -1;

                for generator.program.constants {
                    if it.type == .NUMBER && it.number == literal_number.value {
                        const_index = it_index;
                        break;
                    }
                }

                if const_index == -1 {
                    const_index = generator.program.constants.count;
                    array_add(*generator.program.constants, .{type=.NUMBER, number = literal_number.value});
                }

                op_instruction := Instruction.{
                    op_code = .ADD_CONST,
                    dest    = left_register,
                    arg1    = left_register,
                    imm     = cast(s32) const_index,
                };

                array_add(*generator.current_function.instructions, op_instruction);

                emit_store(generator, assignment_expression.left, left_register);

                return left_register;
            } else if assignment_expression.op == "+=" && assignment_expression.left.kind == .IDENTIFIER && assignment_expression.right.kind == .IDENTIFIER {
                left_identifier  := cast(*Ast_Identifier) assignment_expression.left;
                right_identifier := cast(*Ast_Identifier) assignment_expression.right;

                left_index  := get_local_index(generator, left_identifier.name);
                right_index := get_local_index(generator, right_identifier.name);

                if left_index != -1 && right_index != -1 {
                    op_instruction := Instruction.{
                        op_code = .ADD_LOCAL_LOCAL,
                        dest    = cast(u8) left_index,
                        arg1    = cast(u8) right_index,
                    };

                    array_add(*generator.current_function.instructions, op_instruction);

                    return cast(u8) left_index;
                }

                left_register  := emit_expression(generator, assignment_expression.left);
                right_register := emit_expression(generator, assignment_expression.right);

                result_register := generator.next_register;

                generator.next_register += 1;

                instruction := Instruction.{
                    dest    = result_register,
                    arg1    = left_register,
                    arg2    = right_register,
                    op_code = .ADD,
                };

                emit_instruction(generator, instruction);

                emit_store(generator, assignment_expression.left, result_register);

                return result_register;
            } else if assignment_expression.op == "-=" && assignment_expression.left.kind == .IDENTIFIER && assignment_expression.right.kind == .IDENTIFIER {
                left_identifier  := cast(*Ast_Identifier) assignment_expression.left;
                right_identifier := cast(*Ast_Identifier) assignment_expression.right;

                left_index  := get_local_index(generator, left_identifier.name);
                right_index := get_local_index(generator, right_identifier.name);

                if left_index != -1 && right_index != -1 {
                    op_instruction := Instruction.{
                        op_code = .SUB_LOCAL_LOCAL,
                        dest    = cast(u8) left_index,
                        arg1    = cast(u8) right_index,
                    };

                    array_add(*generator.current_function.instructions, op_instruction);

                    return cast(u8) left_index;
                }

                left_register  := emit_expression(generator, assignment_expression.left);
                right_register := emit_expression(generator, assignment_expression.right);

                result_register := generator.next_register;

                generator.next_register += 1;

                instruction := Instruction.{
                    dest    = result_register,
                    arg1    = left_register,
                    arg2    = right_register,
                    op_code = .SUB,
                };

                emit_instruction(generator, instruction);

                emit_store(generator, assignment_expression.left, result_register);

                return result_register;
            } else {
                left_register  := emit_expression(generator, assignment_expression.left);
                right_register := emit_expression(generator, assignment_expression.right);

                result_register := generator.next_register;

                generator.next_register += 1;

                instruction := Instruction.{
                    dest = result_register,
                    arg1 = left_register,
                    arg2 = right_register,
                };

                if      assignment_expression.op == "+=" instruction.op_code = .ADD;
                else if assignment_expression.op == "-=" instruction.op_code = .SUB;
                else if assignment_expression.op == "*=" instruction.op_code = .MUL;
                else if assignment_expression.op == "/=" instruction.op_code = .DIV;
                else if assignment_expression.op == "**=" instruction.op_code = .EXPONENTIATION;

                emit_instruction(generator, instruction);

                emit_store(generator, assignment_expression.left, result_register);

                return result_register;
            }

        case .PROGRAM;
        case .VARIABLE_DECLARATION;
        case .VARIABLE_DECLARATOR;
        case .EXPRESSION_STATEMENT;
        case .RETURN_STATEMENT;
        case .BLOCK_STATEMENT;
        case .THROW_STATEMENT;
        case .IF_STATEMENT;
        case .WHILE_STATEMENT;
        case .FOR_STATEMENT;
        case .FUNCTION_DECLARATION;
        case .IMPORT_STATEMENT;
        case .EXPORT_STATEMENT;
        case .TRY_STATEMENT;
        case .FOR_OF_STATEMENT;
        case .BREAK_STATEMENT;
        case .CONTINUE_STATEMENT;
        case .SWITCH_STATEMENT;
        case .CASE_CLAUSE;
            return 0;

        case .LOGICAL_EXPRESSION;
            logical_expression := cast(*Ast_Logical_Expression) node;

            register: u8;

            if destination_register != -1 {
                register = cast(u8) destination_register;
            } else {
                register = generator.next_register;
                generator.next_register += 1;
            }

            left_register := emit_expression(generator, logical_expression.left);

            move_instruction := Instruction.{
                op_code = .MOVE,
                dest    = register,
                arg1    = left_register,
            };

            array_add(*generator.current_function.instructions, move_instruction);

            jump_instruction: Instruction;

            if logical_expression.op == "||" {
                jump_instruction.op_code = .JUMP_IF_TRUE;
            } else if logical_expression.op == "&&" {
                jump_instruction.op_code = .JUMP_IF_FALSE;
            } else {
                jump_instruction.op_code = .JUMP_IF_NOT_NULLISH;
            }

            jump_instruction.arg1 = register;

            array_add(*generator.current_function.instructions, jump_instruction);

            jump_index := generator.current_function.instructions.count - 1;

            right_register := emit_expression(generator, logical_expression.right);

            move_instruction_2 := Instruction.{
                op_code = .MOVE,
                dest    = register,
                arg1    = right_register,
            };

            array_add(*generator.current_function.instructions, move_instruction_2);

            generator.current_function.instructions[jump_index].imm = cast(s32) generator.current_function.instructions.count;

            return register;

        case .UPDATE_EXPRESSION;
            update_expression := cast(*Ast_Update_Expression) node;

            if update_expression.argument.kind == .IDENTIFIER {
                identifier  := cast(*Ast_Identifier) update_expression.argument;
                local_index := get_local_index(generator, identifier.name);

                if local_index != -1 {
                    register: u8;
                    if destination_register != -1 {
                        register = cast(u8) destination_register;
                    } else {
                        register = generator.next_register;
                        generator.next_register += 1;
                    }

                    if !update_expression.prefix {
                        move_instruction := Instruction.{
                            op_code = .MOVE,
                            dest    = register,
                            arg1    = cast(u8) local_index,
                        };

                        array_add(*generator.current_function.instructions, move_instruction);

                        op_instruction := Instruction.{
                            op_code = ifx update_expression.op == "++" then .INC_LOCAL else .DEC_LOCAL,
                            imm     = cast(s32) local_index,
                        };

                        array_add(*generator.current_function.instructions, op_instruction);

                        return register;
                    } else {
                        op_instruction := Instruction.{
                            op_code = ifx update_expression.op == "++" then .INC_LOCAL else .DEC_LOCAL,
                            imm     = cast(s32) local_index,
                        };

                        array_add(*generator.current_function.instructions, op_instruction);

                        move_instruction := Instruction.{
                            op_code = .MOVE,
                            dest    = register,
                            arg1    = cast(u8) local_index,
                        };

                        array_add(*generator.current_function.instructions, move_instruction);

                        return register;
                    }
                }

                value_register := emit_expression(generator, update_expression.argument);

                register: u8;

                if destination_register != -1 {
                    register = cast(u8) destination_register;
                } else {
                    register = generator.next_register;
                    generator.next_register += 1;
                }

                if !update_expression.prefix {
                    move_instruction := Instruction.{
                        op_code = .MOVE,
                        dest    = register,
                        arg1    = value_register,
                    };

                    array_add(*generator.current_function.instructions, move_instruction);

                    one_index := -1;

                    for generator.program.constants {
                        if it.type == .NUMBER && it.number == 1.0 {
                            one_index = it_index;
                            break;
                        }
                    }

                    if one_index == -1 {
                        one_index = generator.program.constants.count;
                        array_add(*generator.program.constants, .{type=.NUMBER, number=1.0});
                    }

                    op_instruction := Instruction.{
                        op_code = ifx update_expression.op == "++" then .ADD_CONST else .SUB_CONST,
                        dest    = value_register,
                        arg1    = value_register,
                        imm     = cast(s32) one_index,
                    };

                    array_add(*generator.current_function.instructions, op_instruction);

                    emit_store(generator, update_expression.argument, value_register);

                    return register;
                } else {
                    one_index := -1;

                    for generator.program.constants {
                        if it.type == .NUMBER && it.number == 1.0 {
                            one_index = it_index;
                            break;
                        }
                    }

                    if one_index == -1 {
                        one_index = generator.program.constants.count;
                        array_add(*generator.program.constants, .{ type=.NUMBER, number = 1.0 });
                    }

                    op_instruction := Instruction.{
                        op_code = .ADD_CONST,
                        dest    = value_register,
                        arg1    = value_register,
                        imm     = cast(s32) one_index,
                    };

                    if update_expression.op == "++" {
                        array_add(*generator.current_function.instructions, op_instruction);
                    } else {
                        one_register := generator.next_register;

                        generator.next_register += 1;

                        load_const(generator, one_register, .{type=.NUMBER, number=1.0});

                        op_instruction.op_code = .SUB;
                        op_instruction.arg2 = one_register;

                        array_add(*generator.current_function.instructions, op_instruction);
                    }

                    emit_store(generator, update_expression.argument, value_register);

                    move_instruction := Instruction.{
                        op_code = .MOVE,
                        dest    = register,
                        arg1    = value_register,
                    };

                    array_add(*generator.current_function.instructions, move_instruction);

                    return register;
                }
            }

            value_register := emit_expression(generator, update_expression.argument);

            register: u8;

            if destination_register != -1 {
                register = cast(u8) destination_register;
            } else {
                register = generator.next_register;
                generator.next_register += 1;
            }

            if update_expression.prefix {
                move_instruction := Instruction.{
                    op_code = .MOVE,
                    dest    = register,
                    arg1    = value_register,
                };

                array_add(*generator.current_function.instructions, move_instruction);

                one_register := generator.next_register;

                generator.next_register += 1;

                load_const(generator, one_register, .{ type = .NUMBER, number = 1.0 });

                op_instruction := Instruction.{
                    op_code = ifx update_expression.op == "++" then .ADD else .SUB,
                    dest    = register,
                    arg1    = register,
                    arg2    = one_register,
                };

                array_add(*generator.current_function.instructions, op_instruction);

                emit_store(generator, update_expression.argument, register);

                return register;
            } else {
                move_instruction := Instruction.{
                    op_code = .MOVE,
                    dest    = register,
                    arg1    = value_register,
                };

                array_add(*generator.current_function.instructions, move_instruction);

                one_register := generator.next_register;

                generator.next_register += 1;

                load_const(generator, one_register, .{ type = .NUMBER, number = 1.0 });

                op_instruction := Instruction.{
                    op_code = ifx update_expression.op == "++" then .ADD else .SUB,
                    dest    = value_register,
                    arg1    = value_register,
                    arg2    = one_register,
                };

                array_add(*generator.current_function.instructions, op_instruction);

                emit_store(generator, update_expression.argument, value_register);

                return register;
            }

        case .CONDITIONAL_EXPRESSION;
            conditional_expression := cast(*Ast_Conditional_Expression) node;

            condition_register := emit_expression(generator, conditional_expression.test);

            jump_if_false_instruction := Instruction.{
                op_code = .JUMP_IF_FALSE,
                arg1    = condition_register,
            };

            jump_if_false_index := generator.current_function.instructions.count;

            array_add(*generator.current_function.instructions, jump_if_false_instruction);

            register: u8;

            if destination_register != -1 {
                register = cast(u8) destination_register;
            } else {
                register = generator.next_register;
                generator.next_register += 1;
            }

            consequent_register := emit_expression(generator, conditional_expression.consequent);

            move_instruction := Instruction.{
                op_code = .MOVE,
                dest    = register,
                arg1    = consequent_register,
            };

            array_add(*generator.current_function.instructions, move_instruction);

            jump_instruction := Instruction.{
                op_code = .JUMP,
            };

            jump_index := generator.current_function.instructions.count;

            array_add(*generator.current_function.instructions, jump_instruction);

            generator.current_function.instructions[jump_if_false_index].imm = cast(s32) generator.current_function.instructions.count;

            alternate_register := emit_expression(generator, conditional_expression.alternate);

            move_instruction_2 := Instruction.{
                op_code = .MOVE,
                dest    = register,
                arg1    = alternate_register,
            };

            array_add(*generator.current_function.instructions, move_instruction_2);

            generator.current_function.instructions[jump_index].imm = cast(s32) generator.current_function.instructions.count;

            return register;

        case .CLASS_EXPRESSION;
            register: u8;

            if destination_register != -1 {
                register = cast(u8) destination_register;
            } else {
                register = generator.next_register;
                generator.next_register += 1;
            }

            emit_class_expression(generator, cast(*Ast_Class_Expression) node, register);

            return register;

        case .METHOD_DEFINITION;

        case .SUPER_EXPRESSION;
            register: u8;

            if destination_register != -1 {
                register = cast(u8) destination_register;
            } else {
                register = generator.next_register;
                generator.next_register += 1;
            }

            emit_super_expression(generator, cast(*Ast_Super_Expression) node, register);

            return register;

        case .CLASS_DECLARATION;
        case .CLASS_BODY;
    }

    return 0;
}

get_property_index_standalone :: (program: *Bytecode_Program, name: string) -> int {
    pointer := table_find_pointer(*program.property_names_hash, name);
    if pointer return pointer.*;

    array_add(*program.property_names, name);

    index := program.property_names.count - 1;
    table_set(*program.property_names_hash, name, index);

    return index;
}

emit_class_declaration :: (generator: *Bytecode_Generator, node: *Ast_Class_Declaration) {
    if !node return;

    constructor_register := emit_class_common(generator, node.super_class, node.body);

    if node.identifier {
        identifier := cast(*Ast_Identifier) node.identifier;
        local_index := get_local_index(generator, identifier.name);

        if local_index != -1 {
            store_instruction := Instruction.{
                op_code = .STORE_LOCAL,
                arg1    = constructor_register,
                imm     = cast(s32) local_index,
            };

            emit_instruction(generator, store_instruction);
        } else {
            global_index := -1;

            for generator.program.globals {
                if it == identifier.name {
                    global_index = it_index;
                    break;
                }
            }

            if global_index == -1 {
                array_add(*generator.program.globals, identifier.name);
                global_index = generator.program.globals.count - 1;
            }

            store_instruction := Instruction.{
                op_code = .STORE_GLOBAL,
                arg1    = constructor_register,
                imm     = cast(s32) global_index,
            };

            emit_instruction(generator, store_instruction);
        }
    }
}

emit_class_expression :: (generator: *Bytecode_Generator, node: *Ast_Class_Expression, dest_register: u8) {
    if !node return;

    constructor_register := emit_class_common(generator, node.super_class, node.body);

    move_instruction := Instruction.{
        op_code = .MOVE,
        dest    = dest_register,
        arg1    = constructor_register,
    };

    emit_instruction(generator, move_instruction);
}

emit_class_common :: (generator: *Bytecode_Generator, super_class: *Ast_Node, body: *Ast_Class_Body) -> u8 {
    constructor_method: *Ast_Method_Definition = null;

    for body.body {
        if it.method_kind == .CONSTRUCTOR {
            constructor_method = it;
            break;
        }
    }

    constructor_register: u8;

    if constructor_method {
        constructor_register = emit_expression(generator, constructor_method.value);
    } else {
        function_expression: *Ast_Function_Expression;

        {
            push_allocator(temp);

            function_expression = New(Ast_Function_Expression);

            function_expression.kind = .FUNCTION_EXPRESSION;
            function_expression.body = New(Ast_Block_Statement);
            function_expression.body.kind = .BLOCK_STATEMENT;
        }

        constructor_register = emit_expression(generator, xx function_expression);
    }

    prototype_index := get_property_index_standalone(generator.program, "prototype");

    if super_class {
        super_register := emit_expression(generator, super_class);

        set_proto_instruction := Instruction.{
            op_code = .SET_PROTOTYPE,
            dest    = constructor_register,
            arg1    = super_register,
        };

        emit_instruction(generator, set_proto_instruction);

        constructor_prototype_register := generator.next_register;

        generator.next_register += 1;

        get_onstructor_prototype := Instruction.{
            op_code = .GET_FIELD,
            dest    = constructor_prototype_register,
            arg1    = constructor_register,
            imm     = cast(s32) prototype_index,
        };

        emit_instruction(generator, get_onstructor_prototype);

        super_prototype_register := generator.next_register;

        generator.next_register += 1;

        get_super_prototype := Instruction.{
            op_code = .GET_FIELD,
            dest    = super_prototype_register,
            arg1    = super_register,
            imm     = cast(s32) prototype_index,
        };

        emit_instruction(generator, get_super_prototype);

        set_prototype_2 := Instruction.{
            op_code = .SET_PROTOTYPE,
            dest    = constructor_prototype_register,
            arg1    = super_prototype_register,
        };

        emit_instruction(generator, set_prototype_2);
    }

    for body.body {
        if it.method_kind == .CONSTRUCTOR continue;

        method_register := emit_expression(generator, it.value);
        key_identifier  := cast(*Ast_Identifier) it.key;

        property_index := get_property_index_standalone(generator.program, key_identifier.name);

        target_register := constructor_register;

        if !it.is_static {
            target_register = generator.next_register;

            generator.next_register += 1;

            get_constructor_prototype := Instruction.{
                op_code = .GET_FIELD,
                dest    = target_register,
                arg1    = constructor_register,
                imm     = cast(s32) prototype_index,
            };

            emit_instruction(generator, get_constructor_prototype);
        }

        set_method := Instruction.{
            op_code = .SET_FIELD,
            dest    = target_register,
            arg1    = method_register,
            imm     = cast(s32) property_index,
        };

        emit_instruction(generator, set_method);
    }

    return constructor_register;
}

emit_super_expression :: (generator: *Bytecode_Generator, node: *Ast_Super_Expression, dest_register: u8) {
    load_this := Instruction.{
        op_code = .LOAD_THIS,
        dest    = dest_register,
    };

    emit_instruction(generator, load_this);
}

operator == :: (a: Value, b: Value) -> bool {
    if a.type != b.type return false;

    if #complete a.type == {
        case .UNDEFINED;       return true;
        case .NULL;            return true;
        case .NUMBER;          return a.number               == b.number;
        case .OBJECT;          return a.object               == b.object;
        case .ARRAY;           return a.object               == b.object;
        case .FUNCTION;        return a.function.function    == b.function.function;
        case .BOOLEAN;         return a.boolean              == b.boolean;
        case .NATIVE_FUNCTION; return a.native_function      == b.native_function;
        case .STRING;          return a.s                    == b.s;
        case .GENERATOR;       return a.generator_object     == b.generator_object;
    }
}

Op_Code :: enum u8 {
    LOAD_CONST;
    LOAD_GLOBAL;
    STORE_GLOBAL;
    LOAD_LOCAL;
    STORE_LOCAL;
    ADD;
    SUB;
    MUL;
    DIV;
    MOD;
    CALL;
    NEW_CALL;
    RETURN;
    NEW_OBJECT;
    SET_FIELD;
    GET_FIELD;
    NEW_ARRAY;
    ARRAY_GET;
    ARRAY_SET;
    LOAD_FUNC;
    EQUAL;
    NOT_EQUAL;
    LESS_THAN;
    GREATER_THAN;
    LESS_THAN_EQUAL;
    GREATER_THAN_EQUAL;
    STRICT_EQUAL;
    STRICT_NOT_EQUAL;
    INSTANCEOF;
    IN;
    BITWISE_AND;
    BITWISE_OR;
    BITWISE_XOR;
    JUMP;
    JUMP_IF_FALSE;
    JUMP_IF_TRUE;
    MOVE;
    LOGICAL_NOT;
    TYPEOF;
    THROW;
    YIELD;
    AWAIT;
    IMPORT;
    EXPORT;
    LOAD_UPVALUE;
    STORE_UPVALUE;
    LOAD_THIS;
    TRY_CONTEXT;
    POP_TRY_CONTEXT;
    ITERATOR_NEXT;
    ITERATOR_CLOSE;
    COMPUTED_SET;
    EXPONENTIATION;
    JUMP_IF_NOT_NULLISH;
    UNARY_MINUS;
    ARRAY_APPEND;
    OBJECT_SPREAD;
    ARRAY_PUSH;
    CALL_APPLY;
    NEW_CALL_APPLY;
    ARRAY_SLICE;
    SET_PROTOTYPE;
    SUPER_CALL;
    ADD_CONST;
    SUB_CONST;
    ADD_REG_REG;
    ADD_LOCAL_LOCAL;
    SUB_LOCAL_LOCAL;
    JUMP_IF_LESS_THAN;
    INC_LOCAL;
    DEC_LOCAL;
    JUMP_IF_LOCAL_LESS_THAN_CONST;
}

Instruction :: struct {
    op_code: Op_Code;

    dest:    u8;

    arg1:    u8;
    arg2:    u8;

    imm:     s32;

    inline_cache: Inline_Cache;
}

Inline_Cache :: struct {
    shapes:        [PIC_SIZE] *Shape;
    target_shapes: [PIC_SIZE] *Shape;

    offsets: [PIC_SIZE] s32;

    count: s8;
}

Bytecode_Function_Flags :: enum_flags u8 {
    GENERATOR;
    ASYNC;
    TOP_LEVEL;
    ARROW;
    REST_PARAMETER;
}

Bytecode_Function :: struct {
    name: string;

    locals_count:    int;
    arguments_count: int;

    instructions: [..] Instruction;
    flags: Bytecode_Function_Flags;

    locals: [..] string;
}

Bytecode_Program :: struct {
    functions:      [..] *Bytecode_Function;
    constants:      [..] Value;
    globals:        [..] string;

    property_names:      [..] string;
    property_names_hash: Table(string, int);

    has_error:     bool;
    error_message: string;
}

Bytecode_Generator :: struct {
    program:          *Bytecode_Program;
    current_function: *Bytecode_Function;
    parent:           *Bytecode_Generator;

    next_register: u8;

    locals:     [..] string;
    loop_stack: [..] Loop_Context;

    has_error:     bool;
    error_message: string;
}

Value_Type :: enum u8 {
    UNDEFINED;
    NULL;
    NUMBER;
    OBJECT;
    ARRAY;
    FUNCTION;
    BOOLEAN;
    NATIVE_FUNCTION;
    STRING;
    GENERATOR;
}

Function :: struct {
    function:    *Bytecode_Function;
    environment: *Environment;
}

Native_Function :: #type (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value;

Value :: struct {
    object: *Gc_Object;

    union type: Value_Type {
        .NUMBER          ,, number:           float64;
        .BOOLEAN         ,, boolean:          bool;
        .STRING          ,, s:                string;
        .FUNCTION        ,, function:         Function;
        .GENERATOR       ,, generator_object: *Gc_Object;
        .NATIVE_FUNCTION ,, native_function:  Native_Function;
    }
}

Loop_Context :: struct {
    continue_target: int = -1;

    continue_jumps:  [..] int;
    break_jumps:     [..] int;

    is_switch:       bool;
}

Variable_Location_Type :: enum { LOCAL; UPVALUE; GLOBAL; NOT_FOUND; }

Variable_Location :: struct {
    type: Variable_Location_Type;
    index: int;
    level: int;
}

PIC_SIZE :: 4;