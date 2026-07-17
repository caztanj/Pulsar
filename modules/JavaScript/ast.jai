build_ast :: (code: string, tokens: [] Token) -> *Ast_Program {
    parser := Parser.{
        code   = code,
        tokens = tokens,
    };

    program := new_node(*parser, Ast_Program);
    program.kind = .PROGRAM;

    while !is_at_end(*parser) {
        if parser.has_error break;
        statement := parse_statement(*parser);

        if statement array_add(*program.statements, statement);

        skip_whitespace_and_comments(*parser);
    }

    if parser.has_error {
        program.has_error = true;
        program.error_message = parser.error_message;
    }

    return program;
}

create_identifier :: inline (token: Token) -> *Ast_Identifier {
    identifier := New(Ast_Identifier);
    identifier.kind   = .IDENTIFIER;
    identifier.name   = token.text;
    identifier.line   = token.line;
    identifier.column = token.column;
    return identifier;
}

new_node :: (parser: *Parser, $T: Type) -> *T {
    node := New(T);

    if !is_at_end(parser) {
        token := peek(parser);

        node.line   = token.line;
        node.column = token.column;
    }

    return node;
}

parse_statement :: (parser: *Parser) -> *Ast_Node {
    if is_at_end(parser) return null;

    token := peek(parser);

    if token.type == .WHITESPACE || token.type == .COMMENT {
        skip_whitespace_and_comments(parser);

        if is_at_end(parser) return null;

        token = peek(parser);
    }

    if token.type == .IDENTIFIER {
        if token.text == "let" || token.text == "const" || token.text == "var" {
            return parse_variable_declaration(parser);
        } else if token.text == "function" {
            return xx parse_function_declaration(parser);
        } else if token.text == "async" {
            old_current := parser.current;

            advance(parser);
            skip_whitespace_and_comments(parser);

            next := peek(parser);

            if next.type == .IDENTIFIER && next.text == "function" {
                func := parse_function_declaration(parser);
                func.is_async = true;

                return xx func;
            }

            parser.current = old_current;
        } else if token.text == "return" {
            return parse_return_statement(parser);
        } else if token.text == "if" {
            return parse_if_statement(parser);
        } else if token.text == "throw" {
            return parse_throw_statement(parser);
        } else if token.text == "while" {
            return parse_while_statement(parser);
        } else if token.text == "for" {
            return parse_for_statement(parser);
        } else if token.text == "import" {
            old_current := parser.current;

            advance(parser);
            skip_whitespace_and_comments(parser);

            if peek(parser).text == "(" {
                parser.current = old_current;
            } else {
                parser.current = old_current;
                return xx parse_import_statement(parser);
            }
        } else if token.text == "export" {
            return xx parse_export_statement(parser);
        } else if token.text == "try" {
            return xx parse_try_statement(parser);
        } else if token.text == "switch" {
            return xx parse_switch_statement(parser);
        } else if token.text == "break" {
            node := new_node(parser, Ast_Break_Statement);
            node.kind = .BREAK_STATEMENT;

            advance(parser);
            skip_whitespace_and_comments(parser);
            consume_semicolon(parser);

            return xx node;
        } else if token.text == "continue" {
            node := new_node(parser, Ast_Continue_Statement);
            node.kind = .CONTINUE_STATEMENT;

            advance(parser);
            skip_whitespace_and_comments(parser);
            consume_semicolon(parser);

            return xx node;
        } else if token.text == "class" {
            return xx parse_class_declaration(parser);
        }
    }

    if token.type == .PUNCTUATION && token.text == "{" {
        return xx parse_block_statement(parser);
    }

    if token.type == .PUNCTUATION && token.text == ";" {
        advance(parser);
        return null;
    }

    return parse_expression_statement(parser);
}

parse_try_statement :: (parser: *Parser) -> *Ast_Try_Statement {
    node := new_node(parser, Ast_Try_Statement);
    node.kind = .TRY_STATEMENT;

    consume(parser, "try");
    skip_whitespace_and_comments(parser);

    node.try_block = parse_block_statement(parser);

    skip_whitespace_and_comments(parser);

    if match(parser, "catch") {
        skip_whitespace_and_comments(parser);

        if match(parser, "(") {
            skip_whitespace_and_comments(parser);

            identifier_token := consume(parser, .IDENTIFIER);
            identifier := create_identifier(identifier_token);

            node.catch_parameter = identifier;

            consume(parser, ")");
        }

        skip_whitespace_and_comments(parser);

        node.catch_block = parse_block_statement(parser);
    }

    skip_whitespace_and_comments(parser);

    if match(parser, "finally") {
        skip_whitespace_and_comments(parser);
        node.finally_block = parse_block_statement(parser);
    }

    return node;
}

parse_switch_statement :: (parser: *Parser) -> *Ast_Switch_Statement {
    node := new_node(parser, Ast_Switch_Statement);
    node.kind = .SWITCH_STATEMENT;

    consume(parser, "switch");
    skip_whitespace_and_comments(parser);
    consume(parser, "(");

    node.discriminant = parse_expression(parser);

    consume(parser, ")");

    skip_whitespace_and_comments(parser);
    consume(parser, "{");

    while !is_at_end(parser) && !check(parser, "}") {
        skip_whitespace_and_comments(parser);

        case_node := new_node(parser, Ast_Switch_Case);
        case_node.kind = .CASE_CLAUSE;

        if match(parser, "case") {
            skip_whitespace_and_comments(parser);

            case_node.test = parse_expression(parser);

            consume(parser, ":");
        } else if match(parser, "default") {
            skip_whitespace_and_comments(parser);
            consume(parser, ":");
        } else {
            report_parse_error(parser, peek(parser), "Expected 'case' or 'default' in switch statement");
            return null;
        }

        while !is_at_end(parser) && !check(parser, "case") && !check(parser, "default") && !check(parser, "}") {
            skip_whitespace_and_comments(parser);
            if is_at_end(parser) || check(parser, "case") || check(parser, "default") || check(parser, "}") break;

            statement := parse_statement(parser);

            if statement array_add(*case_node.consequent, statement);

            skip_whitespace_and_comments(parser);
        }

        array_add(*node.cases, case_node);
    }

    consume(parser, "}");

    return node;
}

parse_block_statement :: (parser: *Parser) -> *Ast_Block_Statement {
    node := new_node(parser, Ast_Block_Statement);
    node.kind = .BLOCK_STATEMENT;

    consume(parser, "{");

    while !is_at_end(parser) && !check(parser, "}") {
        if parser.has_error break;
        statement := parse_statement(parser);

        if statement array_add(*node.body, statement);

        skip_whitespace_and_comments(parser);
    }

    consume(parser, "}");

    return node;
}

parse_if_statement :: (parser: *Parser) -> *Ast_Node {
    node := new_node(parser, Ast_If_Statement);
    node.kind = .IF_STATEMENT;

    advance(parser);

    skip_whitespace_and_comments(parser);
    consume(parser, "(");

    node.condition = parse_expression(parser);

    consume(parser, ")");

    skip_whitespace_and_comments(parser);

    node.then_branch = parse_statement(parser);

    skip_whitespace_and_comments(parser);

    if match(parser, "else") {
        skip_whitespace_and_comments(parser);
        node.else_branch = parse_statement(parser);
    }

    return xx node;
}

parse_while_statement :: (parser: *Parser) -> *Ast_Node {
    node := new_node(parser, Ast_While_Statement);
    node.kind = .WHILE_STATEMENT;

    advance(parser);

    skip_whitespace_and_comments(parser);
    consume(parser, "(");

    node.condition = parse_expression(parser);

    consume(parser, ")");

    skip_whitespace_and_comments(parser);

    node.body = parse_statement(parser);

    return xx node;
}

