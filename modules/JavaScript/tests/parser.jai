test_parser :: () {
    test(() => {
        push_allocator(temp);

        code := #string JS
            let a = 5;
        JS

        _, _, tokens := tokenize(code);
        ast          := build_ast(code, tokens);
        bytecode     := generate_bytecode(ast);

        main_function: *Bytecode_Function;
        for bytecode.functions if it.name == "main" main_function = it;

        expect_not_null(main_function);
        expect_equals(main_function.instructions.count, 2);
        expect_equals(main_function.instructions[0].op_code, .LOAD_CONST);
        expect_equals(main_function.instructions[1].op_code, .STORE_GLOBAL);
    });

    test(() => {
        push_allocator(temp);

        code := #string JS
            function add(x, y) {
                return x + y;
            }
        JS

        _, _, tokens := tokenize(code);
        ast          := build_ast(code, tokens);
        bytecode     := generate_bytecode(ast);

        add_function: *Bytecode_Function;
        for bytecode.functions if it.name == "add" add_function = it;

        expect_not_null(add_function);
        expect_equals(add_function.arguments_count, 2);
        expect_equals(add_function.instructions.count, 2);
        expect_equals(add_function.instructions[0].op_code, .ADD);
        expect_equals(add_function.instructions[1].op_code, .RETURN);
    });

    test(() => {
        push_allocator(temp);

        code := #string JS
            let x = 1 + 2 * 3;
        JS

        _, _, tokens := tokenize(code);
        ast          := build_ast(code, tokens);
        bytecode     := generate_bytecode(ast);

        main_function: *Bytecode_Function;
        for bytecode.functions if it.name == "main" main_function = it;

        expect_not_null(main_function);
        expect_equals(main_function.instructions.count, 6);
        expect_equals(main_function.instructions[5].op_code, .STORE_GLOBAL);
    });

    test(() => {
        push_allocator(temp);

        code := #string JS
            let x = 1;
            let y = 2;
            /* multiline
               comment */
            let z = 3;
        JS

        _, _, tokens := tokenize(code);

        found_x       := false;
        found_y       := false;
        found_z       := false;
        found_comment := false;

        for tokens {
            if it.text == "x" {
                expect_equals(it.line, 1);
                expect_equals(it.column, 17);
                found_x = true;
            } else if it.text == "y" {
                expect_equals(it.line, 2);
                expect_equals(it.column, 17);
                found_y = true;
            } else if it.text == "z" {
                expect_equals(it.line, 5);
                expect_equals(it.column, 17);
                found_z = true;
            } else if it.type == .COMMENT && it.text.count > 20 {
                expect_equals(it.line, 3);
                expect_equals(it.column, 13);
                found_comment = true;
            }
        }

        expect_true(found_x);
        expect_true(found_y);
        expect_true(found_z);
        expect_true(found_comment);
    });

    test(() => {
        push_allocator(temp);

        code := #string JS
            let x = 1;
            let y = 2;
        JS

        _, _, tokens := tokenize(code);
        ast          := build_ast(code, tokens);
        bytecode     := generate_bytecode(ast);

        expect_equals(ast.statements.count, 2);

        node1 := ast.statements[0];
        expect_equals(node1.line, 1);
        expect_equals(node1.column, 13);

        decl1 := cast(*Ast_Variable_Declaration) node1;
        expect_equals(decl1.declarations[0].identifier.line, 1);
        expect_equals(decl1.declarations[0].identifier.column, 17);

        node2 := ast.statements[1];
        expect_equals(node2.line, 2);
        expect_equals(node2.column, 13);

        decl2 := cast(*Ast_Variable_Declaration) node2;
        expect_equals(decl2.declarations[0].identifier.line, 2);
        expect_equals(decl2.declarations[0].identifier.column, 17);
    });

    test(() => {
        push_allocator(temp);

        code := #string JS
            var tr = $(id), coll = !hasClass(tr, 'coll');
        JS

        _, _, tokens := tokenize(code);
        ast          := build_ast(code, tokens);
        bytecode     := generate_bytecode(ast);

        expect_equals(ast.statements.count, 1);

        node1 := ast.statements[0];
        expect_equals(node1.line, 1);
        expect_equals(node1.column, 13);

        decl1 := cast(*Ast_Variable_Declaration) node1;
        expect_equals(decl1.declarations.count, 2);

        expect_equals(decl1.declarations[0].identifier.line, 1);
        expect_equals(decl1.declarations[0].identifier.column, 17);

        expect_equals(decl1.declarations[1].identifier.line, 1);
        expect_equals(decl1.declarations[1].identifier.column, 29);
    });
}
