main :: () {
    client: Http_Client;

    success := http_client_init(*client);
    if !success {
        log_error("Failed to initialize Http_Client");
        return;
    }

    defer http_client_deinit(*client);

    http_client_request(*client, "http://google.com", user_data = cast(*void) 1, follow_redirects = true);
    http_client_request(*client, "http://caztanj.com",  user_data = cast(*void) 2, follow_redirects = true);

    requests_finished := 0;
    while requests_finished < 2 {
        events := http_client_poll(*client);

        for events {
            print("Request % finished with code %\n", it.user_data, it.response.code);

            free(it.response);
            requests_finished += 1;
        }

        reset_temporary_storage();
        sleep_milliseconds(10);
    }

    print("All requests finished.\n");
}

#import "Basic";
#import,file "../module.jai";