parse_for_statement :: (parser: *Parser) -> *Ast_Node {
    start_token := peek(parser);

    advance(parser);

    skip_whitespace_and_comments(parser);
    consume(parser, "(");

    old_current := parser.current;

    skip_whitespace_and_comments(parser);

    is_for_of := false;
    is_for_in := false;
    token     := peek(parser);

    if token.type == .IDENTIFIER && (token.text == "let" || token.text == "const" || token.text == "var") {
        advance(parser);
        skip_whitespace_and_comments(parser);

        next := peek(parser);

        if next.type == .IDENTIFIER || (next.type == .PUNCTUATION && (next.text == "[" || next.text == "{")) {
            if next.type == .IDENTIFIER {
                advance(parser);
            } else {
                depth := 0;

                while !is_at_end(parser) {
                    t := advance(parser);

                    if      t.text == "[" || t.text == "{" depth += 1;
                    else if t.text == "]" || t.text == "}" depth -= 1;

                    if depth == 0 break;
                }
            }

            skip_whitespace_and_comments(parser);

            if peek(parser).type == .IDENTIFIER && peek(parser).text == "of" {
                is_for_of = true;
            } else if peek(parser).type == .IDENTIFIER && peek(parser).text == "in" {
                is_for_in = true;
            }
        }
    } else if token.type == .IDENTIFIER || (token.type == .PUNCTUATION && (token.text == "[" || token.text == "{")) {
        if token.type == .IDENTIFIER {
            advance(parser);
        } else {
            depth := 0;

            while !is_at_end(parser) {
                t := advance(parser);

                if      t.text == "[" || t.text == "{" depth += 1;
                else if t.text == "]" || t.text == "}" depth -= 1;

                if depth == 0 break;
            }
        }

        skip_whitespace_and_comments(parser);

        if peek(parser).type == .IDENTIFIER && peek(parser).text == "of" {
            is_for_of = true;
        } else if peek(parser).type == .IDENTIFIER && peek(parser).text == "in" {
            is_for_in = true;
        }
    }

    parser.current = old_current;

    if is_for_of || is_for_in {
        node_kind := ifx is_for_of then Ast_Kind.FOR_OF_STATEMENT else Ast_Kind.FOR_IN_STATEMENT;

        node: *Ast_Node;
        if is_for_of {
            node = xx new_node(parser, Ast_For_Of_Statement);
        } else {
            node = xx new_node(parser, Ast_For_In_Statement);
        }

        node.kind = node_kind;
        node.line = start_token.line;
        node.column = start_token.column;

        skip_whitespace_and_comments(parser);

        token = peek(parser);

        if token.type == .IDENTIFIER && (token.text == "let" || token.text == "const" || token.text == "var") {
            decl := new_node(parser, Ast_Variable_Declaration);
            decl.kind = .VARIABLE_DECLARATION;
            decl.declaration_type = advance(parser).text;

            skip_whitespace_and_comments(parser);

            next := peek(parser);

            declarator := new_node(parser, Ast_Variable_Declarator);
            declarator.kind = .VARIABLE_DECLARATOR;

            if next.type == .PUNCTUATION && (next.text == "[" || next.text == "{") {
                declarator.identifier = parse_primary(parser);
            } else {
                identifier_token := consume(parser, .IDENTIFIER);
                identifier := create_identifier(identifier_token);

                declarator.identifier = xx identifier;
            }
            array_add(*decl.declarations, declarator);

            if is_for_of {
                (cast(*Ast_For_Of_Statement) node).left = xx decl;
            } else {
                (cast(*Ast_For_In_Statement) node).left = xx decl;
            }
        } else {
            left_expr := parse_expression(parser);
            if is_for_of {
                (cast(*Ast_For_Of_Statement) node).left = left_expr;
            } else {
                (cast(*Ast_For_In_Statement) node).left = left_expr;
            }
        }

        skip_whitespace_and_comments(parser);
        if is_for_of consume(parser, "of");
        else         consume(parser, "in");

        right_expr := parse_expression(parser);
        if is_for_of {
            (cast(*Ast_For_Of_Statement) node).right = right_expr;
        } else {
            (cast(*Ast_For_In_Statement) node).right = right_expr;
        }

        consume(parser, ")");

        skip_whitespace_and_comments(parser);

        body_expr := parse_statement(parser);
        if is_for_of {
            (cast(*Ast_For_Of_Statement) node).body = body_expr;
        } else {
            (cast(*Ast_For_In_Statement) node).body = body_expr;
        }

        return xx node;
    }

    node := new_node(parser, Ast_For_Statement);

    node.kind   = .FOR_STATEMENT;
    node.line   = start_token.line;
    node.column = start_token.column;

    skip_whitespace_and_comments(parser);

    if !check(parser, ";") {
        token := peek(parser);

        if token.type == .IDENTIFIER && (token.text == "let" || token.text == "const" || token.text == "var") {
            node.init = parse_variable_declaration(parser);
        } else {
            node.init = parse_expression_statement(parser);
        }
    } else {
        consume(parser, ";");
    }

    skip_whitespace_and_comments(parser);

    if !check(parser, ";") {
        node.condition = parse_expression(parser);
    }

    consume(parser, ";");

    skip_whitespace_and_comments(parser);

    if !check(parser, ")") {
        node.update = parse_expression(parser);
    }

    consume(parser, ")");

    skip_whitespace_and_comments(parser);

    node.body = parse_statement(parser);

    return xx node;
}

parse_variable_declaration :: (parser: *Parser) -> *Ast_Node {
    variable_declaration := new_node(parser, Ast_Variable_Declaration);
    variable_declaration.kind = .VARIABLE_DECLARATION;

    type_token := advance(parser);
    variable_declaration.declaration_type = type_token.text;

    skip_whitespace_and_comments(parser);

    while true {
        if parser.has_error break;
        declarator := new_node(parser, Ast_Variable_Declarator);
        declarator.kind = .VARIABLE_DECLARATOR;

        token := peek(parser);

        if token.type == .PUNCTUATION && (token.text == "[" || token.text == "{") {
            declarator.identifier = parse_primary(parser);
        } else {
            identifier_token := consume(parser, .IDENTIFIER);
            identifier := create_identifier(identifier_token);

            declarator.identifier = xx identifier;
        }

        skip_whitespace_and_comments(parser);

        if match(parser, "=") {
            skip_whitespace_and_comments(parser);
            declarator.init = parse_expression(parser);
        }

        array_add(*variable_declaration.declarations, declarator);

        skip_whitespace_and_comments(parser);
        if !match(parser, ",") {
            break;
        }
        skip_whitespace_and_comments(parser);
    }

    consume_semicolon(parser);

    return xx variable_declaration;
}

parse_function_declaration :: (parser: *Parser) -> *Ast_Function_Declaration {
    function_declaration := new_node(parser, Ast_Function_Declaration);
    function_declaration.kind = .FUNCTION_DECLARATION;

    consume(parser, .IDENTIFIER);

    skip_whitespace_and_comments(parser);

    if match(parser, "*") {
        function_declaration.is_generator = true;
        skip_whitespace_and_comments(parser);
    }

    identifier_token := consume(parser, .IDENTIFIER);
    identifier := create_identifier(identifier_token);

    function_declaration.identifier = identifier;

    skip_whitespace_and_comments(parser);

    consume(parser, "(");

    if !check(parser, ")") {
        while true {
            if parser.has_error break;
            skip_whitespace_and_comments(parser);

            if check(parser, "...") {
                advance(parser);

                spread := new_node(parser, Ast_Spread_Element);
                spread.kind = .SPREAD_ELEMENT;

                skip_whitespace_and_comments(parser);

                parameter_token := consume(parser, .IDENTIFIER);
                parameter := create_identifier(parameter_token);

                spread.argument = xx parameter;

                array_add(*function_declaration.parameters, xx spread);

                skip_whitespace_and_comments(parser);

                break;
            } else {
                parameter_token := consume(parser, .IDENTIFIER);
                parameter := create_identifier(parameter_token);

                array_add(*function_declaration.parameters, xx parameter);
            }

            skip_whitespace_and_comments(parser);

            if !match(parser, ",") break;
        }
    }

    skip_whitespace_and_comments(parser);
    consume(parser, ")");

    skip_whitespace_and_comments(parser);

    function_declaration.body = parse_block_statement(parser);

    return function_declaration;
}

