init :: (server: *Http_Server, port: u16, tls := false, certificate_file := "", private_key_file := "") -> error: bool {
    Socket.socket_init();

    server.listening_socket = Socket.socket(Socket.AF_INET, .SOCK_STREAM, Socket.IPPROTO.IPPROTO_TCP);
    if server.listening_socket == Socket.INVALID_SOCKET return true;

    result := Socket.bind(server.listening_socket, Socket.INADDR_ANY, port);
    if result != 0 return true;

    result = Socket.listen(server.listening_socket, Socket.SOMAXCONN);
    if result != 0 return true;

    success := Socket.set_blocking(server.listening_socket, false);
    if !success return true;

    wsapollfd := Socket.WSAPOLLFD.{ fd = server.listening_socket, events = Socket.POLLIN };
    array_add(*server.wsapollfds, wsapollfd);

    if tls {
        server.ssl_ctx = create_ssl_context();
        if server.ssl_ctx == null return true;

        error := configure_ssl_context(server.ssl_ctx, certificate_file, private_key_file);
        if error return true;
    }

    server.wakeup_socket = Socket.socket(Socket.AF_INET, .SOCK_DGRAM, 0);
    if server.wakeup_socket != Socket.INVALID_SOCKET {
        addr: Socket.sockaddr_in;
        addr.sin_family = Socket.AF_INET;
        addr.sin_port = 0;
        addr.sin_addr.S_un.S_addr = Socket.inet_addr("127.0.0.1");

        if Socket.bind(server.wakeup_socket, cast(*Socket.sockaddr)*addr, size_of(type_of(addr))) == 0 {
            addr_size: s32 = size_of(type_of(addr));

            Socket.getsockname(server.wakeup_socket, cast(*Socket.sockaddr)*addr, *addr_size);

            server.wakeup_port = Socket.ntohs(addr.sin_port);

            Socket.set_blocking(server.wakeup_socket, false);

            wsapollfd_wakeup := Socket.WSAPOLLFD.{ fd = server.wakeup_socket, events = Socket.POLLIN };

            array_add(*server.wsapollfds, wsapollfd_wakeup);
        } else {
            Socket.close_and_reset(*server.wakeup_socket);
        }
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

    number_of_events := Socket.WSAPoll(server.wsapollfds.data, xx server.wsapollfds.count, xx timeout);
    if number_of_events == Socket.SOCKET_ERROR return true, .[];

    ERROR_EVENTS :: Socket.POLLPRI | Socket.POLLHUP | Socket.POLLERR | Socket.POLLNVAL;

    for < server.wsapollfds {
        if it.fd == server.wakeup_socket {
            if it.revents & Socket.POLLIN {
                buffer: [64] u8;
                Socket.recvfrom(server.wakeup_socket, buffer.data, 64, 0, null, null);
            }

            continue;
        }

        if it.fd == server.listening_socket {
            if it.revents & Socket.POLLIN accept_clients(server);
            if it.revents & ERROR_EVENTS return true, .[];
            continue;
        }

        client_id := it.fd;

        if it.revents & ERROR_EVENTS {
            client := find_client(server, client_id);
            if client close(server, client);
            continue;
        }

        if it.revents & Socket.POLLOUT {
            closed := send_to_client(server, client_id);
            if closed continue;
        }

        if it.revents & Socket.POLLIN {
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
    listening_socket: Socket.Socket;

    clients: Table(Socket.Socket, Http_Client);

    clients_to_close_in_next_iteration:  [..] Socket.Socket;

    events: [..] Http_Event;
    events.allocator = temp;

    timers: [..] Http_Timer;
    next_timer_id: u64 = 1;

    wsapollfds: [..] Socket.WSAPOLLFD;

    tls:     bool;
    ssl_ctx: *LibreSSL.SSL_CTX;

    wakeup_socket: Socket.Socket;
    wakeup_port:   u16;
}

#scope_module

add_to_queue :: (server: *Http_Server, client: *Http_Client) -> error: bool {
    wsapollfd := Socket.WSAPOLLFD.{ fd = client.client_id, events = Socket.POLLIN };
    array_add(*server.wsapollfds, wsapollfd);

    return false;
}

notify_when_sendable :: (server: *Http_Server, client: *Http_Client) -> error: bool {
    for * server.wsapollfds {
        if it.fd == client.client_id {
            it.events = Socket.POLLIN | Socket.POLLOUT;
            break;
        }
    }

    return false;
}

do_not_notify_when_sendable :: (server: *Http_Server, client: *Http_Client) -> error: bool {
    for * server.wsapollfds {
        if it.fd == client.client_id {
            it.events = Socket.POLLIN;
            break;
        }
    }

    return false;
}