#module_parameters () (MAX_REQUEST_SIZE := 65536, MAX_WEB_SOCKET_MESSAGE_SIZE := 16_777_216);

get_header :: (headers: [] Http_Header, key: string) -> error: bool, string {
    for headers {
        if equal_nocase(it.key, key) return false, it.value;
    }

    return true, "";
}

set_header :: (headers: *[..] Http_Header, key: string, value: string) {
    // @Warning: Do not pass unvalidated user input into 'key' or 'value'
    // as it could lead to HTTP Response Splitting (CRLF injection) if it contains \r or \n.

    push_allocator(context.default_allocator);

    for * headers.* {
        if equal_nocase(it.key, key) {
            it.value = value;
            return;
        }
    }

    header := Http_Header.{ key = key, value = value };
    array_add(headers, header);
}

static_file :: (request: Http_Request, directory: string) -> Http_Response {
    push_allocator(temp);

    path := join(directory, "/", percent_decode(request.uri));

    if contains(path, "..") || contains(path, "\0") return bad_request(request);
    if !file_exists(path)   return not_found  (request);

    if is_directory(path) {
        index_path := tprint("%/index.html", path);
        if file_exists(index_path) path = index_path;
        else                       return not_found(request);
    }

    error, range := get_header(request.headers, "Range");
    if !error return serve_static_file_range(request, path);

    return serve_entire_static_file(request, path);
}

text :: (request: Http_Request, text: string, content_type := "text/plain") -> Http_Response {
    response: Http_Response;
    response.client_id = request.client_id;

    response.status = .OK;
    response.body   = text;

    set_header(*response.headers, "Content-Type", content_type);
    set_header(*response.headers, "Content-Length", tprint("%", text.count));

    return response;
}

html :: (request: Http_Request, html: string) -> Http_Response {
    return text(request, html, "text/html");
}

css :: (request: Http_Request, css: string) -> Http_Response {
    return text(request, css, "text/css");
}

js :: (request: Http_Request, js: string) -> Http_Response {
    return text(request, js, "application/js");
}

json :: (request: Http_Request, json: string) -> Http_Response {
    return text(request, json, "application/json");
}

not_found :: (request: Http_Request) -> Http_Response {
    response: Http_Response;
    response.client_id = request.client_id;

    response.status = .NOT_FOUND;

    set_header(*response.headers, "Content-Length", "0");

    return response;
}

bad_request :: (request: Http_Request) -> Http_Response {
    response: Http_Response;
    response.client_id = request.client_id;

    response.status = .BAD_REQUEST;

    set_header(*response.headers, "Content-Length", "0");

    return response;
}

internal_server_error :: (request: Http_Request) -> Http_Response {
    response: Http_Response;
    response.client_id = request.client_id;

    response.status = .INTERNAL_SERVER_ERROR;

    set_header(*response.headers, "Content-Length", "0");

    return response;
}

print_http_request :: (request: *Http_Request) {
    b: String_Builder;
    b.allocator = temp;

    print_to_builder(*b, "%", request.method);

    print_to_builder(*b, " % HTTP/1.1\n", request.uri);

    for request.headers {
        print_to_builder(*b, "%: %\n", it.key, it.value);
    }

    if request.body.count != 0 {
        print_to_builder(*b, "%\n", request.body);
    }

    print("%\n", builder_to_string(*b,, temp));
}

print_http_response :: (response: Http_Response) {
    b: String_Builder;
    b.allocator = temp;

    print_to_builder(*b, "HTTP/1.1 %\r\n", http_response_status_to_string(response.status));

    for response.headers {
        print_to_builder(*b, "%: %\r\n", it.key, it.value);
    }

    print("%\n", builder_to_string(*b,, temp));
}

percent_decode :: (s: string) -> string {
    b: String_Builder;
    b.allocator = temp;

    t     := s.data;
    max_t := t + s.count;

    start := t;

    while t < max_t {
        if t.* == "%" && (t + 2) < max_t {
            hex_char_to_int :: (c: u8) -> int, bool {
                if c >= "0" && c <= "9" return c - "0", true;
                if c >= "a" && c <= "f" return c - "a" + 10, true;
                if c >= "A" && c <= "F" return c - "A" + 10, true;
                return 0, false;
            }

            v1, ok1 := hex_char_to_int((t + 1).*);
            v2, ok2 := hex_char_to_int((t + 2).*);

            if ok1 && ok2 {
                if t > start append(*b, string.{ data = start, count = t - start });
                append(*b, (v1 * 16 + v2).(u8));
                t += 3;
                start = t;
                continue;
            }
        }

        t += 1;
    }

    if start < max_t {
        append(*b, string.{ data = start, count = max_t - start });
    }

    return builder_to_string(*b);
}