parse_return_statement :: (parser: *Parser) -> *Ast_Node {
    return_statement := new_node(parser, Ast_Return_Statement);
    return_statement.kind = .RETURN_STATEMENT;

    advance(parser);

    if !can_insert_semicolon(parser) {
        return_statement.argument = parse_expression(parser);
    }

    consume_semicolon(parser);

    return xx return_statement;
}

parse_throw_statement :: (parser: *Parser) -> *Ast_Node {
    node := new_node(parser, Ast_Throw_Statement);
    node.kind = .THROW_STATEMENT;

    advance(parser);

    if !can_insert_semicolon(parser) {
        node.argument = parse_expression(parser);
    }

    consume_semicolon(parser);

    return xx node;
}

parse_expression_statement :: (parser: *Parser) -> *Ast_Node {
    node := new_node(parser, Ast_Expression_Statement);
    node.kind = .EXPRESSION_STATEMENT;

    node.expression = parse_expression(parser);

    consume_semicolon(parser);

    return xx node;
}

parse_expression :: (parser: *Parser) -> *Ast_Node {
    return parse_assignment(parser);
}

parse_assignment :: (parser: *Parser) -> *Ast_Node {
    left := parse_conditional(parser);

    skip_whitespace_and_comments(parser);

    if is_at_end(parser) return left;

    token := peek(parser);

    if token.type == .OPERATOR && (token.text == "=" || token.text == "+=" || token.text == "-=" || token.text == "*=" || token.text == "/=" || token.text == "**=" || token.text == "??=") {
        advance(parser);

        node := New(Ast_Assignment_Expression);

        node.kind   = .ASSIGNMENT_EXPRESSION;
        node.left   = left;
        node.line   = left.line;
        node.column = left.column;
        node.op     = token.text;
        node.right  = parse_assignment(parser);

        return xx node;
    }

    return left;
}

parse_conditional :: (parser: *Parser) -> *Ast_Node {
    left := parse_binary(parser, 0);

    skip_whitespace_and_comments(parser);

    if match(parser, "?") {
        node := New(Ast_Conditional_Expression);

        node.kind   = .CONDITIONAL_EXPRESSION;
        node.line   = left.line;
        node.column = left.column;
        node.test   = left;

        skip_whitespace_and_comments(parser);

        node.consequent = parse_assignment(parser);

        skip_whitespace_and_comments(parser);
        consume(parser, ":");

        skip_whitespace_and_comments(parser);

        node.alternate = parse_assignment(parser);

        return xx node;
    }

    return left;
}

parse_binary :: (parser: *Parser, precedence: int) -> *Ast_Node {
    left := parse_unary(parser);
    if !left return null;

    while true {
        skip_whitespace_and_comments(parser);

        if is_at_end(parser) break;

        token := peek(parser);
        if token.type != .OPERATOR && !(token.type == .IDENTIFIER && (token.text == "instanceof" || token.text == "in")) break;

        next_precedence := get_precedence(token.text);
        if next_precedence <= precedence break;

        advance(parser);

        p := next_precedence;
        if token.text == "**" p -= 1;

        right := parse_binary(parser, p);

        if token.text == "&&" || token.text == "||" || token.text == "??" {
            node := New(Ast_Logical_Expression);

            node.kind   = .LOGICAL_EXPRESSION;
            node.left   = left;
            node.line   = left.line;
            node.column = left.column;
            node.right  = right;
            node.op     = token.text;

            left = xx node;
        } else {
            node := New(Ast_Binary_Expression);

            node.kind   = .BINARY_EXPRESSION;
            node.left   = left;
            node.line   = left.line;
            node.column = left.column;
            node.op     = token.text;
            node.right  = right;

            left = xx node;
        }
    }

    return left;
}

parse_unary :: (parser: *Parser) -> *Ast_Node {
    skip_whitespace_and_comments(parser);
    if is_at_end(parser) return null;

    token := peek(parser);
    if (token.type == .OPERATOR && (token.text == "!" || token.text == "-" || token.text == "+" || token.text == "++" || token.text == "--")) || (token.type == .IDENTIFIER && (token.text == "typeof" || token.text == "yield" || token.text == "await")) {
        advance(parser);

        if token.text == "++" || token.text == "--" {
            node := New(Ast_Update_Expression);

            node.kind     = .UPDATE_EXPRESSION;
            node.line     = token.line;
            node.column   = token.column;
            node.op       = token.text;
            node.prefix   = true;
            node.argument = parse_unary(parser);

            return xx node;
        }

        if token.text == "yield" {
            node := New(Ast_Yield_Expression);

            node.kind   = .YIELD_EXPRESSION;
            node.line   = token.line;
            node.column = token.column;

            skip_whitespace_and_comments(parser);

            if !check(parser, ";") && !check(parser, "}") && !check(parser, ")") && !check(parser, ",") {
                node.argument = parse_expression(parser);
            }

            return xx node;
        }

        if token.text == "await" {
            node := New(Ast_Yield_Expression);

            node.kind     = .AWAIT_EXPRESSION;
            node.line     = token.line;
            node.column   = token.column;
            node.argument = parse_expression(parser);

            return xx node;
        }

        node := New(Ast_Unary_Expression);

        node.kind   = .UNARY_EXPRESSION;
        node.line   = token.line;
        node.column = token.column;
        node.op     = token.text;
        node.right  = parse_unary(parser);

        return xx node;
    }

    return parse_postfix(parser);
}

get_precedence :: (op: string) -> int {
    if op == "??"         return 1;
    if op == "||"         return 2;
    if op == "&&"         return 3;
    if op == "|"          return 4;
    if op == "^"          return 5;
    if op == "&"          return 6;
    if op == "=="         return 7;
    if op == "!="         return 7;
    if op == "==="        return 7;
    if op == "!=="        return 7;
    if op == "<"          return 8;
    if op == ">"          return 8;
    if op == "<="         return 8;
    if op == ">="         return 8;
    if op == "in"         return 8;
    if op == "instanceof" return 8;
    if op == "+"          return 9;
    if op == "-"          return 9;
    if op == "*"          return 10;
    if op == "/"          return 10;
    if op == "%"          return 10;
    if op == "**"         return 11;

    return 0;
}


parse_postfix :: (parser: *Parser, allow_calls: bool = true) -> *Ast_Node {
    left := parse_primary(parser);
    if !left return null;

    while true {
        skip_whitespace_and_comments(parser);

        if is_at_end(parser) break;

        token := peek(parser);

        if allow_calls && token.type == .PUNCTUATION && token.text == "(" {
            advance(parser);

            call := New(Ast_Call_Expression);

            call.kind   = .CALL_EXPRESSION;
            call.line   = left.line;
            call.column = left.column;
            call.callee = left;

            if !check(parser, ")") {
                while true {
                    if parser.has_error break;
                    skip_whitespace_and_comments(parser);

                    if check(parser, "...") {
                        advance(parser);

                        spread := new_node(parser, Ast_Spread_Element);

                        spread.kind     = .SPREAD_ELEMENT;
                        spread.argument = parse_assignment(parser);

                        array_add(*call.arguments, xx spread);
                    } else {
                        argument := parse_expression(parser);
                        array_add(*call.arguments, xx argument);
                    }

                    skip_whitespace_and_comments(parser);

                    if !match(parser, ",") break;
                }
            }

            consume(parser, ")");

            left = xx call;
        } else if token.type == .PUNCTUATION && token.text == "." {
            advance(parser);

            member := New(Ast_Member_Expression);

            member.kind     = .MEMBER_EXPRESSION;
            member.line     = left.line;
            member.column   = left.column;
            member.object   = left;
            member.computed = false;

            skip_whitespace_and_comments(parser);

            property_token := consume(parser, .IDENTIFIER);
            identifier := create_identifier(property_token);

            member.property = xx identifier;

            left = xx member;
        } else if token.type == .PUNCTUATION && token.text == "[" {
            advance(parser);

            member := New(Ast_Member_Expression);

            member.kind     = .MEMBER_EXPRESSION;
            member.line     = left.line;
            member.column   = left.column;
            member.object   = left;
            member.computed = true;

            skip_whitespace_and_comments(parser);

            member.property = parse_expression(parser);

            consume(parser, "]");

            left = xx member;
        } else if token.type == .OPERATOR && (token.text == "++" || token.text == "--") {
            advance(parser);

            node := New(Ast_Update_Expression);

            node.kind     = .UPDATE_EXPRESSION;
            node.line     = token.line;
            node.column   = token.column;
            node.op       = token.text;
            node.prefix   = false;
            node.argument = left;

            left = xx node;
        } else {
            break;
        }
    }

    return left;
}

