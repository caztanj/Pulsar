main :: () {
    error, response := get("http://google.com", follow_redirects = true);
    if error {
        log_error("Failed to perform request: %\n", response.curl_code);
        return;
    }

    defer free(response);

    print("Request finished with code %\n", response.code);
}

#import "Basic";
#import,file "../module.jai";
