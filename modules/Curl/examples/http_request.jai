// This example implements an http_request module
// that handles robust parsing of response headers into a Hash_Table
// If you simply need to make http requests without parsing response headers, see http_request_simple.jai

#import "Curl";
#import "Hash_Table";

size_t :: u64;

print_yellow :: (format_string: string, args: .. Any) {
    write_string("\n\u001b[33m");
    print(format_string, .. args);
    write_string("\u001b[0m\n");
}

main :: () {


    print_yellow("GET request: example.com");
    {
        res := get("example.com");
        defer free(res);
        print("response body preview:\n%\n", slice(res.body, 0, 64));
    }


    push_allocator(temp); // we'll use temporary storage from now on, so we don't have to free


    print_yellow("POST request: application/x-www-form-urlencoded");
    {
        res := post("example.com", data="a=1&b=2");
        print("response code: %\n", res.code);
    }


    print_yellow("POST request: application/json");
    {
        res := post(
            url     = "example.com",
            data    = "{'name': 'Stephen'}",
            headers = .["Content-Type: application/json"]
        );
        print("response code: %\n", res.code);
    }


    print_yellow("HEAD request: Download headers only");
    {
        res := head("example.com", include_headers=true);
        print("body.count: %\n", res.body.count);
        print("headers_table.count: %\n", res.headers_table.count);
    }


    print_yellow("Ping example.com");
    for 1 .. 3 {
        start_time := seconds_since_init();
        res := head("example.com");
        duration := seconds_since_init() - start_time;
        print("ping example.com: %ms\n", cast(int)(duration*1000));
    }


    print_yellow("Error handling");
    {
        res := get("?example?com?");
        if res.curl_code != .OK {
            log_error(to_string(curl_easy_strerror(res.curl_code)));
        }
        print("response code: %\n", res.code);
    }


    print_yellow("Download File: example.txt");
    {
        res := get("https://example.com/");
        print("bytes downloaded: %\n", res.body.count);
        if res.code == 200  write_entire_file("example.txt", res.body);
    }


    print_yellow("GET body and parsed headers");
    {
        res := get("example.com", include_headers=true);
        print("Content-Type :: %\n", get_header(res, "Content-Type"));
        // print("response raw headers:\n%", res.headers);
        // print("response body:\n%", res.body);
        // print("parsed headers_table:\n");
        // for val, key: res.headers_table  print("% :: %\n", key, val);
    }


    print_yellow("API Authentication");
    {
        res := get(
            url             = "https://example.com/api/user",
            include_headers = true,                             // curl -i
            data            = "api_key=TOKEN",                  // curl -d
            headers         = .["Authorization: Bearer TOKEN"], // curl -H

            setopt = curl => {
                curl_easy_setopt(curl, .USERPWD, "USER:TOKEN"); // curl -u
            }
        );
        rate_limit := to_integer(get_header(res, "x-rate-limit"));
        print("response code: %\nrate limit: %", res.code, rate_limit);
    }
}


Curl_Response :: struct {
    body          : string;
    headers       : string;
    headers_table : Table(string, string);
    code          : int;
    curl_code     : CURLcode;
}

get    :: #bake_arguments request(method="GET");
post   :: #bake_arguments request(method="POST");
put    :: #bake_arguments request(method="PUT");
delete :: #bake_arguments request(method="DELETE");
head   :: #bake_arguments request(method="HEAD");

