init_vm_json :: (vm: *Vm) {
    found, json_global_index := get_global_index(vm, "JSON");

    if found {
        json_obj := allocate_object(vm);

        vm.current_realm.globals[json_global_index].type   = .OBJECT;
        vm.current_realm.globals[json_global_index].object = json_obj;

        add_static_method(vm, json_obj, "stringify", json_stringify);
        add_static_method(vm, json_obj, "parse",     json_parse);
    }
}

json_stringify :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .UNDEFINED };

    builder: String_Builder;
    builder.allocator = temp;

    success := json_stringify_recursive(vm, *builder, arguments[0]);

    if !success return .{ type = .UNDEFINED };

    result := builder_to_string(*builder);

    array_add(*vm.allocated_strings, result);

    return .{ type = .STRING, s = result };
}

json_stringify_recursive :: (vm: *Vm, builder: *String_Builder, value: Value) -> bool {
    if value.type == {
        case .UNDEFINED;
            return false;

        case .NULL;
            append(builder, "null");

        case .BOOLEAN;
            append(builder, ifx value.boolean "true" else "false");

        case .NUMBER;
            if (value.number != value.number) || (value.number == positive_infinity_value) || (value.number == negative_infinity_value) {
                append(builder, "null");
            } else {
                print_item_to_builder(builder, value.number);
            }

        case .STRING;
            append(builder, "\"");

            for 0..value.s.count - 1 {
                c := value.s[it];

                if c == {
                    case "\""; append(builder, "\\\"");
                    case "\\"; append(builder, "\\\\");
                    case "\n"; append(builder, "\\n");
                    case "\r"; append(builder, "\\r");
                    case "\t"; append(builder, "\\t");
                    case;
                        if c < 32 print_to_builder(builder, "\\u00%", formatInt(c, base=16, minimum_digits=2));
                        else      append(builder, c);
                }
            }

            append(builder, "\"");

        case .ARRAY;
            append(builder, "[");

            object := value.object;

            for object.elements {
                if it_index > 0 append(builder, ",");

                if it.type == .UNDEFINED || it.type == .FUNCTION || it.type == .NATIVE_FUNCTION {
                    append(builder, "null");
                } else {
                    json_stringify_recursive(vm, builder, it);
                }
            }

            append(builder, "]");

        case .OBJECT;
            append(builder, "{");

            object := value.object;
            first  := true;

            for object.elements {
                if it.type == .UNDEFINED || it.type == .FUNCTION || it.type == .NATIVE_FUNCTION continue;

                if !first append(builder, ",");

                first = false;

                append(builder, "\"");
                append(builder, tprint("%", it_index));
                append(builder, "\":");

                json_stringify_recursive(vm, builder, it);
            }

            if object.shape {
                for object.shape.property_names {
                    offset_pointer := table_find_pointer(*object.shape.property_offsets, it);

                    if !offset_pointer || offset_pointer.* >= object.fields.count continue;

                    property_value := object.fields[offset_pointer.*];

                    if property_value.type == .UNDEFINED || property_value.type == .FUNCTION || property_value.type == .NATIVE_FUNCTION continue;

                    if !first append(builder, ",");

                    first = false;

                    append(builder, "\"");
                    append(builder, it);
                    append(builder, "\":");

                    json_stringify_recursive(vm, builder, property_value);
                }
            }

            append(builder, "}");

        case .FUNCTION; #through;
        case .NATIVE_FUNCTION;
            return false;

        case .GENERATOR;
            return false;
    }

    return true;
}

json_parse :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if arguments.count == 0 return .{ type = .UNDEFINED };

    json_string := value_to_string(vm, arguments[0]);

    error, error_msg, tokens := tokenize(json_string,, temp);
    if error return .{ type = .UNDEFINED };

    parser := Json_Parser.{
        tokens = tokens,
        index  = 0,
    };

    result, success := parse_json_value(vm, *parser);
    if !success return .{ type = .UNDEFINED };

    return result;
}

