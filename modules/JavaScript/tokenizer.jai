add_token :: inline (tokens: *[..] Token, type: Token_Type, data: *u8, length: int, line: int, column: int) {
    token := Token.{
        type       = type,
        text.data  = data,
        text.count = length,
        line       = line,
        column     = column,
    };

    array_add(tokens, token);
}

tokenize :: (code: string) -> error: bool, error_message: string, [] Token {
    tokens: [..] Token;

    t      := code.data;
    max_t  := t + code.count;

    line   := 1;
    column := 1;

    brace_stack: [..] Brace_Type;
    brace_stack.allocator = temp;

    is_in_template_string := false;

    while t < max_t {
        start_line   := line;
        start_column := column;

        if is_in_template_string {
            start_t := t;

            while t < max_t {
                if t.* == "`" {
                    if t > start_t {
                        add_token(*tokens, .TEMPLATE_PART, start_t, t - start_t, start_line, start_column);
                    }

                    add_token(*tokens, .PUNCTUATION, t, 1, line, column);

                    t      += 1;
                    column += 1;

                    is_in_template_string = false;

                    break;
                } else if t.* == "$" && t + 1 < max_t && (t + 1).* == "{" {
                    if t > start_t {
                        add_token(*tokens, .TEMPLATE_PART, start_t, t - start_t, start_line, start_column);
                    }

                    add_token(*tokens, .PUNCTUATION, t, 2, line, column);

                    t      += 2;
                    column += 2;

                    is_in_template_string = false;

                    array_add(*brace_stack, .TEMPLATE_STRING);

                    break;
                } else if t.* == "\\" && t + 1 < max_t {
                    if (t + 1).* == "\n" {
                        line  += 1;
                        column = 1;
                    } else {
                        column += 2;
                    }

                    t += 2;
                } else {
                    if t.* == "\n" {
                        line  += 1;
                        column = 1;
                    } else {
                        column += 1;
                    }

                    t += 1;
                }
            }

            continue;
        }

        if t.* == "/" {
            if t + 1 < max_t && (t + 1).* == "/" {
                start_t := t;

                t      += 2;
                column += 2;

                while t < max_t && t.* != "\n" {
                    t      += 1;
                    column += 1;
                }

                add_token(*tokens, .COMMENT, start_t, t - start_t, start_line, start_column);

                continue;
            } else if t + 1 < max_t && (t + 1).* == "*" {
                start_t := t;

                t      += 2;
                column += 2;

                while t < max_t {
                    if t.* == "*" && t + 1 < max_t && (t + 1).* == "/" {
                        t      += 2;
                        column += 2;

                        break;
                    }

                    if t.* == "\n" {
                        line  += 1;
                        column = 1;
                    } else {
                        column += 1;
                    }

                    t += 1;
                }

                add_token(*tokens, .COMMENT, start_t, t - start_t, start_line, start_column);

                continue;
            }
        }

        if is_digit(t.*) {
            start_t := t;

            while t < max_t && (is_digit(t.*) || t.* == ".") {
                t      += 1;
                column += 1;
            }

            add_token(*tokens, .NUMBER, start_t, t - start_t, start_line, start_column);

            continue;
        }

        if is_alpha(t.*) || t.* == "_" || t.* == "$" {
            start_t := t;

            while t < max_t && (is_alnum(t.*) || t.* == "_" || t.* == "$") {
                t      += 1;
                column += 1;
            }

            add_token(*tokens, .IDENTIFIER, start_t, t - start_t, start_line, start_column);

            continue;
        }

        if t.* == "\"" || t.* == "'" {
            quote   := t.*;
            start_t := t;

            t      += 1;
            column += 1;

            while t < max_t && t.* != quote {
                if t.* == "\\" && t + 1 < max_t {
                    if (t + 1).* == "\n" {
                        line  += 1;
                        column = 1;
                    } else {
                        column += 2;
                    }

                    t += 2;
                } else {
                    if t.* == "\n" {
                        line  += 1;
                        column = 1;
                    } else {
                        column += 1;
                    }

                    t += 1;
                }
            }

            if t < max_t {
                t      += 1;
                column += 1;
            }

            add_token(*tokens, .STRING, start_t, t - start_t, start_line, start_column);

            continue;
        }

        if t.* == "`" {
            add_token(*tokens, .PUNCTUATION, t, 1, start_line, start_column);

            t      += 1;
            column += 1;

            is_in_template_string = true;

            continue;
        }

        if is_space(t.*) {
            start_t := t;

            while t < max_t && is_space(t.*) {
                if t.* == "\n" {
                    line  += 1;
                    column = 1;
                } else {
                    column += 1;
                }

                t += 1;
            }

            add_token(*tokens, .WHITESPACE, start_t, t - start_t, start_line, start_column);

            continue;
        }

        if t.* == "/" && t + 1 < max_t && (t + 1).* != "*" && (t + 1).* != "/" {
            is_regexp := false;

            last_meaningful_token: *Token = null;
            for < i: 0 .. tokens.count - 1 {
                if tokens[i].type != .WHITESPACE && tokens[i].type != .COMMENT {
                    last_meaningful_token = *tokens[i];
                    break;
                }
            }

            if !last_meaningful_token {
                is_regexp = true;
            } else {
                if last_meaningful_token.type == .OPERATOR {
                    is_regexp = true;
                } else if last_meaningful_token.type == .PUNCTUATION {
                    c := last_meaningful_token.text;
                    if c == "(" || c == "{" || c == "[" || c == ";" || c == "," || c == ":" || c == "?" {
                        is_regexp = true;
                    }
                } else if last_meaningful_token.type == .IDENTIFIER {
                    text := last_meaningful_token.text;
                    if text == "return" || text == "throw" || text == "yield" || text == "typeof" || text == "case" || text == "do" || text == "else" || text == "in" || text == "instanceof" || text == "new" || text == "delete" || text == "void" || text == "await" {
                        is_regexp = true;
                    }
                }
            }

            if is_regexp {
                start_t := t;
                t += 1;
                column += 1;

                while t < max_t && t.* != "/" {
                    if t.* == "\\" && t + 1 < max_t {
                        t += 2;
                        column += 2;
                    } else if t.* == "\n" {
                        break;
                    } else {
                        t += 1;
                        column += 1;
                    }
                }

                if t < max_t && t.* == "/" {
                    t += 1;
                    column += 1;

                    while t < max_t && is_alpha(t.*) {
                        t += 1;
                        column += 1;
                    }

                    add_token(*tokens, .REGEXP, start_t, t - start_t, start_line, start_column);
                    continue;
                } else {
                    t = start_t;
                    column = start_column;
                }
            }
        }

        if t.* == "=" || t.* == "+" || t.* == "-" || t.* == "*" || t.* == "/" || t.* == "!" || t.* == "<" || t.* == ">" || t.* == "&" || t.* == "|" || t.* == "^" || t.* == "%" || t.* == "?" {
            start_t := t;

            t      += 1;
            column += 1;

            while t < max_t && (t.* == "=" || t.* == "+" || t.* == "-" || t.* == "*" || t.* == "&" || t.* == "|" || t.* == ">" || t.* == "<" || t.* == "?") {
                next_text := string.{
                    data  = start_t,
                    count = t - start_t + 1,
                };

                if next_text == "==" || next_text == "===" || next_text == "!=" || next_text == "!==" || next_text == "<=" || next_text == ">=" || next_text == "++" || next_text == "--" || next_text == "&&" || next_text == "||" || next_text == "=>" || next_text == "<<" || next_text == ">>" || next_text == ">>>" || next_text == "+=" || next_text == "-=" || next_text == "*=" || next_text == "/=" || next_text == "**" || next_text == "**=" || next_text == "??" || next_text == "??=" {
                    t      += 1;
                    column += 1;
                } else {
                    break;
                }
            }

            add_token(*tokens, .OPERATOR, start_t, t - start_t, start_line, start_column);

            continue;
        }

        if t.* == "." {
            if t + 1 < max_t && (t + 1).* == "." && t + 2 < max_t && (t + 2).* == "." {
                add_token(*tokens, .PUNCTUATION, t, 3, start_line, start_column);

                t      += 3;
                column += 3;

                continue;
            }
        }

        if is_punctuation(t.*) {
            if t.* == "{" {
                array_add(*brace_stack, .NORMAL);
            } else if t.* == "}" {
                if brace_stack.count > 0 {
                    brace_type := pop(*brace_stack);

                    if brace_type == .TEMPLATE_STRING {
                        add_token(*tokens, .PUNCTUATION, t, 1, start_line, start_column);

                        t      += 1;
                        column += 1;

                        is_in_template_string = true;

                        continue;
                    }
                }
            }

            add_token(*tokens, .PUNCTUATION, t, 1, start_line, start_column);

            t      += 1;
            column += 1;

            continue;
        }

        error_msg := report_tokenization_error(code, t, line, column);

        return true, error_msg, .[];
    }

    return false, "", tokens;
}