html_escape :: (s: string) -> string {
    b: String_Builder;
    b.allocator = temp;

    t     := s.data;
    max_t := t + s.count;

    start := t;

    while t < max_t {
        if t.* == {
            case "&";
                append(*b, string.{ data = start, count = t - start });
                append(*b, "&amp;");
                start = t + 1;
            case "<";
                append(*b, string.{ data = start, count = t - start });
                append(*b, "&lt;");
                start = t + 1;
            case ">";
                append(*b, string.{ data = start, count = t - start });
                append(*b, "&gt;");
                start = t + 1;
            case "\"";
                append(*b, string.{ data = start, count = t - start });
                append(*b, "&quot;");
                start = t + 1;
            case "'";
                append(*b, string.{ data = start, count = t - start });
                append(*b, "&#39;");
                start = t + 1;
        }

        t += 1;
    }

    if start < max_t {
        append(*b, string.{ data = start, count = max_t - start });
    }

    return builder_to_string(*b);
}

send_response :: (server: *Http_Server, response: Http_Response) {
    push_allocator(context.default_allocator);

    client := find_client(server, response.client_id);
    if client == null return;

    b: String_Builder;
    b.allocator = temp;

    print_to_builder(*b, "HTTP/1.1 %\r\n", http_response_status_to_string(response.status));

    for response.headers {
        print_to_builder(*b, "%: %\r\n", it.key, it.value);
    }

    append(*b, "\r\n");
    append(*b, response.body);

    buffer := get_base_buffer(*b);
    while buffer {
        if buffer.count > 0 {
            slice: [] u8;
            slice.data  = get_buffer_data(buffer);
            slice.count = buffer.count;
            array_add(*client.send_buffer, ..slice);
        }

        buffer = buffer.next;
    }

    if response.file.handle {
        client.send_file        = response.file;
        client.send_file_offset = 0;
        client.send_file_size   = file_length(client.send_file);
    }

    send_to_client(server, response.client_id);
}

shutdown :: (server: *Http_Server) {
    for * server.clients {
        close(server, it, now = true);
    }

    deinit(*server.clients);

    array_reset(*server.clients_to_close_in_next_iteration);

    if server.tls {
        LibreSSL.SSL_CTX_free(server.ssl_ctx);
    }

    #if OS == .MACOS {
        array_reset(*server.kqueue_changes);
    }

    #if OS == .WINDOWS {
        array_reset(*server.wsapollfds);
    }
}

add_timer :: (server: *Http_Server, milliseconds: int) -> u64 {
    timer: Http_Timer;
    timer.id      = server.next_timer_id;
    timer.timeout = current_time_monotonic() + milliseconds_to_apollo(milliseconds);

    server.next_timer_id += 1;

    array_add(*server.timers, timer);

    return timer.id;
}

add_timer :: (server: *Http_Server, time: Apollo_Time) -> u64 {
    timer: Http_Timer;
    timer.id      = server.next_timer_id;
    timer.timeout = time;

    server.next_timer_id += 1;

    array_add(*server.timers, timer);

    return timer.id;
}

remove_timer :: (server: *Http_Server, id: u64) {
    for server.timers {
        if it.id == id {
            remove it;
            return;
        }
    }
}

Http_Request :: struct {
    client_id: Socket.Socket;

    uri:    string;
    method: Http_Method;

    headers: [..] Http_Header;
    headers.allocator = temp;

    body: string;
}

Http_Response :: struct {
    client_id: Socket.Socket;

    status: Http_Response_Status;

    headers: [..] Http_Header;
    headers.allocator = temp;

    body: string;

    file: File;
}

Http_Method :: enum {
    GET;
    HEAD;
    POST;
    PUT;
    DELETE;
    CONNECT;
    OPTIONS;
    TRACE;
    PATCH;
}

Http_Header :: struct {
    key:   string;
    value: string;
}

Http_Event_Type :: enum {
    Http_Request;
    Web_Socket_Message;
    Client_Closed;
    Timer;
}

Http_Event :: struct {
    type: Http_Event_Type;

    union {
        http_request:       Http_Request;
        web_socket_message: Web_Socket_Message;
        client_closed:      Socket.Socket;
        timer:              u64;
    };
}

Http_Timer :: struct {
    id:      u64;
    timeout: Apollo_Time;
}

#scope_module