parse_primary :: (parser: *Parser) -> *Ast_Node {
    skip_whitespace_and_comments(parser);

    token := peek(parser);

    if token.type == .NUMBER {
        advance(parser);

        node := New(Ast_Literal_Number);

        node.kind   = .LITERAL_NUMBER;
        node.line   = token.line;
        node.column = token.column;
        node.value  = string_to_float64(token.text);
        node.text   = token.text;

        return xx node;
    }

    if token.type == .STRING {
        advance(parser);

        node := New(Ast_Literal_String);

        node.kind   = .LITERAL_STRING;
        node.line   = token.line;
        node.column = token.column;
        node.value  = unescape_string(slice(token.text, 1, token.text.count - 2));

        return xx node;
    }

    if token.type == .REGEXP {
        advance(parser);

        node := new_node(parser, Ast_Literal_RegExp);
        node.kind = .LITERAL_REGEXP;

        text := token.text;
        last_slash := find_index_from_right(text, "/");
        if last_slash != -1 && last_slash > 0 {
            node.pattern = slice(text, 1, last_slash - 1);
            node.flags   = slice(text, last_slash + 1, text.count - last_slash - 1);
        } else {
            node.pattern = "";
            node.flags   = "";
        }

        return xx node;
    }

    if token.type == .IDENTIFIER {
        if token.text == "function" {
            return xx parse_function_expression(parser);
        } else if token.text == "class" {
            return xx parse_class_expression(parser);
        } else if token.text == "super" {
            advance(parser);

            node := new_node(parser, Ast_Super_Expression);

            node.kind   = .SUPER_EXPRESSION;
            node.line   = token.line;
            node.column = token.column;

            return xx node;
        } else if token.text == "async" {
            old_current := parser.current;

            advance(parser);
            skip_whitespace_and_comments(parser);

            next := peek(parser);

            if next.type == .IDENTIFIER && next.text == "function" {
                func := parse_function_expression(parser);
                func.is_async = true;

                return xx func;
            } else if next.type == .IDENTIFIER || (next.type == .PUNCTUATION && next.text == "(") {
                is_arrow := false;

                if next.type == .IDENTIFIER {
                    t := parser.current;

                    while t < parser.tokens.count && (parser.tokens[t].type == .WHITESPACE || parser.tokens[t].type == .COMMENT) t += 1;

                    if t < parser.tokens.count && parser.tokens[t].text == "=>" is_arrow = true;
                } else {
                    depth := 1;
                    t     := parser.current + 1;

                    while t < parser.tokens.count && depth > 0 {
                        if      parser.tokens[t].text == "(" depth += 1;
                        else if parser.tokens[t].text == ")" depth -= 1;

                        t += 1;
                    }

                    if depth == 0 {
                        while t < parser.tokens.count && (parser.tokens[t].type == .WHITESPACE || parser.tokens[t].type == .COMMENT) t += 1;

                        if t < parser.tokens.count && parser.tokens[t].text == "=>" is_arrow = true;
                    }
                }

                if is_arrow {
                    node := new_node(parser, Ast_Arrow_Function_Expression);

                    node.kind     = .ARROW_FUNCTION_EXPRESSION;
                    node.is_async = true;

                    if next.type == .IDENTIFIER {
                        parameter_token := advance(parser);
                        parameter := create_identifier(parameter_token);

                        array_add(*node.parameters, xx parameter);
                    } else {
                        advance(parser);

                        if !check(parser, ")") {
                            while true {
                                skip_whitespace_and_comments(parser);

                                parameter_token := consume(parser, .IDENTIFIER);
                                parameter := create_identifier(parameter_token);

                                array_add(*node.parameters, xx parameter);

                                skip_whitespace_and_comments(parser);

                                if !match(parser, ",") break;
                            }
                        }

                        consume(parser, ")");
                    }

                    skip_whitespace_and_comments(parser);

                    consume(parser, "=>");

                    node.body = parse_arrow_body(parser);

                    return xx node;
                }
            }

            parser.current = old_current;
        } else if token.text == "new" {
            advance(parser);

            node := New(Ast_New_Expression);

            node.kind   = .NEW_EXPRESSION;
            node.line   = token.line;
            node.column = token.column;
            node.callee = parse_postfix(parser, allow_calls = false);

            skip_whitespace_and_comments(parser);
            consume(parser, "(");

            if !check(parser, ")") {
                while true {
                    skip_whitespace_and_comments(parser);

                    argument := parse_expression(parser);
                    array_add(*node.arguments, xx argument);

                    skip_whitespace_and_comments(parser);

                    if !match(parser, ",") break;
                }
            }

            consume(parser, ")");

            return xx node;
        } else if token.text == "this" {
            advance(parser);

            node := New(Ast_Node);

            node.kind   = .THIS_EXPRESSION;
            node.line   = token.line;
            node.column = token.column;

            return node;
        } else if token.text == "import" {
            advance(parser);

            node := new_node(parser, Ast_Import_Expression);

            node.kind   = .IMPORT_EXPRESSION;
            node.line   = token.line;
            node.column = token.column;

            skip_whitespace_and_comments(parser);
            consume(parser, "(");

            skip_whitespace_and_comments(parser);
            node.argument = parse_expression(parser);

            skip_whitespace_and_comments(parser);
            consume(parser, ")");

            return xx node;
        }

        advance(parser);

        node := New(Ast_Identifier);

        node.kind   = .IDENTIFIER;
        node.line   = token.line;
        node.column = token.column;
        node.name   = token.text;

        old_current := parser.current;

        skip_whitespace_and_comments(parser);

        if match(parser, "=>") {
            arrow := new_node(parser, Ast_Arrow_Function_Expression);

            arrow.kind   = .ARROW_FUNCTION_EXPRESSION;
            arrow.line   = node.line;
            arrow.column = node.column;

            array_add(*arrow.parameters, xx node);

            arrow.body = parse_arrow_body(parser);

            return xx arrow;
        }

        parser.current = old_current;

        return xx node;
    }

    if token.type == .PUNCTUATION && token.text == "`" {
        return xx parse_template_literal(parser);
    }

    if token.type == .PUNCTUATION && token.text == "(" {
        old_current := parser.current;

        advance(parser);

        depth := 1;
        t     := parser.current;

        while t < parser.tokens.count && depth > 0 {
            if      parser.tokens[t].text == "(" depth += 1;
            else if parser.tokens[t].text == ")" depth -= 1;

            t += 1;
        }

        if depth == 0 {
            while t < parser.tokens.count && (parser.tokens[t].type == .WHITESPACE || parser.tokens[t].type == .COMMENT) t += 1;

            if t < parser.tokens.count && parser.tokens[t].text == "=>" {
                node := new_node(parser, Ast_Arrow_Function_Expression);
                node.kind = .ARROW_FUNCTION_EXPRESSION;

                if !check(parser, ")") {
                    while true {
                        skip_whitespace_and_comments(parser);

                        parameter_token := consume(parser, .IDENTIFIER);
                        parameter := create_identifier(parameter_token);

                        array_add(*node.parameters, xx parameter);

                        skip_whitespace_and_comments(parser);

                        if !match(parser, ",") break;
                    }
                }

                consume(parser, ")");
                skip_whitespace_and_comments(parser);
                consume(parser, "=>");

                node.body = parse_arrow_body(parser);

                return xx node;
            }
        }

        parser.current = old_current;

        advance(parser);

        expression := parse_expression(parser);

        consume(parser, ")");

        return expression;
    }

    if token.type == .PUNCTUATION && token.text == "[" {
        advance(parser);

        node := New(Ast_Array_Literal);

        node.kind   = .ARRAY_LITERAL;
        node.line   = token.line;
        node.column = token.column;

        if !check(parser, "]") {
            while true {
                if parser.has_error break;
                skip_whitespace_and_comments(parser);

                if check(parser, "...") {
                    advance(parser);

                    spread := new_node(parser, Ast_Spread_Element);

                    spread.kind     = .SPREAD_ELEMENT;
                    spread.argument = parse_assignment(parser);

                    array_add(*node.elements, xx spread);
                } else {
                    element := parse_expression(parser);
                    array_add(*node.elements, xx element);
                }

                skip_whitespace_and_comments(parser);

                if !match(parser, ",") break;

                skip_whitespace_and_comments(parser);
                if check(parser, "]") break;
            }
        }

        consume(parser, "]");

        return xx node;
    }

    if token.type == .PUNCTUATION && token.text == "{" {
        advance(parser);

        node := New(Ast_Object_Literal);

        node.kind   = .OBJECT_LITERAL;
        node.line   = token.line;
        node.column = token.column;

        if !check(parser, "}") {
            while true {
                if parser.has_error break;
                skip_whitespace_and_comments(parser);

                if check(parser, "...") {
                    advance(parser);

                    spread := new_node(parser, Ast_Spread_Element);

                    spread.kind     = .SPREAD_ELEMENT;
                    spread.argument = parse_assignment(parser);

                    property := Ast_Object_Property.{
                        is_spread = true,
                        value     = xx spread,
                    };

                    array_add(*node.properties, property);
                } else {
                    key_token := peek(parser);
                    is_generator := false;

                    if key_token.type == .OPERATOR && key_token.text == "*" {
                        is_generator = true;
                        advance(parser);
                        skip_whitespace_and_comments(parser);
                        key_token = peek(parser);
                    }

                    if key_token.type != .IDENTIFIER && key_token.type != .STRING && key_token.type != .NUMBER {
                        report_parse_error(parser, key_token, "Expected identifier, string, or number for object property key, but got % (%)", key_token.type, key_token.text);
                        break;
                    }

                    advance(parser);

                    key_text: string;
                    if key_token.type == .STRING {
                        key_text = unescape_string(slice(key_token.text, 1, key_token.text.count - 2));
                    } else {
                        key_text = key_token.text;
                    }

                    skip_whitespace_and_comments(parser);

                    value: *Ast_Node;

                    if match(parser, ":") {
                        if is_generator {
                            report_parse_error(parser, key_token, "Unexpected ':' after generator modifier");
                            break;
                        }

                        skip_whitespace_and_comments(parser);

                        value = parse_expression(parser);
                    } else if match(parser, "(") {
                        func := new_node(parser, Ast_Function_Expression);
                        func.kind = .FUNCTION_EXPRESSION;
                        func.is_generator = is_generator;

                        if !check(parser, ")") {
                            while true {
                                skip_whitespace_and_comments(parser);

                                if check(parser, "...") {
                                    advance(parser);

                                    spread := new_node(parser, Ast_Spread_Element);
                                    spread.kind = .SPREAD_ELEMENT;

                                    skip_whitespace_and_comments(parser);

                                    parameter_token := consume(parser, .IDENTIFIER);
                                    parameter := create_identifier(parameter_token);

                                    spread.argument = xx parameter;

                                    array_add(*func.parameters, xx spread);

                                    skip_whitespace_and_comments(parser);

                                    break;
                                } else {
                                    parameter_token := consume(parser, .IDENTIFIER);
                                    parameter := create_identifier(parameter_token);

                                    array_add(*func.parameters, xx parameter);
                                }

                                skip_whitespace_and_comments(parser);

                                if !match(parser, ",") break;
                            }
                        }

                        consume(parser, ")");
                        skip_whitespace_and_comments(parser);
                        func.body = parse_block_statement(parser);

                        value = xx func;
                    } else {
                        if key_token.type != .IDENTIFIER {
                            report_parse_error(parser, key_token, "Expected ':' after property key, but got % (%)", parser.tokens[parser.current].type, parser.tokens[parser.current].text);
                            break;
                        }

                        identifier := create_identifier(key_token);

                        value = xx identifier;
                    }

                    property := Ast_Object_Property.{
                        key   = key_text,
                        value = value,
                    };

                    array_add(*node.properties, property);
                }

                skip_whitespace_and_comments(parser);

                if !match(parser, ",") break;

                skip_whitespace_and_comments(parser);
                if check(parser, "}") break;
            }
        }

        consume(parser, "}");

        return xx node;
    }

    report_parse_error(parser, token, "Unexpected token '%' (%)", token.text, token.type);

    return null;
}