report_tokenization_error :: (code: string, t: *u8, line: int, column: int) -> string {
    builder: String_Builder;
    builder.allocator = temp;
    print_to_builder(*builder, "Unknown JavaScript: Tokenization Error at line %, column %: Unknown character '%'\n\n", line, column, t.*);

    line_start_t := t;
    while line_start_t > code.data && (line_start_t - 1).* != "\n" {
        line_start_t -= 1;
    }

    line_end_t := t;
    while line_end_t < code.data + code.count && line_end_t.* != "\n" {
        line_end_t += 1;
    }

    previous_line_start_t: *u8;
    previous_line_end_t:   *u8;

    if line_start_t > code.data {
        previous_line_end_t = line_start_t - 1;
        previous_line_start_t = previous_line_end_t;

        while previous_line_start_t > code.data && (previous_line_start_t - 1).* != "\n" {
            previous_line_start_t -= 1;
        }
    }

    next_line_start_t: *u8;
    next_line_end_t:   *u8;

    if line_end_t < code.data + code.count {
        next_line_start_t = line_end_t + 1;
        next_line_end_t   = next_line_start_t;

        while next_line_end_t < code.data + code.count && next_line_end_t.* != "\n" {
            next_line_end_t += 1;
        }
    }

    if previous_line_start_t {
        text := string.{
            data  = previous_line_start_t,
            count = previous_line_end_t - previous_line_start_t,
        };

        print_to_builder(*builder, "%: %\n", line - 1, text);
    }

    {
        text := string.{
            data  = line_start_t,
            count = line_end_t - line_start_t,
        };

        print_to_builder(*builder, "%: %\n", line, text);
    }

    prefix_length  := 0;
    temporary_line := line;

    if temporary_line == 0 prefix_length = 1;
    else while temporary_line > 0 { temporary_line /= 10; prefix_length += 1; }

    prefix_length += 2;

    for 1..prefix_length + column - 1 print_to_builder(*builder, " ");

    if next_line_start_t {
        text := string.{
            data  = next_line_start_t,
            count = next_line_end_t - next_line_start_t,
        };

        print_to_builder(*builder, "%: %\n", line + 1, text);
    }

    print_to_builder(*builder, "\n");

    return builder_to_string(*builder);
}

is_punctuation :: (c: u8) -> bool {
    return c == "(" || c == ")" || c == "{" || c == "}" ||
           c == "[" || c == "]" || c == ";" || c == "," ||
           c == "." || c == ":" || c == "?";
}

Brace_Type :: enum {
    NORMAL;
    TEMPLATE_STRING;
}

Token_Type :: enum {
    IDENTIFIER;
    NUMBER;
    STRING;
    REGEXP;
    OPERATOR;
    PUNCTUATION;
    WHITESPACE;
    COMMENT;
    TEMPLATE_PART;
}

Token :: struct {
    type:   Token_Type;
    text:   string;
    line:   int;
    column: int;
}