accept_clients :: (server: *Http_Server) {
    while true {
        client_socket := Socket.accept_v6(server.listening_socket);
        if client_socket == Socket.INVALID_SOCKET {
            error := Socket.get_last_socket_error();
            if error == Socket.SOCKET_WOULDBLOCK return;
            continue;
        }

        client := add_client(server, client_socket);

        if server.tls {
            client.ssl = LibreSSL.SSL_new(server.ssl_ctx);

            LibreSSL.SSL_set_fd(client.ssl, xx client_socket);

            result := LibreSSL.SSL_accept(client.ssl);
            if result <= 0 {
                error := LibreSSL.SSL_get_error(client.ssl, result);
                if error != LibreSSL.SSL_ERROR_WANT_READ && error != LibreSSL.SSL_ERROR_WANT_WRITE {
                    print_ssl_errors();
                    close(server, client);
                    continue;
                }
            }
        }

        success := Socket.set_blocking(client_socket, false);
        if !success {
            close(server, client);
            continue;
        }

        error := add_to_queue(server, client);
        if error {
            close(server, client);
            continue;
        }

        closed := read_from_client(server, client_socket);
        if !closed parse_requests(server, client_socket);
    }
}

read_from_client :: (server: *Http_Server, client_id: Socket.Socket) -> closed: bool {
    client := find_client(server, client_id);

    while true {
        offset := client.read_buffer.data + client.read_buffer.count;
        max    := client.read_buffer.allocated - client.read_buffer.count;

        if max == 0 {
            array_reserve(*client.read_buffer, client.read_buffer.allocated + 4096);

            offset = client.read_buffer.data + client.read_buffer.count;
            max    = client.read_buffer.allocated - client.read_buffer.count;
        }

        bytes_read := recv(server, client, offset, max);
        if bytes_read == -1 {
            error := Socket.get_last_socket_error();

            if server.tls {
                if LibreSSL.SSL_get_error(client.ssl, xx bytes_read) == {
                    case LibreSSL.SSL_ERROR_WANT_READ;  #through;
                    case LibreSSL.SSL_ERROR_WANT_WRITE; error = Socket.SOCKET_WOULDBLOCK;
                }
            }

            if error != Socket.SOCKET_WOULDBLOCK {
                close(server, client);
                return true;
            }

            set_timeout(client, 30);

            return false;
        }

        if bytes_read == 0 {
            close(server, client);
            return true;
        }

        client.read_buffer.count += bytes_read;

        if client.type != .Web_Socket && client.read_buffer.count >= MAX_REQUEST_SIZE {
            close(server, client);
            return true;
        }
    }

    return false;
}

send_to_client :: (server: *Http_Server, client_id: Socket.Socket) -> closed: bool {
    client := find_client(server, client_id);

    while client.send_buffer.count - client.send_buffer_offset > 0 {
        bytes_sent := send(server, client, client.send_buffer.data + client.send_buffer_offset, client.send_buffer.count - client.send_buffer_offset);
        if bytes_sent == -1 {
            error := Socket.get_last_socket_error();

            if server.tls {
                if LibreSSL.SSL_get_error(client.ssl, xx bytes_sent) == {
                    case LibreSSL.SSL_ERROR_WANT_READ;  #through;
                    case LibreSSL.SSL_ERROR_WANT_WRITE; error = Socket.SOCKET_WOULDBLOCK;
                }
            }

            if error != Socket.SOCKET_WOULDBLOCK {
                close(server, client);
                return true;
            }

            set_timeout(client, 30);
            notify_when_sendable(server, client);

            return false;
        }

        client.send_buffer_offset += bytes_sent;
    }

    if client.send_buffer_offset == client.send_buffer.count {
        client.send_buffer_offset = 0;
        client.send_buffer.count = 0;
    } else if client.send_buffer_offset >= 4096 {
        remaining := client.send_buffer.count - client.send_buffer_offset;
        memcpy(client.send_buffer.data, client.send_buffer.data + client.send_buffer_offset, remaining);
        client.send_buffer.count = remaining;
        client.send_buffer_offset = 0;
    }

    if client.send_file.handle {
        while client.send_file_offset < client.send_file_size {
            error, content := read_part_of_file(client.send_file, client.send_file_offset, kilobytes(32),, temp);
            if error {
                close(server, client);
                return true;
            }

            remaining := content;
            while remaining.count > 0 {
                bytes_sent := send(server, client, remaining.data, remaining.count);
                if bytes_sent == -1 {
                    error := Socket.get_last_socket_error();

                    if server.tls {
                        if LibreSSL.SSL_get_error(client.ssl, xx bytes_sent) == {
                            case LibreSSL.SSL_ERROR_WANT_READ;  #through;
                            case LibreSSL.SSL_ERROR_WANT_WRITE; error = Socket.SOCKET_WOULDBLOCK;
                        }
                    }

                    if error != Socket.SOCKET_WOULDBLOCK {
                        close(server, client);
                        return true;
                    }

                    set_timeout(client, 30);
                    notify_when_sendable(server, client);

                    return false;
                }

                client.send_file_offset += bytes_sent;
                remaining.data  += bytes_sent;
                remaining.count -= bytes_sent;
            }
        }

        file_close(*client.send_file);

        client.send_file_offset = 0;
        client.send_file_size   = 0;
    }

    do_not_notify_when_sendable(server, client);
    set_timeout(client, 30);

    return false;
}

