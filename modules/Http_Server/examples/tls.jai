main :: () {
    error := init(*server, 3000, tls = true, certificate_file = "examples/cert.pem", private_key_file = "examples/key.pem");
    if error {
        log_error("Error: Unable to initialize the HTTP server.");
        return;
    }

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

            response := html(request, "<h1>TLS</h1>");
            send_response(*server, response);
        }

        reset_temporary_storage();
    }
}

server: Http_Server;

#import "Basic";
#import,file "../module.jai";