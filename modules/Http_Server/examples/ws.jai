main :: () {
    error := init(*server, 3000);
    if error {
        log_error("Error: Unable to initialize the HTTP server.");
        return;
    }

    init(*router);

    get(*router, "/", (request: Http_Request) -> Http_Response {
        return html(request, #string HTML
            <h1>WebSocket Echo Demo</h1>
            <script>
                const ws = new WebSocket("ws://localhost:3000/ws");
                ws.onopen    = () => ws.send("Hello from browser!");
                ws.onmessage = (event) => console.log("echo:", event.data);
            </script>
        HTML);
    });

    web_socket(*router, "/ws", (server: *Http_Server, request: Http_Request) -> bool {
        error := web_socket_upgrade(server, request);
        if error return false;

        print("WebSocket client connected: %\n", request.client_id);
        return true;
    });

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

                    if request.uri == "/stop" quit = true;

                    // @Todo: This should be part of the normal http_router_handle_request and be done automatically.
                    if !http_router_handle_web_socket(*server, *router, request) {
                        handled, response := http_router_handle_request(*router, request);
                        if !handled response = not_found(request);
                        send_response(*server, response);
                    }

                case .Web_Socket_Message;
                    message := it.web_socket_message;

                    if message.opcode == .TEXT || message.opcode == .BINARY {
                        print("WebSocket message from %: %\n", message.client_id, message.data);
                        web_socket_send(*server, message.client_id, message.data, message.opcode);
                    }

            }

        }

        reset_temporary_storage();
    }

    shutdown(*server);
    fini(*router);

    report_memory_leaks();
}

server: Http_Server;
router: Http_Router;

#import "Basic" () (MEMORY_DEBUGGER = true, TEMP_ALLOCATOR_OVERWRITE_MEMORY = false);
#import,file "../module.jai";