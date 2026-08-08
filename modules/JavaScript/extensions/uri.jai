init_vm_uri :: (vm: *Vm) {
    init_global_uri_fn(vm, "decodeURI",          uri_decode_uri);
    init_global_uri_fn(vm, "decodeURIComponent", uri_decode_uri_component);
    init_global_uri_fn(vm, "encodeURI",          uri_encode_uri);
    init_global_uri_fn(vm, "encodeURIComponent", uri_encode_uri_component);
}

init_global_uri_fn :: (vm: *Vm, name: string, fn: Native_Function) {
    found, index := get_global_index(vm, name);
    if found {
        obj := allocate_object(vm);
        obj.prototype = vm.function_prototype;
        obj.is_not_constructor = true;
        set_object_property(vm, obj, "name", Value.{ type = .STRING, s = name });
        set_object_property(vm, obj, "length", Value.{ type = .NUMBER, number = 1.0 });

        vm.current_realm.globals[index] = Value.{
            type = .NATIVE_FUNCTION,
            native_function = fn,
            object = obj,
        };
    }
}

uri_decode_uri :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if is_new {
        throw_exception(vm, "TypeError: decodeURI is not a constructor");
        return .{};
    }
    reserved_set := ";/?:@&=+$,#";
    return decode_uri_common(vm, arguments, reserved_set, false);
}

uri_decode_uri_component :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if is_new {
        throw_exception(vm, "TypeError: decodeURIComponent is not a constructor");
        return .{};
    }
    return decode_uri_common(vm, arguments, "", true);
}

uri_encode_uri :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if is_new {
        throw_exception(vm, "TypeError: encodeURI is not a constructor");
        return .{};
    }
    return encode_uri_common(vm, arguments, false);
}

uri_encode_uri_component :: (vm: *Vm, this: Value, arguments: [] Value, is_new: bool) -> Value {
    if is_new {
        throw_exception(vm, "TypeError: encodeURIComponent is not a constructor");
        return .{};
    }
    return encode_uri_common(vm, arguments, true);
}

append_utf8_cp :: (builder: *String_Builder, cp: u32) {
    if cp < 0x80 {
        append(builder, cast(u8) cp);
    } else if cp < 0x800 {
        append(builder, cast(u8) (0xC0 | (cp >> 6)));
        append(builder, cast(u8) (0x80 | (cp & 0x3F)));
    } else if cp < 0x10000 {
        append(builder, cast(u8) (0xE0 | (cp >> 12)));
        append(builder, cast(u8) (0x80 | ((cp >> 6) & 0x3F)));
        append(builder, cast(u8) (0x80 | (cp & 0x3F)));
    } else if cp <= 0x10FFFF {
        append(builder, cast(u8) (0xF0 | (cp >> 18)));
        append(builder, cast(u8) (0x80 | ((cp >> 12) & 0x3F)));
        append(builder, cast(u8) (0x80 | ((cp >> 6) & 0x3F)));
        append(builder, cast(u8) (0x80 | (cp & 0x3F)));
    }
}

#scope_file

hex_digit_val :: (c: u8) -> int {
    if c >= #char "0" && c <= #char "9" return c - #char "0";
    if c >= #char "A" && c <= #char "F" return c - #char "A" + 10;
    if c >= #char "a" && c <= #char "f" return c - #char "a" + 10;
    return -1;
}