parse_template_literal :: (parser: *Parser) -> *Ast_Template_Literal {
    node := new_node(parser, Ast_Template_Literal);
    node.kind = .TEMPLATE_LITERAL;

    consume(parser, "`");

    while !is_at_end(parser) && !check(parser, "`") {
        if peek(parser).type == .TEMPLATE_PART {
            part := advance(parser);
            array_add(*node.quasis, unescape_string(part.text));
        } else if check(parser, "${") {
            if node.quasis.count == node.expressions.count {
                array_add(*node.quasis, "");
            }

            advance(parser);

            expression := parse_expression(parser);
            array_add(*node.expressions, expression);

            consume(parser, "}");
        } else {
            break;
        }
    }

    if node.quasis.count == node.expressions.count {
        array_add(*node.quasis, "");
    }

    consume(parser, "`");

    return node;
}

parse_function_expression :: (parser: *Parser) -> *Ast_Function_Expression {
    node := new_node(parser, Ast_Function_Expression);
    node.kind = .FUNCTION_EXPRESSION;

    consume(parser, .IDENTIFIER);

    skip_whitespace_and_comments(parser);
    if match(parser, "*") {
        node.is_generator = true;
        skip_whitespace_and_comments(parser);
    }

    consume(parser, "(");

    if !check(parser, ")") {
        while true {
            skip_whitespace_and_comments(parser);

            if check(parser, "...") {
                advance(parser);

                spread := new_node(parser, Ast_Spread_Element);
                spread.kind = .SPREAD_ELEMENT;

                skip_whitespace_and_comments(parser);

                parameter_token := consume(parser, .IDENTIFIER);
                parameter := create_identifier(parameter_token);

                spread.argument = xx parameter;

                array_add(*node.parameters, xx spread);

                skip_whitespace_and_comments(parser);

                break;
            } else {
                parameter_token := consume(parser, .IDENTIFIER);
                parameter := create_identifier(parameter_token);

                array_add(*node.parameters, xx parameter);
            }

            skip_whitespace_and_comments(parser);

            if !match(parser, ",") break;
        }
    }

    consume(parser, ")");

    skip_whitespace_and_comments(parser);

    node.body = parse_block_statement(parser);

    return node;
}

parse_arrow_body :: (parser: *Parser) -> *Ast_Node {
    skip_whitespace_and_comments(parser);

    if check(parser, "{") {
        return xx parse_block_statement(parser);
    } else {
        return parse_expression(parser);
    }
}

is_at_end :: (parser: *Parser) -> bool {
    return parser.current >= parser.tokens.count;
}

peek :: (parser: *Parser) -> Token {
    return parser.tokens[parser.current];
}

advance :: (parser: *Parser) -> Token {
    if !is_at_end(parser) {
        token := peek(parser);

        if token.type != .WHITESPACE && token.type != .COMMENT {
            parser.last_token_line = token.line;
        }

        parser.current += 1;
    }

    return parser.tokens[parser.current - 1];
}

check :: (parser: *Parser, text: string) -> bool {
    if is_at_end(parser) return false;
    return peek(parser).text == text;
}