recv :: (server: *Http_Server, client: *Http_Client, buffer: *u8, size: int) -> int {
    if server.tls {
        return LibreSSL.SSL_read(client.ssl, buffer, xx size);
    }

    return Socket.recv(client.client_id, buffer, xx size, 0);
}

send :: (server: *Http_Server, client: *Http_Client, buffer: *u8, size: int) -> int {
    if server.tls {
        return LibreSSL.SSL_write(client.ssl, buffer, xx size);
    }

    return Socket.send(client.client_id, buffer, xx size, 0);
}

parse_requests :: (server: *Http_Server, client_id: Socket.Socket) {
    client := find_client(server, client_id);

    if client.type == {
        case .SSE;
            array_reset(*client.read_buffer);
            return;

        case .Web_Socket;
            parse_web_socket_frames(server, client_id);
            return;

    }

    client.t     = client.read_buffer.data;
    client.max_t = client.read_buffer.data + client.read_buffer.count;

    while true {
        t := client.t;

        status, request := parse_request(client);
        if status == .ERROR {
            close(server, client);
            return;
        } else if status == .INCOMPLETE {
            count := client.max_t - t;
            memcpy(client.read_buffer.data, t, count);
            client.read_buffer.count = count;

            return;
        }

        request.client_id = client_id;

        array_add(*server.events, .{ type = .Http_Request, http_request = request });
    }
}

parse_request :: (using client: *Http_Client) -> Parse_Status, Http_Request {
    request: Http_Request;

    status := parse_request_line(client, *request);
    if status != .SUCCESS return status, .{};

    if t >= max_t return .INCOMPLETE, .{};

    content_length := -1;

    while true {
        if t.* == "\r" {
            t += 1;
            if t >= max_t  return .INCOMPLETE, .{};
            if t.* != "\n" return .ERROR, .{};

            t += 1;
            break;
        }

        status, header := parse_header(client);
        if status != .SUCCESS return status, .{};

        if equal_nocase(header.key, "Content-Length") {
            if content_length != -1 return .ERROR, .{};

            content_length=, success:, remainder := string_to_int(header.value, T = u32);
            if !success || remainder.count > 0 return .ERROR, .{};
        } else if equal_nocase(header.key, "Transfer-Encoding") {
            return .ERROR, .{};
        }

        array_add(*request.headers, header);
    }

    if content_length != -1 {
        if t + content_length > max_t return .INCOMPLETE, .{};

        request.body.data = t;
        request.body.count = content_length;

        request.body = copy_temporary_string(request.body);

        t += content_length;
    }

    return .SUCCESS, request;
}

parse_request_line :: (using client: *Http_Client, request: *Http_Request) -> Parse_Status {
    method := string.{ data = t };

    while t < max_t {
        if t - method.data > 7    return .ERROR;
        if t.* == " "             break;
        if t.* < "A" || t.* > "Z" return .ERROR;

        t += 1;
    }

    if t >= max_t return .INCOMPLETE;

    method.count = t - method.data;

    if method == {
        case "GET";     request.method = .GET;
        case "HEAD";    request.method = .HEAD;
        case "POST";    request.method = .POST;
        case "PUT";     request.method = .PUT;
        case "DELETE";  request.method = .DELETE;
        case "CONNECT"; request.method = .CONNECT;
        case "OPTIONS"; request.method = .OPTIONS;
        case "TRACE";   request.method = .TRACE;
        case "PATCH";   request.method = .PATCH;

        case; return .ERROR;
    }

    t += 1;
    if t >= max_t return .INCOMPLETE;

    request.uri.data = t;

    while t < max_t {
        if t.* == " " break;

        if !URI_ALLOWED_CHARS[t.*] return .ERROR;

        t += 1;
    }

    if t >= max_t return .INCOMPLETE;

    request.uri.count = t - request.uri.data;

    t += 1;
    if t >= max_t return .INCOMPLETE;

    version := string.{ data = t };

    while t < max_t {
        if t - version.data > 8 return .ERROR;

        if t.* == "\r" {
            t += 1;
            if t >= max_t  return .INCOMPLETE;
            if t.* != "\n" return .ERROR;

            break;
        }

        version.count += 1;
        t += 1;
    }

    if t >= max_t return .INCOMPLETE;

    if version != "HTTP/1.1" return .ERROR;

    t += 1;
    if t >= max_t return .INCOMPLETE;

    request.uri = copy_temporary_string(request.uri);

    return .SUCCESS;
}

