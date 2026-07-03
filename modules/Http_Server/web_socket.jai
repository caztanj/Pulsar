web_socket_upgrade :: (server: *Http_Server, request: Http_Request) -> error: bool {
    error, upgrade_value := get_header(request.headers, "Upgrade");
    if error || !equal_nocase(upgrade_value, "websocket") return true;

    error=, connection_value := get_header(request.headers, "Connection");
    if error return true;

    found_upgrade := false;
    remainder     := connection_value;

    while remainder.count > 0 {
        token, rest := break_by_spaces(trim_left(remainder, chars=" ,\t"));
        token = trim(token, chars=" ,\t");
        if equal_nocase(token, "Upgrade") found_upgrade = true;
        remainder = rest;
    }

    if !found_upgrade return true;

    error=, key := get_header(request.headers, "Sec-WebSocket-Key");
    if error || key.count == 0 return true;

    error=, version := get_header(request.headers, "Sec-WebSocket-Version");
    if error || version != "13" return true;

    accept_key := web_socket_get_accept_key(key);

    b: String_Builder;
    b.allocator = temp;

    append(*b, "HTTP/1.1 101 Switching Protocols\r\n");
    append(*b, "Upgrade: websocket\r\n");
    append(*b, "Connection: Upgrade\r\n");
    print_to_builder(*b, "Sec-WebSocket-Accept: %\r\n", accept_key);
    append(*b, "\r\n");

    serialized := builder_to_string(*b,, temp);

    client := find_client(server, request.client_id);
    if client == null return true;

    array_add(*client.send_buffer, ..serialized.([] u8));

    client.type              = .Web_Socket;
    client.ws_partial_opcode = 0;

    send_to_client(server, request.client_id);

    return false;
}

web_socket_send :: (server: *Http_Server, client_id: Socket.Socket, data: string, opcode: Web_Socket_Opcode = .TEXT) -> error: bool {
    client := find_client(server, client_id);
    if client == null || client.type != .Web_Socket return true;

    web_socket_write_frame(*client.send_buffer, opcode, data, fin = true);

    return send_to_client(server, client_id);
}

web_socket_send_ping :: (server: *Http_Server, client_id: Socket.Socket) -> error: bool {
    return web_socket_send(server, client_id, "", .PING);
}

web_socket_close :: (server: *Http_Server, client_id: Socket.Socket, code: Web_Socket_Status_Code = .NORMAL_CLOSURE) {
    client := find_client(server, client_id);
    if client == null return;

    c := cast(u16) code;

    payload: [2] u8;
    payload[0] = xx (c >> 8);
    payload[1] = xx (c & 0xff);

    s := string.{ data = payload.data, count = 2 };

    web_socket_write_frame(*client.send_buffer, .CLOSE, s, fin = true);
    send_to_client(server, client_id);
    close(server, client); // @Todo: Shall this be the close after send?
}

#scope_module

web_socket_write_frame :: (buffer: *[..] u8, opcode: Web_Socket_Opcode, data: string, fin: bool) {
    b0: u8 = xx (opcode & 0xF);
    if fin b0 |= 0x80;

    array_add(buffer, b0);

    if data.count <= 125 {
        array_add(buffer, xx data.count);
    } else if data.count <= 0xFFFF {
        array_add(buffer, 126);
        array_add(buffer, xx ((data.count >> 8) & 0xFF));
        array_add(buffer, xx (data.count & 0xFF));
    } else {
        array_add(buffer, 127);
        for < i: 0..7 array_add(buffer, xx ((data.count >> (i * 8)) & 0xFF));
    }

    array_add(buffer, ..data.([] u8));
}