match :: (parser: *Parser, text: string) -> bool {
    if check(parser, text) {
        advance(parser);
        return true;
    }

    return false;
}

consume :: (parser: *Parser, type: Token_Type) -> Token {
    token := peek(parser);

    if token.type == type return advance(parser);

    report_parse_error(parser, token, "Expected token type %, but got % (%)", type, token.type, token.text);
    return .{};
}

consume :: (parser: *Parser, text: string) -> Token {
    token := peek(parser);

    if token.text == text return advance(parser);

    report_parse_error(parser, token, "Expected token text '%', but got '%' (%)", text, token.text, token.type);
    return .{};
}

Parser :: struct {
    code:    string;
    tokens:  [] Token;
    current: int;

    last_token_line: int;

    has_error: bool;
    error_message: string;
}

can_insert_semicolon :: (parser: *Parser) -> bool {
    if is_at_end(parser)  return true;
    if check(parser, ";") return true;
    if check(parser, "}") return true;

    old_current := parser.current;

    defer parser.current = old_current;

    while !is_at_end(parser) {
        token := peek(parser);

        if token.type == .WHITESPACE || token.type == .COMMENT {
            parser.current += 1;
        } else {
            return token.line > parser.last_token_line;
        }
    }

    return true;
}

consume_semicolon :: (parser: *Parser) {
    if match(parser, ";")           return;
    if can_insert_semicolon(parser) return;

    report_parse_error(parser, peek(parser), "Expected ';' for automatic semicolon insertion, but none was found");
}

skip_whitespace_and_comments :: (parser: *Parser) {
    while !is_at_end(parser) {
        token := peek(parser);

        if token.type == .WHITESPACE || token.type == .COMMENT {
            advance(parser);
        } else {
            break;
        }
    }
}

parse_import_statement :: (parser: *Parser) -> *Ast_Import_Statement {
    node := new_node(parser, Ast_Import_Statement);
    node.kind = .IMPORT_STATEMENT;

    consume(parser, "import");
    skip_whitespace_and_comments(parser);

    if peek(parser).type == .STRING {
        node.source = cast(*Ast_Literal_String) parse_primary(parser);

        skip_whitespace_and_comments(parser);
        match(parser, ";");

        return node;
    }

    if match(parser, "*") {
        skip_whitespace_and_comments(parser);
        consume(parser, "as");
        skip_whitespace_and_comments(parser);

        identifier_token := consume(parser, .IDENTIFIER);
        identifier := create_identifier(identifier_token);

        node.namespace_import = identifier;
    } else if match(parser, "{") {
        while !check(parser, "}") {
            skip_whitespace_and_comments(parser);

            imported_token := consume(parser, .IDENTIFIER);
            imported := create_identifier(imported_token);

            local := imported;

            skip_whitespace_and_comments(parser);

            if match(parser, "as") {
                skip_whitespace_and_comments(parser);

                local_token := consume(parser, .IDENTIFIER);
                local        = New(Ast_Identifier);

                local.kind   = .IDENTIFIER;
                local.name   = local_token.text;
                local.line   = local_token.line;
                local.column = local_token.column;
            }

            array_add(*node.specifiers, .{imported, local});

            skip_whitespace_and_comments(parser);

            if !match(parser, ",") break;
        }

        skip_whitespace_and_comments(parser);
        consume(parser, "}");
    } else {
        default_token      := consume(parser, .IDENTIFIER);
        default_identifier := create_identifier(default_token);

        node.default_import = default_identifier;

        skip_whitespace_and_comments(parser);

        if match(parser, ",") {
            skip_whitespace_and_comments(parser);

            if match(parser, "*") {
                skip_whitespace_and_comments(parser);
                consume(parser, "as");
                skip_whitespace_and_comments(parser);

                identifier_token := consume(parser, .IDENTIFIER);
                identifier := create_identifier(identifier_token);

                node.namespace_import = identifier;
            } else {
                consume(parser, "{");

                while !check(parser, "}") {
                    skip_whitespace_and_comments(parser);

                    imported_token := consume(parser, .IDENTIFIER);
                    imported := create_identifier(imported_token);

                    local := imported;

                    skip_whitespace_and_comments(parser);

                    if match(parser, "as") {
                        skip_whitespace_and_comments(parser);

                        local_token := consume(parser, .IDENTIFIER);
                        local        = New(Ast_Identifier);

                        local.kind   = .IDENTIFIER;
                        local.name   = local_token.text;
                        local.line   = local_token.line;
                        local.column = local_token.column;
                    }

                    array_add(*node.specifiers, .{imported, local});

                    skip_whitespace_and_comments(parser);

                    if !match(parser, ",") break;
                }

                skip_whitespace_and_comments(parser);
                consume(parser, "}");
            }
        }
    }

    skip_whitespace_and_comments(parser);
    consume(parser, "from");
    skip_whitespace_and_comments(parser);

    source_token := consume(parser, .STRING);
    source       := New(Ast_Literal_String);

    source.kind   = .LITERAL_STRING;
    source.line   = source_token.line;
    source.column = source_token.column;
    source.value  = slice(source_token.text, 1, source_token.text.count - 2);

    node.source = source;

    skip_whitespace_and_comments(parser);
    match(parser, ";");

    return node;
}

parse_export_statement :: (parser: *Parser) -> *Ast_Export_Statement {
    node := new_node(parser, Ast_Export_Statement);
    node.kind = .EXPORT_STATEMENT;

    consume(parser, "export");
    skip_whitespace_and_comments(parser);

    if match(parser, "default") {
        node.is_default = true;

        skip_whitespace_and_comments(parser);

        node.declaration = parse_expression(parser);
    } else if match(parser, "*") {
        skip_whitespace_and_comments(parser);
        consume(parser, "from");
        skip_whitespace_and_comments(parser);

        source_token := consume(parser, .STRING);
        source       := New(Ast_Literal_String);

        source.kind   = .LITERAL_STRING;
        source.line   = source_token.line;
        source.column = source_token.column;
        source.value  = slice(source_token.text, 1, source_token.text.count - 2);

        node.source = source;
    } else if match(parser, "{") {
        while !check(parser, "}") {
            skip_whitespace_and_comments(parser);

            local_token := consume(parser, .IDENTIFIER);
            local := create_identifier(local_token);

            exported := local;

            skip_whitespace_and_comments(parser);

            if match(parser, "as") {
                skip_whitespace_and_comments(parser);

                exported_token := consume(parser, .IDENTIFIER);
                exported        = New(Ast_Identifier);

                exported.kind   = .IDENTIFIER;
                exported.name   = exported_token.text;
                exported.line   = exported_token.line;
                exported.column = exported_token.column;
            }

            array_add(*node.specifiers, .{local, exported});

            skip_whitespace_and_comments(parser);

            if !match(parser, ",") break;
        }

        skip_whitespace_and_comments(parser);
        consume(parser, "}");

        skip_whitespace_and_comments(parser);

        if match(parser, "from") {
            skip_whitespace_and_comments(parser);

            source_token := consume(parser, .STRING);
            source       := New(Ast_Literal_String);

            source.kind   = .LITERAL_STRING;
            source.line   = source_token.line;
            source.column = source_token.column;
            source.value  = slice(source_token.text, 1, source_token.text.count - 2);

            node.source = source;
        }
    } else {
        node.declaration = parse_statement(parser);
    }

    skip_whitespace_and_comments(parser);
    match(parser, ";");

    return node;
}

parse_class_declaration :: (parser: *Parser) -> *Ast_Class_Declaration {
    node := new_node(parser, Ast_Class_Declaration);
    node.kind = .CLASS_DECLARATION;

    consume(parser, "class");
    skip_whitespace_and_comments(parser);

    if peek(parser).type == .IDENTIFIER && peek(parser).text != "extends" {
        identifier_token := consume(parser, .IDENTIFIER);
        identifier := create_identifier(identifier_token);

        node.identifier = xx identifier;

        skip_whitespace_and_comments(parser);
    }

    if match(parser, "extends") {
        skip_whitespace_and_comments(parser);

        node.super_class = parse_expression(parser);

        skip_whitespace_and_comments(parser);
    }

    node.body = parse_class_body(parser);

    return node;
}

