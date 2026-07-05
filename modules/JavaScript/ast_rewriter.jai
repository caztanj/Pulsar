optimize_ast :: (program: *Ast_Program) {
    for * program.statements {
        new_statement := optimize_node(it.*);
        if new_statement it.* = new_statement;
    }
}

optimize_field :: inline (field: **$T) {
    if !field.* return;
    optimized := optimize_node(xx field.*);
    if optimized { field.* = xx optimized; }
}

optimize_array :: inline (arr: [] *$T) {
    for * arr {
        if !it.* continue;
        optimized := optimize_node(xx it.*);
        if optimized { it.* = xx optimized; }
    }
}

optimize_node :: (node: *Ast_Node) -> *Ast_Node {
    if !node return null;

    if #complete node.kind == {
        case .BINARY_EXPRESSION;
            binary_expression := cast(*Ast_Binary_Expression) node;

            optimize_field(*binary_expression.left);
            optimize_field(*binary_expression.right);

        case .EXPRESSION_STATEMENT;
            expression_statement           := cast(*Ast_Expression_Statement) node;
            optimize_field(*expression_statement.expression);

        case .IF_STATEMENT;
            if_statement := cast(*Ast_If_Statement) node;

            optimize_field(*if_statement.condition);
            optimize_field(*if_statement.then_branch);
            optimize_field(*if_statement.else_branch);

        case .WHILE_STATEMENT;
            while_statement := cast(*Ast_While_Statement) node;

            optimize_field(*while_statement.condition);
            optimize_field(*while_statement.body);

        case .FOR_STATEMENT;
            for_statement := cast(*Ast_For_Statement) node;

            optimize_field(*for_statement.init);
            optimize_field(*for_statement.condition);
            optimize_field(*for_statement.update);
            optimize_field(*for_statement.body);

        case .BLOCK_STATEMENT;
            block_statement := cast(*Ast_Block_Statement) node;
            optimize_array(block_statement.body);

        case .VARIABLE_DECLARATION;
            variable_declaration := cast(*Ast_Variable_Declaration) node;

            for variable_declaration.declarations {
                optimize_field(*it.init);
            }

        case .FUNCTION_DECLARATION;
            function_declaration := cast(*Ast_Function_Declaration) node;

            if function_declaration.body {
                optimized := optimize_node(xx function_declaration.body);
            }

        case .CLASS_DECLARATION;
            class_declaration := cast(*Ast_Class_Declaration) node;

            if class_declaration.body {
                optimized := optimize_node(xx class_declaration.body);
            }

            optimize_field(*class_declaration.super_class);

        case .CLASS_EXPRESSION;
            class_expression := cast(*Ast_Class_Expression) node;

            if class_expression.body {
                optimized := optimize_node(xx class_expression.body);
            }

            optimize_field(*class_expression.super_class);

        case .CLASS_BODY;
            class_body := cast(*Ast_Class_Body) node;
            optimize_array(class_body.body);

        case .METHOD_DEFINITION;
            method_definition := cast(*Ast_Method_Definition) node;
            optimize_field(*method_definition.value);

        case .RETURN_STATEMENT;
            return_statement := cast(*Ast_Return_Statement) node;
            optimize_field(*return_statement.argument);

        case .PROGRAM; #through;

        case .TEMPLATE_LITERAL;
            template_literal := cast(*Ast_Template_Literal) node;
            optimize_array(template_literal.expressions);

        case .VARIABLE_DECLARATOR;
            variable_declarator := cast(*Ast_Variable_Declarator) node;

            optimize_field(*variable_declarator.identifier);
            optimize_field(*variable_declarator.init);

        case .CONDITIONAL_EXPRESSION;
            conditional_expression := cast(*Ast_Conditional_Expression) node;

            optimize_field(*conditional_expression.test);
            optimize_field(*conditional_expression.consequent);
            optimize_field(*conditional_expression.alternate);

        case .CALL_EXPRESSION;
            call_expression := cast(*Ast_Call_Expression) node;

            optimize_field(*call_expression.callee);
            optimize_array(call_expression.arguments);

        case .NEW_EXPRESSION;
            new_expression := cast(*Ast_New_Expression) node;

            optimize_field(*new_expression.callee);
            optimize_array(new_expression.arguments);

        case .LOGICAL_EXPRESSION;
            logical_expression := cast(*Ast_Logical_Expression) node;

            optimize_field(*logical_expression.left);
            optimize_field(*logical_expression.right);

        case .SPREAD_ELEMENT;
            spread_element := cast(*Ast_Spread_Element) node;
            optimize_field(*spread_element.argument);

        case .UPDATE_EXPRESSION;
            update_expression := cast(*Ast_Update_Expression) node;
            optimize_field(*update_expression.argument);

        case .ARRAY_LITERAL;
            array_literal := cast(*Ast_Array_Literal) node;
            optimize_array(array_literal.elements);

        case .MEMBER_EXPRESSION;
            member_expression := cast(*Ast_Member_Expression) node;

            optimize_field(*member_expression.object);
            optimize_field(*member_expression.property);

        case .OBJECT_LITERAL;
            object_literal := cast(*Ast_Object_Literal) node;

            for * object_literal.properties {
                optimize_field(*it.value);
            }

        case .FUNCTION_EXPRESSION;
            function_expression := cast(*Ast_Function_Expression) node;

            optimize_array(function_expression.parameters);

            if function_expression.body {
                optimized := optimize_node(xx function_expression.body);
            }

        case .ASSIGNMENT_EXPRESSION;
            assignment_expression := cast(*Ast_Assignment_Expression) node;

            optimize_field(*assignment_expression.left);
            optimize_field(*assignment_expression.right);

        case .SWITCH_STATEMENT;
            switch_statement := cast(*Ast_Switch_Statement) node;

            optimize_field(*switch_statement.discriminant);

            for * switch_statement.cases {
                optimized := optimize_node(xx it.*);
            }

        case .THROW_STATEMENT;
            throw_statement := cast(*Ast_Throw_Statement) node;
            optimize_field(*throw_statement.argument);

        case .CASE_CLAUSE;
            case_clause := cast(*Ast_Switch_Case) node;

            optimize_field(*case_clause.test);
            optimize_array(case_clause.consequent);

        case .ARROW_FUNCTION_EXPRESSION;
            arrow_function_expression := cast(*Ast_Arrow_Function_Expression) node;

            optimize_array(arrow_function_expression.parameters);
            optimize_field(*arrow_function_expression.body);

        case .UNARY_EXPRESSION;
            unary_expression := cast(*Ast_Unary_Expression) node;
            optimize_field(*unary_expression.right);

        case .YIELD_EXPRESSION;
            yield_expression := cast(*Ast_Yield_Expression) node;
            optimize_field(*yield_expression.argument);

        case .TRY_STATEMENT;
            try_statement := cast(*Ast_Try_Statement) node;

            if try_statement.try_block {
                optimized := optimize_node(xx try_statement.try_block);
            }

            if try_statement.catch_block {
                optimized := optimize_node(xx try_statement.catch_block);
            }

            if try_statement.finally_block {
                optimized := optimize_node(xx try_statement.finally_block);
            }

        case .FOR_OF_STATEMENT;
            for_of_statement := cast(*Ast_For_Of_Statement) node;

            optimize_field(*for_of_statement.left);
            optimize_field(*for_of_statement.right);
            optimize_field(*for_of_statement.body);

        case .EXPORT_STATEMENT;
            export_statement := cast(*Ast_Export_Statement) node;
            optimize_field(*export_statement.declaration);

        case .AWAIT_EXPRESSION; #through;
        case .SUPER_EXPRESSION; #through;
        case .LITERAL_NUMBER;   #through;
        case .LITERAL_STRING;   #through;
        case .IDENTIFIER;       #through;
        case .THIS_EXPRESSION;  #through;
        case .IMPORT_STATEMENT; #through;
        case .BREAK_STATEMENT;  #through;
        case .CONTINUE_STATEMENT;

        case .IMPORT_EXPRESSION;
            import_expression := cast(*Ast_Import_Expression) node;
            optimize_field(*import_expression.argument);
    }

    folded := constant_folding(node);
    if folded return folded;

    return null;
}