parse_json_value :: (vm: *Vm, parser: *Json_Parser) -> Value, bool {
    skip_json_whitespace(parser);

    if parser.index >= parser.tokens.count return .{}, false;

    token := parser.tokens[parser.index];

    parser.index += 1;

    if token.type == {
        case .NUMBER;
            value := Value.{
                type   = .NUMBER,
                number = string_to_float64(token.text),
            };

            return value, true;

        case .STRING;
            value := Value.{
                type = .STRING,
            };

            inner := slice(token.text, 1, token.text.count - 2);

            value.s = unescape_json_string(vm, inner);

            return value, true;

        case .IDENTIFIER;
            if token.text == {
                case "true";  return .{ type = .BOOLEAN, boolean = true },  true;
                case "false"; return .{ type = .BOOLEAN, boolean = false }, true;
                case "null";  return .{ type = .NULL },                     true;
            }

            return .{}, false;

        case .PUNCTUATION;
            if token.text == "[" {
                array_object           := allocate_object(vm);
                array_object.kind       = .ARRAY;
                array_object.prototype  = vm.array_prototype;

                skip_json_whitespace(parser);

                if parser.index < parser.tokens.count && parser.tokens[parser.index].text == "]" {
                    parser.index += 1;
                    return .{ type = .ARRAY, object = array_object }, true;
                }

                while true {
                    element, success := parse_json_value(vm, parser);

                    if !success return .{}, false;

                    array_add(*array_object.elements, element);

                    skip_json_whitespace(parser);

                    if parser.index >= parser.tokens.count return .{}, false;

                    next := parser.tokens[parser.index];

                    if next.text == "]" {
                        parser.index += 1;
                        break;
                    } else if next.text == "," {
                        parser.index += 1;
                    } else {
                        return .{}, false;
                    }
                }

                return .{ type = .ARRAY, object = array_object }, true;

            } else if token.text == "{" {
                object := allocate_object(vm);

                skip_json_whitespace(parser);

                if parser.index < parser.tokens.count && parser.tokens[parser.index].text == "}" {
                    parser.index += 1;
                    return .{ type = .OBJECT, object = object }, true;
                }

                while true {
                    skip_json_whitespace(parser);

                    if parser.index >= parser.tokens.count return .{}, false;

                    key_token := parser.tokens[parser.index];

                    parser.index += 1;

                    key: string;

                    if key_token.type == .STRING {
                        key = slice(key_token.text, 1, key_token.text.count - 2);
                        key = unescape_json_string(vm, key);
                    } else if key_token.type == .IDENTIFIER {
                        key = key_token.text;
                    } else {
                        return .{}, false;
                    }

                    skip_json_whitespace(parser);

                    if parser.index >= parser.tokens.count || parser.tokens[parser.index].text != ":" return .{}, false;

                    parser.index += 1;

                    value, success := parse_json_value(vm, parser);
                    if !success return .{}, false;

                    set_object_property(vm, object, key, value);

                    skip_json_whitespace(parser);

                    if parser.index >= parser.tokens.count return .{}, false;

                    next := parser.tokens[parser.index];

                    if next.text == "}" {
                        parser.index += 1;
                        break;
                    } else if next.text == "," {
                        parser.index += 1;
                    } else {
                        return .{}, false;
                    }
                }

                return .{ type = .OBJECT, object = object }, true;
            }
    }

    return .{}, false;
}

skip_json_whitespace :: (parser: *Json_Parser) {
    while parser.index < parser.tokens.count {
        t := parser.tokens[parser.index];

        if t.type == .WHITESPACE || t.type == .COMMENT {
            parser.index += 1;
        } else {
            break;
        }
    }
}

unescape_json_string :: (vm: *Vm, s: string) -> string {
    if !contains(s, "\\") return s;

    builder: String_Builder;
    builder.allocator = temp;

    t     := s.data;
    max_t := t + s.count;

    while t < max_t {
        if t.* == {
            case #char "\\";
                if t + 1 < max_t {
                    t += 1;

                    if t.* == {
                        case #char "n";  append(*builder, "\n");
                        case #char "r";  append(*builder, "\r");
                        case #char "t";  append(*builder, "\t");
                        case #char "b";  append(*builder, "\x08");
                        case #char "f";  append(*builder, "\x0c");
                        case #char "\\"; append(*builder, "\\");
                        case #char "\""; append(*builder, "\"");
                        case #char "/";  append(*builder, "/");
                        case #char "u";  append(*builder, "\\u");
                        case;            append(*builder, t.*);
                    }
                }

            case;
                append(*builder, t.*);
        }

        t += 1;
    }

    result := builder_to_string(*builder);

    array_add(*vm.allocated_strings, result);

    return result;
}

Json_Parser :: struct {
    tokens: [] Token;
    index:  int;
}