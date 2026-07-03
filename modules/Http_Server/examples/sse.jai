main :: () {
    error := init(*server, 3000);
    if error {
        log_error("Error: Unable to initialize the HTTP server.");
        return;
    }

    print("Listening on http://localhost:3000\n");

    sse_clients: [..] Socket.Socket;

    timer_id := add_timer(*server, 1000);

    quit := false;
    while !quit {
        error, events := http_server_poll(*server);
        if error {
            log_error("Error: Unable to poll the HTTP server.");
            quit = true;
        }

        for events {
            if it.type == {
                case .Http_Request;
                    request := it.http_request;

                    print_http_request(*request);

                    if request.uri == "/sse" {
                        sse_init(*server, request);
                        array_add(*sse_clients, request.client_id);
                    } else if request.uri == "/stop" {
                        quit = true;
                    } else {
                        send_response(*server, html(request, #string HTML
                            <!DOCTYPE html>
                            <html>
                                <head>
                                    <title>SSE</title>
                                </head>
                                <body>
                                    <h1>SSE</h1>
                                    <div id="messages"></div>
                                    <script>
                                        const eventSource = new EventSource("sse");

                                        eventSource.onmessage = (event) => {
                                            const div = document.createElement("div");
                                            div.textContent = `message: ${event.data}`;
                                            messages.appendChild(div);
                                        };
                                    </script>
                                </body>
                            </html>
                        HTML));
                    }

                case .Client_Closed;
                    array_unordered_remove_by_value(*sse_clients, it.client_closed);

                case .Timer;
                    if it.timer == timer_id {
                        now := current_time_monotonic();
                        for sse_clients {
                            message := tprint("The time is %", now);
                            sse_send(*server, it, message);
                        }

                        timer_id = add_timer(*server, 1000);
                    }
            }
        }

        reset_temporary_storage();
    }

    shutdown(*server);

    array_reset(*sse_clients);

    report_memory_leaks();
}

server: Http_Server;

#import "Basic" () (MEMORY_DEBUGGER = true, TEMP_ALLOCATOR_OVERWRITE_MEMORY = false);

Socket :: #import "Socket";

#import,file "../module.jai";