request :: (url: string, data: string = "", method: string = "", headers: [] string = .[], include_headers: bool = false, setopt: (curl: *CURL)->()=null, getinfo: (curl: *CURL)->()=null) -> res: Curl_Response {
    curl := curl_easy_init();
    assert(curl != null);
    defer curl_easy_cleanup(curl);

    // url
    curl_easy_setopt(curl, .URL, temp_c_string(url));

    // method
    if method {
        curl_easy_setopt(curl, .CUSTOMREQUEST, temp_c_string(method));
    }

    // data
    if data || (method && method != "GET") {
        curl_easy_setopt(curl, .POSTFIELDS, temp_c_string(data));
    }

    // headers - your request headers
    if headers.count {
        slist: *curl_slist;
        for headers slist = curl_slist_append(slist, temp_c_string(it));
        curl_easy_setopt(curl, .HTTPHEADER, slist);
    }

    // nobody
    if method == "HEAD" curl_easy_setopt(curl, .NOBODY, 1);

    // include_headers - parses response headers
    headers_builder: String_Builder;
    defer free_buffers(*headers_builder);
    if include_headers {
        curl_easy_setopt(curl, .HEADERFUNCTION, header_callback);
        curl_easy_setopt(curl, .HEADERDATA,     *headers_builder);
    }

    // our buffer for downloaded body data
    body_builder: String_Builder;
    defer free_buffers(*body_builder);
    curl_easy_setopt(curl, .WRITEFUNCTION, write_callback);
    curl_easy_setopt(curl, .WRITEDATA,     *body_builder);


    curl_easy_setopt(curl, .USERAGENT, "curl"); // some sites require a User-Agent

    // setopt - callback function used to call curl_easy_setopt
    if setopt setopt(curl);


    // actually execute the request. this is blocking
    res: Curl_Response;
    res.curl_code = curl_easy_perform(curl);

    if res.curl_code == .OK {
        // getinfo - callback function used to call curl_easy_getinfo
        if getinfo getinfo(curl);

        curl_easy_getinfo(curl, .RESPONSE_CODE, *res.code);

        if builder_string_length(*body_builder)    res.body    = builder_to_string(*body_builder);
        if builder_string_length(*headers_builder) res.headers = builder_to_string(*headers_builder);
        if res.headers                             res.headers_table = parse_headers(res.headers);
    }

    return res;
}

// called once for each complete header line
header_callback :: (ptr: *u8, size: size_t, nmemb: size_t, userdata: *void) -> size_t #c_call {
    headers_builder := cast(*String_Builder)userdata;

    push_context {
        header: string = ---;
        header.data = ptr;
        header.count = xx nmemb;

        // when using .FOLLOWLOCATION, we have to clear old headers after redirecting
        // we know all our headers are expired if we receive a new HTTP status "header"
        if begins_with(header, "HTTP/") {
            reset(headers_builder);
            return nmemb;
        }

        append(headers_builder, ptr, xx nmemb);
    }

    return nmemb;
}

parse_headers :: (headers: string) -> headers_table: Table(string, string) {
    headers_table: Table(string, string);
    init(*headers_table);

    if !headers return headers_table;

    startofline := 0;
    for i: 0 .. headers.count-1 -3/*because we're looking 3 ahead*/ {
        if headers[i] == #char "\r" && headers[i+1] == #char "\n" {
            defer startofline = i + 2;

            header: string = ---;
            header.data = headers.data + startofline;
            header.count = i - startofline;

            if begins_with(header, "HTTP/") continue; // first line is the status code. not a header

            found, key, val := split_from_left(header, ": ");
            if !found break; // parse error
            table_add(*headers_table, key, val);

            if headers[i+2] == #char "\r" && headers[i+3] == #char "\n" {
                break; // \r\n\r\n found. end of headers
            }
        }
    }

    return headers_table;
}

// called when a chunk of the body is downloaded and ready
write_callback :: (ptr: *u8, size: size_t, nmemb: size_t, userdata: *void) -> size_t #c_call {
    body_builder := cast(*String_Builder)userdata;

    push_context {
        append(body_builder, ptr, xx nmemb);
    }

    return nmemb;
}


get_header :: (using res: Curl_Response, key: string) -> val: string {
    found, val := table_find(*headers_table, key);
    return ifx found then val;
}

free :: (using res: Curl_Response) {
    if body                    free(body);
    if headers                 free(headers);
    if headers_table.allocated deinit(*headers_table);
}

#import "Basic";
#import "String";
#import "File";