parse_header :: (using client: *Http_Client) -> Parse_Status, Http_Header {
    header: Http_Header;
    header.key.data = t;

    while t < max_t {
        if t.* == ":" break;
        t += 1;
    }

    if t >= max_t return .INCOMPLETE, .{};

    header.key.count = t - header.key.data;
    header.key = trim(header.key, chars=" ");

    t += 1;
    if t >= max_t return .INCOMPLETE, .{};

    header.value.data = t;

    while t < max_t {
        if t.* == "\r" {
            t += 1;
            if t >= max_t  return .INCOMPLETE, .{};
            if t.* != "\n" return .ERROR, .{};

            break;
        }

        t += 1;
    }

    header.value.count = t - header.value.data;
    header.value = trim(header.value, chars=" \r");

    t += 1;
    if t >= max_t return .INCOMPLETE, .{};

    header.key   = copy_temporary_string(header.key);
    header.value = copy_temporary_string(header.value);

    return .SUCCESS, header;
}

set_timeout :: (using client: *Http_Client, seconds: int) {
    timeout = current_time_monotonic() + seconds_to_apollo(seconds);
}

process_timeouts_and_get_next_timeout :: (server: *Http_Server) -> int {
    now := current_time_monotonic();
    earliest := -1;

    timed_out_clients: [..] Socket.Socket;
    timed_out_clients.allocator = temp;

    for * server.clients {
        if it.timeout <= now {
            array_add(*timed_out_clients, it.client_id);
            continue;
        }

        this := to_milliseconds(it.timeout - now);

        if earliest == -1 || this < earliest earliest = this;
    }

    for timed_out_clients {
        client := find_client(server, it);
        close(server, client);
    }

    for * server.timers {
        if it.timeout <= now {
            array_add(*server.events, .{ type = .Timer, timer = it.id });
            remove it;
            continue;
        }

        this := to_milliseconds(it.timeout - now);
        if earliest == -1 || this < earliest earliest = this;
    }

    return earliest;
}

close_in_next_iteration :: (server: *Http_Server, client: *Http_Client) {
    array_add(*server.clients_to_close_in_next_iteration, client.client_id);
}

close :: (server: *Http_Server, client: *Http_Client, now := false) {
    should_close_in_next_iteration  := !now;
    should_close_in_next_iteration &&= client.type == .Web_Socket || client.type == .SSE;

    if should_close_in_next_iteration {
        array_add(*server.clients_to_close_in_next_iteration, client.client_id);
        return;
    }

    #if OS == .WINDOWS {
        for server.wsapollfds {
            if it.fd == client.client_id {
                remove it;
                break;
            }
        }
    }

    if server.tls {
        LibreSSL.SSL_shutdown(client.ssl);
        LibreSSL.SSL_free(client.ssl);
    }

    socket := client.client_id;
    Socket.close_and_reset(*socket);
    remove_client(server, client);
}

add_client :: (server: *Http_Server, client_id: Socket.Socket) -> *Http_Client {
    client := table_add(*server.clients, client_id, .{});
    client.client_id = client_id;

    set_timeout(client, 5);

    return client;
}

find_client :: (server: *Http_Server, client_id: Socket.Socket) -> *Http_Client {
    client := table_find_pointer(*server.clients, client_id);
    return client;
}

remove_client :: (server: *Http_Server, client: *Http_Client) {
    for * server.events {
        if it.type == {
            case .Http_Request;
                if it.http_request.client_id == client.client_id remove it;

            case .Web_Socket_Message;
                if it.web_socket_message.client_id == client.client_id remove it;
        }
    }

    client_id := client.client_id;

    array_reset(*client.read_buffer);
    array_reset(*client.send_buffer);
    array_reset(*client.ws_partial_payload);

    if client.send_file.handle file_close(*client.send_file);

    table_remove(*server.clients, client_id);
}