parse_web_socket_frames :: (server: *Http_Server, client_id: Socket.Socket) {
    client := find_client(server, client_id);
    if client == null return;

    t     := client.read_buffer.data;
    max_t := client.read_buffer.data + client.read_buffer.count;

    while t + 2 <= max_t {
        start := t;

        b0 := t.*;
        t += 1;

        b1 := t.*;
        t += 1;

        fin := (b0 & 0x80) != 0;
        rsv := (b0 & 0x70) != 0;

        if rsv {
            web_socket_close(server, client_id, .PROTOCOL_ERROR);
            return;
        }

        raw_opcode := b0 & 0x0F;

        if raw_opcode >= 3 && raw_opcode <= 7 || raw_opcode >= 11 && raw_opcode <= 15 {
            web_socket_close(server, client_id, .PROTOCOL_ERROR);
            return;
        }

        opcode         := cast(Web_Socket_Opcode) raw_opcode;
        masked         := (b1 & 0x80) != 0;
        payload_length := cast(int) (b1 & 0x7F);

        if !masked {
            web_socket_close(server, client_id, .PROTOCOL_ERROR);
            return;
        }

        if raw_opcode >= 8 {
            if !fin || payload_length > 125 {
                web_socket_close(server, client_id, .PROTOCOL_ERROR);
                return;
            }
        }

        if payload_length == 126 {
            if t + 2 > max_t {
                t = start;
                break;
            }

            payload_length = (cast(int) t[0] << 8) | cast(int) t[1];

            t += 2;
        } else if payload_length == 127 {
            if t + 8 > max_t {
                t = start;
                break;
            }

            payload_length = 0;

            for i: 0..7 payload_length = (payload_length << 8) | cast(int) t[i];

            t += 8;
        }

        if payload_length < 0 {
            web_socket_close(server, client_id, .PROTOCOL_ERROR);
            return;
        }

        if client.ws_partial_payload.count + payload_length > MAX_WEB_SOCKET_MESSAGE_SIZE {
            web_socket_close(server, client_id, .MESSAGE_TOO_BIG);
            return;
        }

        masking_key: [4] u8;

        if t + 4 > max_t {
            t = start;
            break;
        }

        masking_key[0] = t[0];
        masking_key[1] = t[1];
        masking_key[2] = t[2];
        masking_key[3] = t[3];

        t += 4;

        if t + payload_length > max_t {
            t = start;
            break;
        }

        key64: u64;
        memcpy(*key64, masking_key.data, 4);
        key64 |= (key64 << 32);

        t64_count := payload_length / 8;
        t64       := cast(*u64) t;
        for i: 0..t64_count - 1 {
            t64[i] ^= key64;
        }

        remainder_start := t64_count * 8;
        for i: remainder_start..payload_length - 1 {
            t[i] ^= masking_key[i % 4];
        }

        payload := string.{ data = t, count = payload_length };
        t += payload_length;

        if opcode == {
            case .PING;
                web_socket_send(server, client_id, payload, .PONG);
                continue;
            case .PONG;
                continue;
            case .CLOSE;
                web_socket_close(server, client_id, .NORMAL_CLOSURE);
                return;
        }

        effective_opcode := opcode;
        if opcode == .CONTINUATION {
            if client.ws_partial_opcode == 0 {
                web_socket_close(server, client_id, .PROTOCOL_ERROR);
                return;
            }
            effective_opcode = xx client.ws_partial_opcode;
        } else {
            if client.ws_partial_opcode != 0 {
                web_socket_close(server, client_id, .PROTOCOL_ERROR);
                return;
            }
            client.ws_partial_opcode = xx opcode;
            array_reset(*client.ws_partial_payload);
        }

        array_add(*client.ws_partial_payload, ..payload.([] u8));

        if fin {
            message: Web_Socket_Message;
            message.client_id = client_id;
            message.opcode    = effective_opcode;

            assembled := string.{ data = client.ws_partial_payload.data, count = client.ws_partial_payload.count };

            if effective_opcode == .TEXT {
                t     := assembled.data;
                max_t := assembled.data + assembled.count;

                is_valid_utf8 := true;

                while t < max_t {
                    character, bytes, status := character_utf8_to_utf32(t, max_t - t);
                    if status != .CONVERSION_OK {
                        is_valid_utf8 = false;
                        break;
                    }

                    t += bytes;
                }

                if !is_valid_utf8 {
                    web_socket_close(server, client_id, .INVALID_FRAME_PAYLOAD_DATA);
                    return;
                }
            }

            message.data = copy_temporary_string(assembled);

            array_add(*server.events, .{ type = .Web_Socket_Message, web_socket_message = message });
            array_reset(*client.ws_partial_payload);
            client.ws_partial_opcode = 0;
        }
    }

    consumed  := t - client.read_buffer.data;
    remaining := client.read_buffer.count - consumed;

    if remaining > 0 memcpy(client.read_buffer.data, t, remaining);

    client.read_buffer.count = remaining;
}

web_socket_get_accept_key :: (client_key: string) -> string {
    combined := join(client_key, WEB_SOCKET_MAGIC,, temp);

    hash: [20] u8;
    LibreSSL.SHA1(combined.data, xx combined.count, hash.data);

    return base64_encode(xx hash);
}

break_by_spaces :: (line: string) -> (left: string, right: string) {
    left  := line;
    right := eat_until_space(line);
    left.count -= right.count;

    right = eat_spaces(right);

    return left, right;
}

#scope_export

Web_Socket_Opcode :: enum u8 {
    CONTINUATION :: 0x0;
    TEXT         :: 0x1;
    BINARY       :: 0x2;
    CLOSE        :: 0x8;
    PING         :: 0x9;
    PONG         :: 0xa;
}

Web_Socket_Message :: struct {
    client_id: Socket.Socket;
    opcode:    Web_Socket_Opcode;
    data:      string;
}

Web_Socket_Status_Code :: enum u16 {
    NORMAL_CLOSURE             :: 1000;
    GOING_AWAY                 :: 1001;
    PROTOCOL_ERROR             :: 1002;
    UNSUPPORTED_DATA           :: 1003;
    NO_STATUS_RECEIVED         :: 1005;
    ABNORMAL_CLOSURE           :: 1006;
    INVALID_FRAME_PAYLOAD_DATA :: 1007;
    POLICY_VIOLATION           :: 1008;
    MESSAGE_TOO_BIG            :: 1009;
    MANDATORY_EXTENSION        :: 1010;
    INTERNAL_SERVER_ERROR      :: 1011;
    TLS_HANDSHAKE              :: 1015;
}

#scope_module

WEB_SOCKET_MAGIC :: "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";