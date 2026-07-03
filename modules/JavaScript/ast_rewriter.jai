optimize_ast :: (program: *Ast_Program) {
    for * program.statements {
        new_statement := optimize_node(it.*);
        if new_statement it.* = new_statement;
    }
}

optimize_node :: (node: *Ast_Node) -> *Ast_Node {
    if !node return null;

    if #complete node.kind == {
        case .BINARY_EXPRESSION;
            binary_expression := cast(*Ast_Binary_Expression) node;

            optimized_left_node := optimize_node(binary_expression.left);
            if optimized_left_node binary_expression.left = optimized_left_node;

            optimized_right_node := optimize_node(binary_expression.right);
            if optimized_right_node binary_expression.right = optimized_right_node;

        case .EXPRESSION_STATEMENT;
            expression_statement           := cast(*Ast_Expression_Statement) node;
            optimized_expression_statement := optimize_node(expression_statement.expression);

            if optimized_expression_statement expression_statement.expression = optimized_expression_statement;

        case .IF_STATEMENT;
            if_statement := cast(*Ast_If_Statement) node;

            optimized_condition := optimize_node(if_statement.condition);
            if optimized_condition if_statement.condition = optimized_condition;

            optimized_then_branch := optimize_node(if_statement.then_branch);
            if optimized_then_branch if_statement.then_branch = optimized_then_branch;

            if if_statement.else_branch {
                optimized_else_branch := optimize_node(if_statement.else_branch);
                if optimized_else_branch if_statement.else_branch = optimized_else_branch;
            }

        case .WHILE_STATEMENT;
            while_statement := cast(*Ast_While_Statement) node;

            optimized_condition := optimize_node(while_statement.condition);
            if optimized_condition while_statement.condition = optimized_condition;

            optimized_body := optimize_node(while_statement.body);
            if optimized_body while_statement.body = optimized_body;

        case .FOR_STATEMENT;
            for_statement := cast(*Ast_For_Statement) node;

            if for_statement.init {
                optimized_init := optimize_node(for_statement.init);
                if optimized_init for_statement.init = optimized_init;
            }

            if for_statement.condition {
                optimized_condition := optimize_node(for_statement.condition);
                if optimized_condition for_statement.condition = optimized_condition;
            }

            if for_statement.update {
                optimized_update := optimize_node(xx for_statement.update);
                if optimized_update for_statement.update = xx optimized_update;
            }

            optimized_body := optimize_node(for_statement.body);
            if optimized_body for_statement.body = optimized_body;

        case .BLOCK_STATEMENT;
            block_statement := cast(*Ast_Block_Statement) node;

            for * block_statement.body {
                optimized := optimize_node(it.*);
                if optimized it.* = optimized;
            }

        case .VARIABLE_DECLARATION;
            variable_declaration := cast(*Ast_Variable_Declaration) node;

            for variable_declaration.declarations {
                if it.init {
                    optimized := optimize_node(it.init);
                    if optimized it.init = optimized;
                }
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

            if class_declaration.super_class {
                optimized := optimize_node(class_declaration.super_class);
                if optimized class_declaration.super_class = optimized;
            }

        case .CLASS_EXPRESSION;
            class_expression := cast(*Ast_Class_Expression) node;

            if class_expression.body {
                optimized := optimize_node(xx class_expression.body);
            }

            if class_expression.super_class {
                optimized := optimize_node(class_expression.super_class);
                if optimized class_expression.super_class = optimized;
            }

        case .CLASS_BODY;
            class_body := cast(*Ast_Class_Body) node;

            for * class_body.body {
                optimized := optimize_node(xx it.*);
                if optimized it.* = xx optimized;
            }

        case .METHOD_DEFINITION;
            method_definition := cast(*Ast_Method_Definition) node;

            if method_definition.value {
                optimized := optimize_node(method_definition.value);
                if optimized method_definition.value = optimized;
            }

        case .RETURN_STATEMENT;
            return_statement := cast(*Ast_Return_Statement) node;

            if return_statement.argument {
                optimized := optimize_node(return_statement.argument);
                if optimized return_statement.argument = optimized;
            }

        case .PROGRAM; #through;

        case .TEMPLATE_LITERAL;
            template_literal := cast(*Ast_Template_Literal) node;

            for * template_literal.expressions {
                optimized := optimize_node(it.*);
                if optimized it.* = optimized;
            }

        case .VARIABLE_DECLARATOR;
            variable_declarator := cast(*Ast_Variable_Declarator) node;

            if variable_declarator.identifier {
                optimized := optimize_node(variable_declarator.identifier);
                if optimized variable_declarator.identifier = optimized;
            }

            if variable_declarator.init {
                optimized := optimize_node(variable_declarator.init);
                if optimized variable_declarator.init = optimized;
            }

        case .CONDITIONAL_EXPRESSION;
            conditional_expression := cast(*Ast_Conditional_Expression) node;

            if conditional_expression.test {
                optimized := optimize_node(conditional_expression.test);
                if optimized conditional_expression.test = optimized;
            }

            if conditional_expression.consequent {
                optimized := optimize_node(conditional_expression.consequent);
                if optimized conditional_expression.consequent = optimized;
            }

            if conditional_expression.alternate {
                optimized := optimize_node(conditional_expression.alternate);
                if optimized conditional_expression.alternate = optimized;
            }

        case .CALL_EXPRESSION;
            call_expression := cast(*Ast_Call_Expression) node;

            if call_expression.callee {
                optimized := optimize_node(call_expression.callee);
                if optimized call_expression.callee = optimized;
            }

            for * call_expression.arguments {
                optimized := optimize_node(it.*);
                if optimized it.* = optimized;
            }

        case .NEW_EXPRESSION;
            new_expression := cast(*Ast_New_Expression) node;

            if new_expression.callee {
                optimized := optimize_node(new_expression.callee);
                if optimized new_expression.callee = optimized;
            }

            for * new_expression.arguments {
                optimized := optimize_node(it.*);
                if optimized it.* = optimized;
            }

        case .LOGICAL_EXPRESSION;
            logical_expression := cast(*Ast_Logical_Expression) node;

            if logical_expression.left {
                optimized := optimize_node(logical_expression.left);
                if optimized logical_expression.left = optimized;
            }

            if logical_expression.right {
                optimized := optimize_node(logical_expression.right);
                if optimized logical_expression.right = optimized;
            }

        case .SPREAD_ELEMENT;
            spread_element := cast(*Ast_Spread_Element) node;

            if spread_element.argument {
                optimized := optimize_node(spread_element.argument);
                if optimized spread_element.argument = optimized;
            }

        case .UPDATE_EXPRESSION;
            update_expression := cast(*Ast_Update_Expression) node;

            if update_expression.argument {
                optimized := optimize_node(update_expression.argument);
                if optimized update_expression.argument = optimized;
            }

        case .ARRAY_LITERAL;
            array_literal := cast(*Ast_Array_Literal) node;

            for * array_literal.elements {
                optimized := optimize_node(it.*);
                if optimized it.* = optimized;
            }

        case .MEMBER_EXPRESSION;
            member_expression := cast(*Ast_Member_Expression) node;

            if member_expression.object {
                optimized := optimize_node(member_expression.object);
                if optimized member_expression.object = optimized;
            }

            if member_expression.property {
                optimized := optimize_node(member_expression.property);
                if optimized member_expression.property = optimized;
            }

        case .OBJECT_LITERAL;
            object_literal := cast(*Ast_Object_Literal) node;

            for * object_literal.properties {
                if it.value {
                    optimized := optimize_node(it.value);
                    if optimized it.value = optimized;
                }
            }

        case .FUNCTION_EXPRESSION;
            function_expression := cast(*Ast_Function_Expression) node;

            for * function_expression.parameters {
                optimized := optimize_node(it.*);
                if optimized it.* = optimized;
            }

            if function_expression.body {
                optimized := optimize_node(xx function_expression.body);
            }

        case .ASSIGNMENT_EXPRESSION;
            assignment_expression := cast(*Ast_Assignment_Expression) node;

            if assignment_expression.left {
                optimized := optimize_node(assignment_expression.left);
                if optimized assignment_expression.left = optimized;
            }

            if assignment_expression.right {
                optimized := optimize_node(assignment_expression.right);
                if optimized assignment_expression.right = optimized;
            }

        case .SWITCH_STATEMENT;
            switch_statement := cast(*Ast_Switch_Statement) node;

            if switch_statement.discriminant {
                optimized := optimize_node(switch_statement.discriminant);
                if optimized switch_statement.discriminant = optimized;
            }

            for * switch_statement.cases {
                optimized := optimize_node(xx it.*);
            }

        case .THROW_STATEMENT;
            throw_statement := cast(*Ast_Throw_Statement) node;

            if throw_statement.argument {
                optimized := optimize_node(throw_statement.argument);
                if optimized throw_statement.argument = optimized;
            }

        case .CASE_CLAUSE;
            case_clause := cast(*Ast_Switch_Case) node;

            if case_clause.test {
                optimized := optimize_node(case_clause.test);
                if optimized case_clause.test = optimized;
            }

            for * case_clause.consequent {
                optimized := optimize_node(it.*);
                if optimized it.* = optimized;
            }

        case .ARROW_FUNCTION_EXPRESSION;
            arrow_function_expression := cast(*Ast_Arrow_Function_Expression) node;

            for * arrow_function_expression.parameters {
                optimized := optimize_node(it.*);
                if optimized it.* = optimized;
            }

            if arrow_function_expression.body {
                optimized := optimize_node(arrow_function_expression.body);
                if optimized arrow_function_expression.body = optimized;
            }

        case .UNARY_EXPRESSION;
            unary_expression := cast(*Ast_Unary_Expression) node;
            if unary_expression.right {
                optimized := optimize_node(unary_expression.right);
                if optimized unary_expression.right = optimized;
            }


        case .YIELD_EXPRESSION;
            yield_expression := cast(*Ast_Yield_Expression) node;

            if yield_expression.argument {
                optimized := optimize_node(yield_expression.argument);
                if optimized yield_expression.argument = optimized;
            }

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

            if for_of_statement.left {
                optimized := optimize_node(for_of_statement.left);
                if optimized for_of_statement.left = optimized;
            }

            if for_of_statement.right {
                optimized := optimize_node(for_of_statement.right);
                if optimized for_of_statement.right = optimized;
            }

            if for_of_statement.body {
                optimized := optimize_node(for_of_statement.body);
                if optimized for_of_statement.body = optimized;
            }

        case .EXPORT_STATEMENT;
            export_statement := cast(*Ast_Export_Statement) node;

            if export_statement.declaration {
                optimized := optimize_node(export_statement.declaration);
                if optimized export_statement.declaration = optimized;
            }

        case .AWAIT_EXPRESSION; #through;
        case .SUPER_EXPRESSION; #through;
        case .LITERAL_NUMBER;   #through;
        case .LITERAL_STRING;   #through;
        case .IDENTIFIER;       #through;
        case .THIS_EXPRESSION;  #through;
        case .IMPORT_STATEMENT; #through;
        case .BREAK_STATEMENT;  #through;
        case .CONTINUE_STATEMENT;
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