create_ssl_context :: () -> *LibreSSL.SSL_CTX {
    method := LibreSSL.TLS_server_method();
    ctx    := LibreSSL.SSL_CTX_new(method);
    if !ctx {
        print_ssl_errors();
        return null;
    }

    return ctx;
}

configure_ssl_context :: (ctx: *LibreSSL.SSL_CTX, certificate_file: string, private_key_file: string) -> error: bool {
    result := LibreSSL.SSL_CTX_use_certificate_file(ctx, temp_c_string(certificate_file), LibreSSL.SSL_FILETYPE_PEM);
    if result <= 0 {
        print_ssl_errors();
        return true;
    }

    result = LibreSSL.SSL_CTX_use_PrivateKey_file(ctx, temp_c_string(private_key_file), LibreSSL.SSL_FILETYPE_PEM);
    if result <= 0 {
        print_ssl_errors();
        return true;
    }

    return false;
}

print_ssl_errors :: () {
    #if OS == .WINDOWS {
        buffer: [1024] u8;

        bio := LibreSSL.BIO_new(LibreSSL.BIO_s_mem());
        LibreSSL.ERR_print_errors(bio);

        count      := LibreSSL.BIO_read(bio, buffer.data, buffer.count);
        serialized := string.{ data = buffer.data, count = count };

        if count > 0 {
            print("%\n", serialized);
        }

        LibreSSL.BIO_free(bio);
    } else {
        LibreSSL.ERR_print_errors_fp(POSIX.stderr);
    }
}

kilobytes :: (n: int) -> int {
    return n * 1024;
}

parse_range :: (header: string) -> error: bool, start: int, end: int {
    t     := header.data;
    max_t := header.data + header.count;

    key := string.{ data = t };

    while t < max_t {
        if t - key.data > #run "bytes".count return true, 0, 0;
        if t.* == "="                        break;
        if !is_alpha(t.*)                    return true, 0, 0;

        t += 1;
    }

    key.count = t - key.data;

    if !equal_nocase(key, "bytes") return true, 0, 0;

    if t.* != "=" return true, 0, 0;
    t += 1;

    if t >= max_t return true, 0, 0;

    start := string.{ data = t };

    while t < max_t {
        if t.* == "-"     break;
        if !is_digit(t.*) return true, 0, 0;

        t += 1;
    }

    start.count = t - start.data;

    if t.* != "-" return true, 0, 0;

    t += 1;
    if t >= max_t return false, string_to_int(start), -1;

    end := string.{ data = t };

    while t < max_t {
        if !is_digit(t.*) return true, 0, 0;

        t += 1;
    }

    end.count = t - end.data;

    start_int := ifx start.count == 0 then -1 else string_to_int(start);
    end_int   := ifx end.count == 0 then -1 else string_to_int(end);
    return false, start_int, end_int;
}

serve_entire_static_file :: (request: Http_Request, path: string) -> Http_Response {
    response: Http_Response;
    response.client_id = request.client_id;
    response.status    = .OK;

    set_header(*response.headers, "Accept-Ranges", "bytes");

    content_type := get_content_type_from_extension(path);
    set_header(*response.headers, "Content-Type", content_type);

    file, success := file_open(path);
    if !success return internal_server_error(request);

    response.file = file;

    length:, success = file_length(file);
    if !success {
        file_close(*file);
        return internal_server_error(request);
    }

    set_header(*response.headers, "Content-Length", tprint("%", length));

    return response;
}

serve_static_file_range :: (request: Http_Request, path: string) -> Http_Response {
    response: Http_Response;
    response.client_id = request.client_id;
    response.status    = .PARTIAL_CONTENT;

    content_type := get_content_type_from_extension(path);
    set_header(*response.headers, "Content-Type", content_type);

    error, range := get_header(request.headers, "Range");
    if error return internal_server_error(request);

    error=, start, end := parse_range(range);
    if error return bad_request(request);

    file, success := file_open(path);
    if !success return internal_server_error(request);

    defer file_close(*file);

    length:, success = file_length(file);
    if !success return internal_server_error(request);

    if start == -1 {
        start = length - end;
        if start < 0 start = 0;
        end = length - 1;
    } else if end == -1 {
        end = start + kilobytes(1024);
    }

    if start >= length {
        response.status = .RANGE_NOT_SATISFIABLE;
        set_header(*response.headers, "Content-Range", tprint("bytes */%", length));
        return response;
    }

    if end >= length end = length - 1;
    if start > end return bad_request(request);

    if end - start + 1 > kilobytes(1024) {
        end = start + kilobytes(1024) - 1;
    }

    error=, content := read_part_of_file(file, start, end - start + 1);
    if error return internal_server_error(request);

    end = start + content.count - 1;

    response.body = content;

    set_header(*response.headers, "Content-Length", tprint("%", content.count));
    set_header(*response.headers, "Content-Range", tprint("bytes %-%/%", start, end, length));

    return response;
}

