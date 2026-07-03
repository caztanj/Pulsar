main :: () {
    error := init(*server, 3000);
    if error {
        log_error("Error: Unable to initialize the HTTP server.");
        return;
    }

    init(*router);

    get(*router, "/", (request: Http_Request) -> Http_Response {
        return html(request, "<h1>Index</h1>");
    });

    get(*router, "/hello/world", (request: Http_Request) -> Http_Response {
        return html(request, "<h1>Hello World!</h1>");
    });

    get(*router, "*", (request: Http_Request) -> Http_Response {
        return html(request, "<h1>*</h1>");
    });

    quit := false;
    while !quit {
        error, events := http_server_poll(*server);
        if error {
            log_error("Error: Unable to poll the HTTP server.");
            quit = true;
        }

        for events {
            request := it.http_request;

            print_http_request(*request);

            if request.uri == "/stop" quit = true;

            handled, response := http_router_handle_request(*router, request);
            if !handled response = not_found(request);

            send_response(*server, response);
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