sse_init :: (server: *Http_Server, request: Http_Request) -> error: bool {
    if request.method != .GET return true;

    client := find_client(server, request.client_id);
    if client == null return true;

    HEADERS :: #run -> string {
        b: String_Builder;

        append(*b, "HTTP/1.1 200 OK\r\n");
        append(*b, "Content-Type: text/event-stream\r\n");
        append(*b, "Cache-Control: no-cache\r\n");
        append(*b, "Connection: keep-alive\r\n");
        append(*b, "X-Content-Type-Options: nosniff\r\n");
        append(*b, "X-Accel-Buffering: no\r\n");
        append(*b, "\r\n");

        return builder_to_string(*b);
    }

    append_to(*client.send_buffer, HEADERS);

    client.type = .SSE;

    send_to_client(server, request.client_id);

    return false;
}

sse_send :: (server: *Http_Server, client_id: Socket.Socket, data: string, event := "message", id := "") -> closed: bool {
    client := find_client(server, client_id);
    if client == null || client.type != .SSE return true;

    buffer := *client.send_buffer;

    write_field :: (prefix: string, value: string) #expand {
        if value {
            append_to(buffer, prefix);
            append_sanitized(buffer, value);
            append_to(buffer, "\n");
        }
    }

    write_field("event: ", event);
    write_field("id: ", id);

    t     := data.data;
    max_t := t + data.count;
    start := t;

    write_data_line :: (start: *u8, end: *u8) #expand {
        line: string;
        line.data = start;
        line.count = end - start;
        append_to(buffer, "data: ");
        append_to(buffer, line);
        append_to(buffer, "\n");
    }

    while t < max_t {
        if t.* == NEWLINE || t.* == CARRIAGE_RETURN {
            write_data_line(start, t);

            if t.* == CARRIAGE_RETURN && t + 1 < max_t && (t + 1).* == NEWLINE t += 1;

            start = t + 1;
        }

        t += 1;
    }

    if start < max_t write_data_line(start, max_t);

    append_to(buffer, "\n");

    return send_to_client(server, client_id);
}

sse_send_comment :: (server: *Http_Server, client_id: Socket.Socket, comment: string) -> closed: bool {
    client := find_client(server, client_id);
    if client == null || client.type != .SSE return true;

    buffer := *client.send_buffer;

    append_to(buffer, ":");
    append_sanitized(buffer, comment);
    append_to(buffer, "\n\n");

    return send_to_client(server, client_id);
}

#scope_file

append_to :: inline (buffer: *[..] u8, s: string) {
    array_add(buffer, ..s.([] u8));
}

append_sanitized :: inline (buffer: *[..] u8, s: string) {
    t     := s.data;
    max_t := t + s.count;
    start := t;

    while t < max_t {
        if t.* == NEWLINE || t.* == CARRIAGE_RETURN {
            if t > start {
                slice: string;
                slice.data = start;
                slice.count = t - start;
                append_to(buffer, slice);
            }

            start = t + 1;
        }

        t += 1;
    }

    if start < max_t {
        slice: string;
        slice.data = start;
        slice.count = max_t - start;
        append_to(buffer, slice);
    }
}

NEWLINE         :: 10;
CARRIAGE_RETURN :: 13;