get_content_type_from_extension :: (path: string) -> string {
    extension := path_extension(path);

    if extension == {
        // Text/HTML/CSS/JS
        case "html"; return "text/html";
        case "css";  return "text/css";
        case "js";   return "application/javascript";
        case "json"; return "application/json";
        case "txt";  return "text/plain";
        case "wasm"; return "application/wasm";

        // Images
        case "jpg";  #through;
        case "jpeg"; return "image/jpeg";
        case "png";  return "image/png";
        case "gif";  return "image/gif";
        case "webp"; return "image/webp";
        case "svg";  return "image/svg+xml";
        case "ico";  return "image/x-icon";
        case "bmp";  return "image/bmp";
        case "tif";  #through;
        case "tiff"; return "image/tiff";
        case "avif"; return "image/avif";

        // Video
        case "webm"; return "video/webm";
        case "mp4";  return "video/mp4";
        case "mkv";  return "video/x-matroska";
        case "avi";  return "video/x-msvideo";
        case "mov";  return "video/quicktime";

        // Audio
        case "mp3";  return "audio/mpeg";
        case "wav";  return "audio/wav";
        case "ogg";  return "audio/ogg";
        case "m4a";  return "audio/mp4";
        case "flac"; return "audio/flac";

        // Documents
        case "pdf";  return "application/pdf";
    }

    return "application/octet-stream";
}

read_part_of_file :: (f: File, start: int, count: int) -> error: bool, string {
    data := cast(*u8) alloc(count);
    if data == null return true, "";

    success := file_set_position(f, start);
    if !success return true, "";

    success=, total_read := file_read(f, data, count);
    if !success return true, "";

    content: string;
    content.data = data;
    content.count = total_read;

    return false, content;
}

Parse_Status :: enum {
    ERROR;
    INCOMPLETE;
    SUCCESS;
}

Http_Client_Type :: enum {
    Http;
    SSE;
    Web_Socket;
}

Http_Client :: struct {
    type: Http_Client_Type;

    client_id: Socket.Socket;
    timeout:   Apollo_Time;

    t:     *u8;
    max_t: *u8;

    read_buffer: [..] u8;
    send_buffer: [..] u8;
    send_buffer_offset: int;

    ssl: *LibreSSL.SSL;

    send_file:        File;
    send_file_offset: int;
    send_file_size:   int;

    ws_partial_opcode:  u8;
    ws_partial_payload: [..] u8;
}