parse_class_expression :: (parser: *Parser) -> *Ast_Class_Expression {
    node := new_node(parser, Ast_Class_Expression);
    node.kind = .CLASS_EXPRESSION;

    consume(parser, "class");
    skip_whitespace_and_comments(parser);

    if peek(parser).type == .IDENTIFIER && peek(parser).text != "extends" {
        identifier_token := consume(parser, .IDENTIFIER);
        identifier := create_identifier(identifier_token);

        node.identifier = xx identifier;

        skip_whitespace_and_comments(parser);
    }

    if match(parser, "extends") {
        skip_whitespace_and_comments(parser);

        node.super_class = parse_expression(parser);

        skip_whitespace_and_comments(parser);
    }

    node.body = parse_class_body(parser);

    return node;
}

parse_class_body :: (parser: *Parser) -> *Ast_Class_Body {
    node := new_node(parser, Ast_Class_Body);
    node.kind = .CLASS_BODY;

    consume(parser, "{");
    skip_whitespace_and_comments(parser);

    while !is_at_end(parser) && !check(parser, "}") {
        if check(parser, ";") {
            advance(parser);
            skip_whitespace_and_comments(parser);

            continue;
        }

        method := parse_method_definition(parser);
        array_add(*node.body, method);

        skip_whitespace_and_comments(parser);
    }

    consume(parser, "}");

    return node;
}

parse_method_definition :: (parser: *Parser) -> *Ast_Method_Definition {
    node := new_node(parser, Ast_Method_Definition);

    node.kind        = .METHOD_DEFINITION;
    node.is_static   = false;
    node.method_kind = .METHOD;

    if match(parser, "static") {
        skip_whitespace_and_comments(parser);

        if check(parser, "(") {
            parser.current -= 1;

            identifier := New(Ast_Identifier);

            identifier.kind   = .IDENTIFIER;
            identifier.name   = "static";
            identifier.line   = node.line;
            identifier.column = node.column;

            node.key = xx identifier;
        } else {
            node.is_static = true;
        }
    }

    if !node.key {
        identifier_token := consume(parser, .IDENTIFIER);
        identifier := create_identifier(identifier_token);

        node.key = xx identifier;

        if identifier.name == "constructor" && !node.is_static {
            node.method_kind = .CONSTRUCTOR;
        }
    }

    skip_whitespace_and_comments(parser);

    func := new_node(parser, Ast_Function_Expression);
    func.kind = .FUNCTION_EXPRESSION;

    consume(parser, "(");

    if !check(parser, ")") {
        while true {
            skip_whitespace_and_comments(parser);

            if check(parser, "...") {
                advance(parser);

                spread := new_node(parser, Ast_Spread_Element);
                spread.kind = .SPREAD_ELEMENT;

                skip_whitespace_and_comments(parser);

                parameter_token := consume(parser, .IDENTIFIER);
                parameter := create_identifier(parameter_token);

                spread.argument = xx parameter;

                array_add(*func.parameters, xx spread);

                skip_whitespace_and_comments(parser);

                break;
            } else {
                parameter_token := consume(parser, .IDENTIFIER);
                parameter := create_identifier(parameter_token);

                array_add(*func.parameters, xx parameter);
            }

            skip_whitespace_and_comments(parser);

            if !match(parser, ",") break;
        }
    }

    consume(parser, ")");
    skip_whitespace_and_comments(parser);

    func.body = parse_block_statement(parser);
    node.value = xx func;

    return node;
}

report_parse_error :: (parser: *Parser, token: Token, message: string, args: ..Any) {
    if parser.has_error return;
    parser.has_error = true;

    builder: String_Builder;
    builder.allocator = temp;

    print_to_builder(*builder, "Unknown JavaScript: Parse Error at line %, column %: ", token.line, token.column);
    print_to_builder(*builder, message, ..args);
    print_to_builder(*builder, "\n\n");

    line      := token.line;
    column    := token.column;
    error_ptr := token.text.data;
    code      := parser.code;

    line_start := error_ptr;
    while line_start > code.data && (line_start - 1).* != "\n" {
        line_start -= 1;
    }

    line_end := error_ptr;
    while line_end < code.data + code.count && line_end.* != "\n" {
        line_end += 1;
    }

    previous_line_start: *u8;
    previous_line_end:   *u8;

    if line_start > code.data {
        previous_line_end = line_start - 1;
        previous_line_start = previous_line_end;

        while previous_line_start > code.data && (previous_line_start - 1).* != "\n" {
            previous_line_start -= 1;
        }
    }

    next_line_start: *u8;
    next_line_end:   *u8;

    if line_end < code.data + code.count {
        next_line_start = line_end + 1;
        next_line_end = next_line_start;

        while next_line_end < code.data + code.count && next_line_end.* != "\n" {
            next_line_end += 1;
        }
    }

    if previous_line_start {
        text := string.{
            data  = previous_line_start,
            count = previous_line_end - previous_line_start,
        };

        print_to_builder(*builder, "%: %\n", line - 1, text);
    }

    {
        text := string.{
            data = line_start,
            count = line_end - line_start,
        };

        print_to_builder(*builder, "%: %\n", line, text);
    }

    prefix_length  := 0;
    temporary_line := line;

    if temporary_line == 0 prefix_length = 1;
    else while temporary_line > 0 { temporary_line /= 10; prefix_length += 1; }

    prefix_length += 2;

    for 1..prefix_length + column - 1 print_to_builder(*builder, " ");
    print_to_builder(*builder, "^\n");

    if next_line_start {
        text := string.{
            data  = next_line_start,
            count = next_line_end - next_line_start,
        };

        print_to_builder(*builder, "%: %\n", line + 1, text);
    }

    print_to_builder(*builder, "\n");

    parser.error_message = builder_to_string(*builder);
}

unescape_string :: (s: string) -> string {
    if !contains(s, "\\") return copy_string(s);

    builder: String_Builder;

    i := 0;

    while i < s.count {
        if s[i] == {
            case "\\";
                if i + 1 < s.count {
                    i += 1;
                    c := s[i];
                    if c == {
                        case "n";  append(*builder, "\n");
                        case "r";  append(*builder, "\r");
                        case "t";  append(*builder, "\t");
                        case "b";  append(*builder, "\x08");
                        case "f";  append(*builder, "\x0c");
                        case "\\"; append(*builder, "\\");
                        case "\""; append(*builder, "\"");
                        case "'";  append(*builder, "'");
                        case "`";  append(*builder, "`");
                        case "/";  append(*builder, "/");
                        case;      append(*builder, c);
                    }
                }
            case;
                append(*builder, s[i]);
        }

        i += 1;
    }

    return builder_to_string(*builder);
}

Ast_Kind :: enum {
    PROGRAM;
    VARIABLE_DECLARATION;
    VARIABLE_DECLARATOR;
    BINARY_EXPRESSION;
    LITERAL_NUMBER;
    LITERAL_STRING;
    LITERAL_REGEXP;
    IDENTIFIER;
    FUNCTION_DECLARATION;
    CALL_EXPRESSION;
    EXPRESSION_STATEMENT;
    BLOCK_STATEMENT;
    RETURN_STATEMENT;
    ARRAY_LITERAL;
    MEMBER_EXPRESSION;
    OBJECT_LITERAL;
    NEW_EXPRESSION;
    FUNCTION_EXPRESSION;
    ASSIGNMENT_EXPRESSION;
    IF_STATEMENT;
    THROW_STATEMENT;
    WHILE_STATEMENT;
    FOR_STATEMENT;
    UNARY_EXPRESSION;
    YIELD_EXPRESSION;
    AWAIT_EXPRESSION;
    THIS_EXPRESSION;
    IMPORT_STATEMENT;
    IMPORT_EXPRESSION;
    EXPORT_STATEMENT;
    TRY_STATEMENT;
    FOR_OF_STATEMENT;
    FOR_IN_STATEMENT;
    BREAK_STATEMENT;
    CONTINUE_STATEMENT;
    UPDATE_EXPRESSION;
    LOGICAL_EXPRESSION;
    SWITCH_STATEMENT;
    CASE_CLAUSE;
    ARROW_FUNCTION_EXPRESSION;
    CONDITIONAL_EXPRESSION;
    TEMPLATE_LITERAL;
    SPREAD_ELEMENT;
    CLASS_DECLARATION;
    CLASS_EXPRESSION;
    CLASS_BODY;
    METHOD_DEFINITION;
    SUPER_EXPRESSION;
}