to_hex_digit :: (v: int) -> u8 {
    if v >= 0 && v <= 9 return cast(u8) (#char "0" + v);
    if v >= 10 && v <= 15 return cast(u8) (#char "A" + (v - 10));
    return #char "0";
}

decode_uri_common :: (vm: *Vm, arguments: [] Value, reserved_set: string, is_component: bool) -> Value {
    if arguments.count == 0 return .{ type = .STRING, s = "undefined" };

    uri_str := abstract_to_string(vm, arguments[0]);
    if vm.has_exception return .{};

    builder: String_Builder;
    i := 0;
    n := uri_str.count;

    while i < n {
        c := uri_str[i];
        if c != #char "%" {
            append(*builder, c);
            i += 1;
            continue;
        }

        if i + 2 >= n {
            throw_exception(vm, "URIError: URI malformed");
            free_buffers(*builder);
            return .{};
        }

        h1 := hex_digit_val(uri_str[i+1]);
        h2 := hex_digit_val(uri_str[i+2]);
        if h1 < 0 || h2 < 0 {
            throw_exception(vm, "URIError: URI malformed");
            free_buffers(*builder);
            return .{};
        }

        b1 := (h1 << 4) | h2;
        i += 3;

        if (b1 & 0x80) == 0 {
            ch := cast(u8) b1;
            if !is_component && find_index_from_left(reserved_set, ch) >= 0 {
                append(*builder, uri_str[i-3]);
                append(*builder, uri_str[i-2]);
                append(*builder, uri_str[i-1]);
            } else {
                append(*builder, ch);
            }
        } else {
            needed: int;
            min_val: u32;
            if (b1 & 0xE0) == 0xC0 {
                needed = 2;
                min_val = 0x80;
            } else if (b1 & 0xF0) == 0xE0 {
                needed = 3;
                min_val = 0x800;
            } else if (b1 & 0xF8) == 0xF0 {
                needed = 4;
                min_val = 0x10000;
            } else {
                throw_exception(vm, "URIError: URI malformed");
                free_buffers(*builder);
                return .{};
            }

            bytes: [4] u8;
            bytes[0] = cast(u8) b1;

            for k: 1..needed-1 {
                if i + 2 >= n || uri_str[i] != #char "%" {
                    throw_exception(vm, "URIError: URI malformed");
                    free_buffers(*builder);
                    return .{};
                }
                kh1 := hex_digit_val(uri_str[i+1]);
                kh2 := hex_digit_val(uri_str[i+2]);
                if kh1 < 0 || kh2 < 0 {
                    throw_exception(vm, "URIError: URI malformed");
                    free_buffers(*builder);
                    return .{};
                }
                bk := (kh1 << 4) | kh2;
                if (bk & 0xC0) != 0x80 {
                    throw_exception(vm, "URIError: URI malformed");
                    free_buffers(*builder);
                    return .{};
                }
                if k == 1 {
                    if b1 == 0xF0 && bk < 0x90 {
                        throw_exception(vm, "URIError: URI malformed");
                        free_buffers(*builder);
                        return .{};
                    }
                    if b1 == 0xF4 && bk > 0x8F {
                        throw_exception(vm, "URIError: URI malformed");
                        free_buffers(*builder);
                        return .{};
                    }
                }
                bytes[k] = cast(u8) bk;
                i += 3;
            }

            cp: u32 = 0;
            if needed == 2 {
                cp = ((cast(u32) bytes[0] & 0x1F) << 6) | (cast(u32) bytes[1] & 0x3F);
            } else if needed == 3 {
                cp = ((cast(u32) bytes[0] & 0x0F) << 12) | ((cast(u32) bytes[1] & 0x3F) << 6) | (cast(u32) bytes[2] & 0x3F);
            } else if needed == 4 {
                cp = ((cast(u32) bytes[0] & 0x07) << 18) | ((cast(u32) bytes[1] & 0x3F) << 12) | ((cast(u32) bytes[2] & 0x3F) << 6) | (cast(u32) bytes[3] & 0x3F);
            }

            if cp < min_val || cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF) {
                throw_exception(vm, "URIError: URI malformed");
                free_buffers(*builder);
                return .{};
            }

            if cp < 0x10000 {
                append_utf8_cp(*builder, cp);
            } else {
                v := cp - 0x10000;
                h := 0xD800 + (v >> 10);
                l := 0xDC00 + (v & 0x03FF);
                append_utf8_cp(*builder, h);
                append_utf8_cp(*builder, l);
            }
        }
    }

    res := allocate_string_from_builder(vm, *builder);
    free_buffers(*builder);
    return .{ type = .STRING, s = res };
}