#insert -> string {
    push_allocator(temp);

    Http_Response_Status_Specification :: struct {
        key:         string;
        code:        int;
        description: string;
    }

    response_status_specifications := Http_Response_Status_Specification.[
        .{ "NONE", 0, "None" },

        .{ "CONTINUE",            100, "Continue" },
        .{ "SWITCHING_PROTOCOLS", 101, "Switching Protocols" },
        .{ "EARLY_HINTS",         103, "Early Hints" },

        .{ "OK",                            200, "OK" },
        .{ "CREATED",                       201, "Created" },
        .{ "ACCEPTED",                      202, "Accepted" },
        .{ "NON_AUTHORITATIVE_INFORMATION", 203, "Non Authoritative Information" },
        .{ "NO_CONTENT",                    204, "No Content" },
        .{ "RESET_CONTENT",                 205, "Reset Content" },
        .{ "PARTIAL_CONTENT",               206, "Partial Content" },

        .{ "MULTIPLE_CHOICES",   300, "Multiple Choices" },
        .{ "MOVED_PERMANENTLY",  301, "Moved Permanently" },
        .{ "FOUND",              302, "Found" },
        .{ "SEE_OTHER",          303, "See Other" },
        .{ "NOT_MODIFIED",       304, "Not Modified" },
        .{ "TEMPORARY_REDIRECT", 307, "Temporary Redirect" },
        .{ "PERMANENT_REDIRECT", 308, "Permanent Redirect" },

        .{ "BAD_REQUEST",                     400, "Bad Request" },
        .{ "UNAUTHORIZED",                    401, "Unauthorized" },
        .{ "PAYMENT_REQUIRED",                402, "Payment Required" },
        .{ "FORBIDDEN",                       403, "Forbidden" },
        .{ "NOT_FOUND",                       404, "Not Found" },
        .{ "METHOD_NOT_ALLOWED",              405, "Method Not Allowed" },
        .{ "NOT_ACCEPTABLE",                  406, "Not Acceptable" },
        .{ "PROXY_AUTHENTICATION_REQUIRED",   407, "Proxy Authentication Required" },
        .{ "REQUEST_TIMEOUT",                 408, "Request Timeout" },
        .{ "CONFLICT",                        409, "Conflict" },
        .{ "GONE",                            410, "Gone" },
        .{ "LENGTH_REQUIRED",                 411, "Length Required" },
        .{ "PRECONDITION_FAILED",             412, "Precondition Failed" },
        .{ "CONTENT_TOO_LARGE",               413, "Content Too Large" },
        .{ "URI_TOO_LONG",                    414, "URI Too Long" },
        .{ "UNSUPPORTED_MEDIA_TYPE",          415, "Unsupported Media Type" },
        .{ "RANGE_NOT_SATISFIABLE",           416, "Range Not Satisfiable" },
        .{ "EXPECTATION_FAILED",              417, "Expectation Failed" },
        .{ "I_AM_A_TEAPOT",                   418, "I'm a teapot" },
        .{ "MISDIRECTED_REQUEST",             421, "Misdirected Request" },
        .{ "UPGRADE_REQUIRED",                426, "Upgrade Required" },
        .{ "PRECONDITION_REQUIRED",           428, "Precondition Required" },
        .{ "TOO_MANY_REQUESTS",               429, "Too Many Requests" },
        .{ "REQUEST_HEADER_FIELDS_TOO_LARGE", 431, "Request Header Fields Too Large" },
        .{ "UNAVAILABLE_FOR_LEGAL_REASONS",   451, "Unavailable For Legal Reasons" },

        .{ "INTERNAL_SERVER_ERROR",           500, "Internal Server Error" },
        .{ "NOT_IMPLEMENTED",                 501, "Not Implemented" },
        .{ "BAD_GATEWAY",                     502, "Bad Gateway" },
        .{ "SERVICE_UNAVAILABLE",             503, "Service Unavailable" },
        .{ "GATEWAY_TIMEOUT",                 504, "Gateway Timeout" },
        .{ "HTTP_VERSION_NOT_SUPPORTED",      505, "HTTP Version Not Supported" },
        .{ "VARIANT_ALSO_NEGOTIATES",         506, "Variant Also Negotiates" },
        .{ "NOT_EXTENDED",                    510, "Not Extended" },
        .{ "NETWORK_AUTHENTICATION_REQUIRED", 511, "Network Authentication Required" },
    ];

    b: String_Builder;

    append(*b, "Http_Response_Status :: enum {\n");

    for response_status_specifications {
        print_to_builder(*b, "    % :: %; \n", it.key, it.code);
    }

    append(*b, "}\n\n");

    append(*b, "http_response_status_to_string :: (response_status: Http_Response_Status) -> string {\n");
    append(*b, "    if #complete response_status == {\n");

    for response_status_specifications {
        print_to_builder(*b, "        case .%;  return \"% %\";\n", it.key, it.code, it.description);
    }

    append(*b, "    }\n");
    append(*b, "}\n");

    return builder_to_string(*b);
}

#no_reset
URI_ALLOWED_CHARS: [256] bool;

#run {
    for c: #char "a"..#char "z" URI_ALLOWED_CHARS[c] = true;
    for c: #char "A"..#char "Z" URI_ALLOWED_CHARS[c] = true;
    for c: #char "0"..#char "9" URI_ALLOWED_CHARS[c] = true;
    for "-._~!$&'()*+,;=:@/?#[]%" URI_ALLOWED_CHARS[it] = true;
}

#load "router.jai";
#load "sse.jai";
#load "web_socket.jai";

#import "Base64";
#import "Basic";
#import "File";
#import "File_Utilities";
#import "Flat_Pool";
#import "Hash_Table";
#import "Math";
#import "String";
#import "Unicode";

Socket   :: #import "Socket";
LibreSSL :: #import,dir "../LibreSSL";

#if OS == .LINUX {
    #load "linux.jai";
    Linux :: #import "Linux";
    POSIX :: #import "POSIX";
}

#if OS == .MACOS {
    #load "macos.jai";
    Macos :: #import "Macos";
    POSIX :: #import "POSIX";
}

#if OS == .WINDOWS {
    #load "windows.jai";
}