Ast_Spread_Element :: struct {
    using base: Ast_Node;
    argument: *Ast_Node;
}

Ast_Node :: struct {
    kind:   Ast_Kind;
    line:   int;
    column: int;
}

Ast_Template_Literal :: struct {
    using base: Ast_Node;
    quasis:      [..] string;
    expressions: [..] *Ast_Node;
}

Ast_Conditional_Expression :: struct {
    using base: Ast_Node;

    test:       *Ast_Node;
    consequent: *Ast_Node;
    alternate:  *Ast_Node;
}

Ast_Break_Statement :: struct {
    using base: Ast_Node;
}

Ast_Continue_Statement :: struct {
    using base: Ast_Node;
}

Ast_Program :: struct {
    using node: Ast_Node;

    statements: [..] *Ast_Node;

    has_error: bool;
    error_message: string;
}

Ast_If_Statement :: struct {
    using base: Ast_Node;

    condition:   *Ast_Node;
    then_branch: *Ast_Node;
    else_branch: *Ast_Node;
}

Ast_While_Statement :: struct {
    using base: Ast_Node;

    condition: *Ast_Node;
    body:      *Ast_Node;
}

Ast_For_Statement :: struct {
    using base: Ast_Node;

    init:      *Ast_Node;
    condition: *Ast_Node;
    update:    *Ast_Node;
    body:      *Ast_Node;
}

Ast_For_Of_Statement :: struct {
    using base: Ast_Node;

    left:  *Ast_Node;
    right: *Ast_Node;
    body:  *Ast_Node;
}

Ast_For_In_Statement :: struct {
    using base: Ast_Node;

    left:  *Ast_Node;
    right: *Ast_Node;
    body:  *Ast_Node;
}

Ast_Throw_Statement :: struct {
    using base: Ast_Node;

    argument: *Ast_Node;
}

Ast_Variable_Declarator :: struct {
    using base: Ast_Node;

    identifier:       *Ast_Node;
    init:             *Ast_Node;
}

Ast_Variable_Declaration :: struct {
    using base: Ast_Node;

    declaration_type: string;
    declarations:     [..] *Ast_Variable_Declarator;
}

Ast_Binary_Expression :: struct {
    using base: Ast_Node;

    left:  *Ast_Node;
    right: *Ast_Node;

    op: string;
}

Ast_Literal_Number :: struct {
    using base: Ast_Node;

    value: float64;
    text:  string;
}

Ast_Literal_String :: struct {
    using #as base: Ast_Node;

    value: string;
}

Ast_Literal_RegExp :: struct {
    using #as base: Ast_Node;

    pattern: string;
    flags: string;
}

Ast_Identifier :: struct {
    using base: Ast_Node;

    name: string;
}

Ast_Array_Literal :: struct {
    using base: Ast_Node;

    elements: [..] *Ast_Node;
}

Ast_Object_Property :: struct {
    key:   string;
    value: *Ast_Node;
    is_spread: bool;
}

Ast_Object_Literal :: struct {
    using base: Ast_Node;

    properties: [..] Ast_Object_Property;
}

Ast_Member_Expression :: struct {
    using base: Ast_Node;

    object:   *Ast_Node;
    property: *Ast_Node;

    computed: bool;
}

Ast_Function_Declaration :: struct {
    using base: Ast_Node;
    identifier: *Ast_Identifier;

    parameters: [..] *Ast_Node;
    body:       *Ast_Block_Statement;

    is_generator: bool;
    is_async:     bool;
}

Ast_Call_Expression :: struct {
    using base: Ast_Node;

    callee:    *Ast_Node;
    arguments: [..] *Ast_Node;
}

Ast_New_Expression :: struct {
    using base: Ast_Node;

    callee:    *Ast_Node;
    arguments: [..] *Ast_Node;
}

Ast_Function_Expression :: struct {
    using base: Ast_Node;

    parameters: [..] *Ast_Node;
    body:       *Ast_Block_Statement;

    is_generator: bool;
    is_async:     bool;
}

Ast_Arrow_Function_Expression :: struct {
    using base: Ast_Node;

    parameters: [..] *Ast_Node;
    body:       *Ast_Node;

    is_async: bool;
}

Ast_Assignment_Expression :: struct {
    using base: Ast_Node;

    left:  *Ast_Node;
    right: *Ast_Node;

    op: string;
}

Ast_Block_Statement :: struct {
    using base: Ast_Node;

    body: [..] *Ast_Node;
}

Ast_Expression_Statement :: struct {
    using base: Ast_Node;

    expression: *Ast_Node;
}

Ast_Return_Statement :: struct {
    using base: Ast_Node;

    argument: *Ast_Node;
}

Import_Specifier :: struct {
    imported: *Ast_Identifier;
    local:    *Ast_Identifier;
}

Ast_Import_Statement :: struct {
    using base: Ast_Node;

    source:           *Ast_Literal_String;
    specifiers:       [..] Import_Specifier;
    default_import:   *Ast_Identifier;
    namespace_import: *Ast_Identifier;
}

Ast_Import_Expression :: struct {
    using base: Ast_Node;

    argument: *Ast_Node;
}

Export_Specifier :: struct {
    local:    *Ast_Identifier;
    exported: *Ast_Identifier;
}

Ast_Export_Statement :: struct {
    using base: Ast_Node;

    declaration: *Ast_Node;
    is_default:  bool;
    specifiers:  [..] Export_Specifier;
    source:      *Ast_Literal_String;
}

Ast_Try_Statement :: struct {
    using base: Ast_Node;

    try_block:    *Ast_Block_Statement;
    catch_block:  *Ast_Block_Statement;
    finally_block: *Ast_Block_Statement;

    catch_parameter: *Ast_Identifier;
}

Ast_Switch_Case :: struct {
    using base: Ast_Node;

    test:       *Ast_Node;
    consequent: [..] *Ast_Node;
}

Ast_Switch_Statement :: struct {
    using base: Ast_Node;

    discriminant: *Ast_Node;
    cases:        [..] *Ast_Switch_Case;
}

Ast_Unary_Expression :: struct {
    using base: Ast_Node;

    op:    string;
    right: *Ast_Node;
}

Ast_Yield_Expression :: struct {
    using base: Ast_Node;
    argument: *Ast_Node;
}

Ast_Update_Expression :: struct {
    using base: Ast_Node;
    op:      string;
    argument: *Ast_Node;
    prefix:   bool;
}

Ast_Logical_Expression :: struct {
    using base: Ast_Node;
    left:  *Ast_Node;
    right: *Ast_Node;
    op:    string;
}

Ast_Class_Declaration :: struct {
    using base: Ast_Node;

    identifier:  *Ast_Node;
    super_class: *Ast_Node;
    body: *Ast_Class_Body;
}

Ast_Class_Expression :: struct {
    using base: Ast_Node;

    identifier:  *Ast_Node;
    super_class: *Ast_Node;
    body:        *Ast_Class_Body;
}

Ast_Class_Body :: struct {
    using base: Ast_Node;

    body: [..] *Ast_Method_Definition;
}

Ast_Method_Kind :: enum {
    CONSTRUCTOR;
    METHOD;
}

Ast_Method_Definition :: struct {
    using base: Ast_Node;

    key:   *Ast_Node;
    value: *Ast_Node;

    method_kind: Ast_Method_Kind;

    is_static: bool;
}

Ast_Super_Expression :: struct {
    using base: Ast_Node;
}