is_uri_unescaped :: (c: u8, is_component: bool) -> bool {
    if (c >= #char "A" && c <= #char "Z") || (c >= #char "a" && c <= #char "z") || (c >= #char "0" && c <= #char "9") return true;
    if c == #char "-" || c == #char "_" || c == #char "." || c == #char "!" || c == #char "~" || c == #char "*" || c == #char "'" || c == #char "(" || c == #char ")" return true;
    if !is_component {
        if c == #char ";" || c == #char "/" || c == #char "?" || c == #char ":" || c == #char "@" || c == #char "&" || c == #char "=" || c == #char "+" || c == #char "$" || c == #char "," || c == #char "#" return true;
    }
    return false;
}

encode_uri_common :: (vm: *Vm, arguments: [] Value, is_component: bool) -> Value {
    if arguments.count == 0 return .{ type = .STRING, s = "undefined" };

    uri_str := abstract_to_string(vm, arguments[0]);
    if vm.has_exception return .{};

    builder: String_Builder;
    i := 0;
    n := uri_str.count;

    while i < n {
        c := uri_str[i];
        if (c & 0x80) == 0 {
            if is_uri_unescaped(c, is_component) {
                append(*builder, c);
            } else {
                append(*builder, #char "%");
                append(*builder, to_hex_digit((c >> 4) & 0xF));
                append(*builder, to_hex_digit(c & 0xF));
            }
            i += 1;
        } else {
            needed := 0;
            if (c & 0xE0) == 0xC0 needed = 2;
            else if (c & 0xF0) == 0xE0 needed = 3;
            else if (c & 0xF8) == 0xF0 needed = 4;

            if needed == 0 || i + needed > n {
                throw_exception(vm, "URIError: URI malformed");
                free_buffers(*builder);
                return .{};
            }

            for k: 1..needed-1 {
                if (uri_str[i + k] & 0xC0) != 0x80 {
                    throw_exception(vm, "URIError: URI malformed");
                    free_buffers(*builder);
                    return .{};
                }
            }

            if needed == 2 {
                cp := ((cast(u32)(uri_str[i] & 0x1F)) << 6) | (cast(u32)(uri_str[i + 1] & 0x3F));
                if cp < 0x80 {
                    throw_exception(vm, "URIError: URI malformed");
                    free_buffers(*builder);
                    return .{};
                }
            } else if needed == 3 {
                b1 := cast(u32) uri_str[i];
                b2 := cast(u32) uri_str[i + 1];
                b3 := cast(u32) uri_str[i + 2];
                cp := ((b1 & 0x0F) << 12) | ((b2 & 0x3F) << 6) | (b3 & 0x3F);

                if cp < 0x800 {
                    throw_exception(vm, "URIError: URI malformed");
                    free_buffers(*builder);
                    return .{};
                }

                if cp >= 0xD800 && cp <= 0xDBFF {
                    if i + 6 > n {
                        throw_exception(vm, "URIError: URI malformed");
                        free_buffers(*builder);
                        return .{};
                    }
                    nb1 := cast(u32) uri_str[i + 3];
                    nb2 := cast(u32) uri_str[i + 4];
                    nb3 := cast(u32) uri_str[i + 5];
                    if (nb1 & 0xF0) != 0xE0 || (nb2 & 0xC0) != 0x80 || (nb3 & 0xC0) != 0x80 {
                        throw_exception(vm, "URIError: URI malformed");
                        free_buffers(*builder);
                        return .{};
                    }
                    cp2 := ((nb1 & 0x0F) << 12) | ((nb2 & 0x3F) << 6) | (nb3 & 0x3F);
                    if cp2 < 0xDC00 || cp2 > 0xDFFF {
                        throw_exception(vm, "URIError: URI malformed");
                        free_buffers(*builder);
                        return .{};
                    }

                    v := (cp - 0xD800) * 0x400 + (cp2 - 0xDC00) + 0x10000;
                    ub1 := cast(u8) (0xF0 | (v >> 18));
                    ub2 := cast(u8) (0x80 | ((v >> 12) & 0x3F));
                    ub3 := cast(u8) (0x80 | ((v >> 6) & 0x3F));
                    ub4 := cast(u8) (0x80 | (v & 0x3F));

                    append(*builder, #char "%");
                    append(*builder, to_hex_digit((ub1 >> 4) & 0xF));
                    append(*builder, to_hex_digit(ub1 & 0xF));
                    append(*builder, #char "%");
                    append(*builder, to_hex_digit((ub2 >> 4) & 0xF));
                    append(*builder, to_hex_digit(ub2 & 0xF));
                    append(*builder, #char "%");
                    append(*builder, to_hex_digit((ub3 >> 4) & 0xF));
                    append(*builder, to_hex_digit(ub3 & 0xF));
                    append(*builder, #char "%");
                    append(*builder, to_hex_digit((ub4 >> 4) & 0xF));
                    append(*builder, to_hex_digit(ub4 & 0xF));

                    i += 6;
                    continue;
                } else if cp >= 0xDC00 && cp <= 0xDFFF {
                    throw_exception(vm, "URIError: URI malformed");
                    free_buffers(*builder);
                    return .{};
                }
            } else if needed == 4 {
                b1 := cast(u32) uri_str[i];
                b2 := cast(u32) uri_str[i + 1];
                b3 := cast(u32) uri_str[i + 2];
                b4 := cast(u32) uri_str[i + 3];
                cp := ((b1 & 0x07) << 18) | ((b2 & 0x3F) << 12) | ((b3 & 0x3F) << 6) | (b4 & 0x3F);
                if cp < 0x10000 || cp > 0x10FFFF {
                    throw_exception(vm, "URIError: URI malformed");
                    free_buffers(*builder);
                    return .{};
                }
            }

            for k: 0..needed-1 {
                b := uri_str[i + k];
                append(*builder, #char "%");
                append(*builder, to_hex_digit((b >> 4) & 0xF));
                append(*builder, to_hex_digit(b & 0xF));
            }
            i += needed;
        }
    }

    res := allocate_string_from_builder(vm, *builder);
    free_buffers(*builder);
    return .{ type = .STRING, s = res };
}
