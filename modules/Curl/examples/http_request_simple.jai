// A simple single procedure to make http requests
// To keep things simple, this example does not parse response headers
// For an example doing that, and demoing more curl features, see http_request.jai

#import "Curl";
// Allocates response_body using context.allocator
request :: (url: string, data: string = "", method: string = "", headers: [] string = .[], include_headers: bool = false) -> response_body: string, response_code: int, curl_code: CURLcode {
    curl := curl_easy_init();
    assert(curl != null);
    defer curl_easy_cleanup(curl);

    curl_easy_setopt(curl, .URL, temp_c_string(url));

    if method                              curl_easy_setopt(curl, .CUSTOMREQUEST, temp_c_string(method));
    if data || (method && method != "GET") curl_easy_setopt(curl, .POSTFIELDS, temp_c_string(data));
    if include_headers                     curl_easy_setopt(curl, .HEADER, 1); // simply prepends headers to body
    if method == "HEAD"                    curl_easy_setopt(curl, .NOBODY, 1);

    if headers.count {
        slist: *curl_slist;
        for headers  slist = curl_slist_append(slist, temp_c_string(it));
        curl_easy_setopt(curl, .HTTPHEADER, slist);
    }

    builder: String_Builder;
    defer free_buffers(*builder);
    curl_easy_setopt(curl, .WRITEFUNCTION, write_callback);
    curl_easy_setopt(curl, .WRITEDATA,     *builder);

    // actually execute the request. this is blocking
    curl_code: CURLcode = curl_easy_perform(curl);

    response_code: int;
    if curl_code == .OK  curl_easy_getinfo(curl, .RESPONSE_CODE, *response_code);

    response_body: string = builder_to_string(*builder);

    return response_body, response_code, curl_code;
}


size_t :: u64;
write_callback :: (ptr: *u8, size: size_t, nmemb: size_t, userdata: *void) -> size_t #c_call {
    builder := cast(*String_Builder)userdata;

    push_context {
        append(builder, ptr, xx nmemb);
    }
    
    return nmemb;
}



print_yellow :: (format_string: string, args: .. Any) {
    write_string("\n\u001b[33m");
    print(format_string, .. args);
    write_string("\u001b[0m\n");
}

main :: () {
    print_yellow("GET request: example.com");
    {
        body, code := request("example.com");
        defer free(body);
        print("response body preview:\n%\n", slice(body, 0, 64));
    }


    push_allocator(temp); // we'll use temporary storage from now on, so we don't have to free


    print_yellow("POST request: application/x-www-form-urlencoded");
    {
        body, code := request("example.com", method="POST", data="mydata=1");
        print("response code: %\n", code);
    }


    print_yellow("POST request: application/json");
    {
        body, code := request(
            url     = "example.com",
            method  = "POST",
            data    = "{'name': 'Stephen'}",
            headers = .["Content-Type: application/json"]
        );
        print("response code: %\n", code);
    }


    print_yellow("HEAD request: Download headers only");
    {
        headers, code := request("https://example.com", method="HEAD", include_headers=true);
        print("response headers: %\n", headers);
    }


    print_yellow("Ping example.com");
    for 1 .. 3 {
        start_time := seconds_since_init();
        res := request("example.com", method="HEAD");
        duration := seconds_since_init() - start_time;
        print("ping example.com: %ms\n", cast(int)(duration*1000));
    }


    print_yellow("Error handling");
    {
        body, code, curl_code := request("?example?com?");
        if curl_code != .OK {
            log_error(to_string(curl_easy_strerror(curl_code)));
        }
        print("response code: %\n", code);
    }


    print_yellow("Download File: example.txt");
    {
        body, code := request("https://example.com");
        print("bytes downloaded: %\n", body.count);
        if code == 200  write_entire_file("example.txt", body);
    }


    print_yellow("GET body and headers");
    {
        response := request("example.com", include_headers=true);
        print("response.count: %\n", response.count);

        // the response is a single string containing headers then body
        // you'll have to parse this yourself. this is a bit involved
        // so to keep this simple, that example is in http_request.jai
    }
}

#import "Basic";
#import "String";
#import "File";