constant_folding :: (node: *Ast_Node) -> *Ast_Node {
    if node.kind == {
        case .BINARY_EXPRESSION;
            binary_expression := cast(*Ast_Binary_Expression) node;

            if binary_expression.left.kind == .LITERAL_NUMBER && binary_expression.right.kind == .LITERAL_NUMBER {
                left  := cast(*Ast_Literal_Number) binary_expression.left;
                right := cast(*Ast_Literal_Number) binary_expression.right;

                if binary_expression.op == {
                    case "+"; return xx create_number_node(left.value + right.value);
                    case "-"; return xx create_number_node(left.value - right.value);
                    case "*"; return xx create_number_node(left.value * right.value);
                    case "/"; return xx create_number_node(left.value / right.value);
                }
            }

        case .UNARY_EXPRESSION;
            unary_expression := cast(*Ast_Unary_Expression) node;

            if unary_expression.right.kind == .LITERAL_NUMBER {
                right := cast(*Ast_Literal_Number) unary_expression.right;
                if unary_expression.op == "-" return xx create_number_node(-right.value);
                if unary_expression.op == "+" return xx create_number_node(right.value);
            }
    }

    return null;
}

create_number_node :: (value: float64) -> *Ast_Literal_Number {
    node := New(Ast_Literal_Number);

    node.kind = .LITERAL_NUMBER;
    node.value = value;

    return node;
}
