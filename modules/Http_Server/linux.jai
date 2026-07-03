init :: (server: *Http_Server, port: u16, tls := false, certificate_file := "", private_key_file := "") -> error: bool {
    POSIX.signal(POSIX.SIGPIPE, POSIX.SIG_IGN);

    server.epoll_queue = Linux.epoll_create1(0);
    if server.epoll_queue == -1 return true;

    server.listening_socket = Socket.socket(Socket.AF_INET6, .SOCK_STREAM, Socket.IPPROTO.IPPROTO_TCP);
    if server.listening_socket == Socket.INVALID_SOCKET return true;

    options := 1;
    result := Socket.setsockopt(server.listening_socket, Socket.SOL_SOCKET, Socket.SO_REUSEPORT, *options, size_of(type_of(options)));
    if result == -1 return true;

    result = Socket.bind(server.listening_socket, Socket.in6addr_any.__in6_u.__u6_addr8, port);
    if result != 0 return true;

    result = Socket.listen(server.listening_socket, Socket.SOMAXCONN);
    if result != 0 return true;

    success := Socket.set_blocking(server.listening_socket, false);
    if !success return true;

    event: Linux.epoll_event;
    event.events = Linux.EPOLLET | Linux.EPOLLIN;
    event.data.fd = server.listening_socket;

    result = Linux.epoll_ctl(server.epoll_queue, .ADD, server.listening_socket, *event);
    if result == -1 return true;

    if tls {
        server.ssl_ctx = create_ssl_context();
        if server.ssl_ctx == null return true;

        error := configure_ssl_context(server.ssl_ctx, certificate_file, private_key_file);
        if error return true;
    }

    server.tls = tls;

    return false;
}

http_server_poll :: (server: *Http_Server, peek := false) -> error: bool, [] Http_Event {
    push_allocator(context.default_allocator);

    array_reset(*server.events);

    for server.clients_to_close_in_next_iteration {
        client := find_client(server, it);
        if client close(server, client, now = true);
    }

    array_reset(*server.clients_to_close_in_next_iteration);

    timeout := process_timeouts_and_get_next_timeout(server);
    if peek || server.events.count > 0 timeout = 0;

    epoll_events: [1024] Linux.epoll_event;
    number_of_events := Linux.epoll_wait(server.epoll_queue, epoll_events.data, epoll_events.count, xx timeout);
    if number_of_events == -1 return true, .[];

    for i: 0..number_of_events - 1 {
        event := epoll_events[i];

        error_events :: Linux.EPOLLPRI | Linux.EPOLLERR | Linux.EPOLLHUP;

        if event.data.fd == server.listening_socket {
            if event.events & Linux.EPOLLIN accept_clients(server);
            if event.events & error_events return true, .[];
            continue;
        }

        client_id := event.data.fd;

        if event.events & error_events {
            client := find_client(server, client_id);
            if client close(server, client);
            continue;
        }

        if event.events & Linux.EPOLLOUT {
            closed := send_to_client(server, client_id);
            if closed continue;
        }

        if event.events & Linux.EPOLLIN {
            closed := read_from_client(server, client_id);
            if closed continue;

            parse_requests(server, client_id);
        }
    }

    // If a WebSocket times out and receives a socket error in the same poll cycle,
    // it can be queued for closure multiple times. This means duplicate .Client_Closed
    // events may be emitted for the same client in this array.
    for server.clients_to_close_in_next_iteration array_add(*server.events, .{ type = .Client_Closed, client_closed = it });

    return false, server.events;
}

Http_Server :: struct {
    epoll_queue:      s32;
    listening_socket: Socket.Socket;

    clients: Table(Socket.Socket, Http_Client);

    clients_to_close_in_next_iteration: [..] Socket.Socket;

    events: [..] Http_Event;
    events.allocator = temp;

    timers: [..] Http_Timer;
    next_timer_id: u64 = 1;

    tls:     bool;
    ssl_ctx: *LibreSSL.SSL_CTX;
}

#scope_module

add_to_queue :: (server: *Http_Server, client: *Http_Client) -> error: bool {
    event: Linux.epoll_event;
    event.events = Linux.EPOLLET | Linux.EPOLLIN;
    event.data.fd = client.client_id;

    result := Linux.epoll_ctl(server.epoll_queue, .ADD, client.client_id, *event);
    if result == -1 return true;

    return false;
}

notify_when_sendable :: (server: *Http_Server, client: *Http_Client) -> error: bool {
    event: Linux.epoll_event;
    event.events = Linux.EPOLLET | Linux.EPOLLIN | Linux.EPOLLOUT;
    event.data.fd = client.client_id;

    result := Linux.epoll_ctl(server.epoll_queue, .MOD, client.client_id, *event);
    if result == -1 return true;

    return false;
}

do_not_notify_when_sendable :: (server: *Http_Server, client: *Http_Client) -> error: bool {
    event: Linux.epoll_event;
    event.events = Linux.EPOLLET | Linux.EPOLLIN;
    event.data.fd = client.client_id;

    result := Linux.epoll_ctl(server.epoll_queue, .MOD, client.client_id, *event);
    if result == -1 return true;

    return false;
}