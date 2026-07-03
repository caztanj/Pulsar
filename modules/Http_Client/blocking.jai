get    :: #bake_arguments request(method = "GET");
post   :: #bake_arguments request(method = "POST");
put    :: #bake_arguments request(method = "PUT");
delete :: #bake_arguments request(method = "DELETE");
head   :: #bake_arguments request(method = "HEAD");

request :: (url: string, data := "", method := "", headers := string.[], include_headers := false, follow_redirects := false, setopt: (curl: *CURL) -> () = null, getinfo: (curl: *CURL) -> () = null) -> error: bool, Curl_Response {
    curl := curl_easy_init();
    if curl == null return true, .{};

    curl_easy_setopt(curl, .URL, temp_c_string(url));

    exe_path := get_path_of_running_executable();
    cacert_path := tprint("%/cacert.pem", path_strip_filename(exe_path));
    if file_exists(cacert_path) {
        curl_easy_setopt(curl, .CAINFO, temp_c_string(cacert_path));
    }

    if follow_redirects {
        curl_easy_setopt(curl, .FOLLOWLOCATION, 1);
    }

    if method {
        curl_easy_setopt(curl, .CUSTOMREQUEST, temp_c_string(method));
    }

    if data {
        curl_easy_setopt(curl, .POSTFIELDS, temp_c_string(data));
    }

    if method == "HEAD" {
        curl_easy_setopt(curl, .NOBODY, 1);
    }

    headers_builder: String_Builder;
    defer free_buffers(*headers_builder);

    if headers.count > 0 {
        curl_easy_setopt(curl, .HEADERFUNCTION, header_callback);
        curl_easy_setopt(curl, .HEADERDATA,     *headers_builder);
    }

    body_builder: String_Builder;
    defer free_buffers(*body_builder);

    curl_easy_setopt(curl, .WRITEFUNCTION, write_callback);
    curl_easy_setopt(curl, .WRITEDATA,     *body_builder);

    curl_easy_setopt(curl, .USERAGENT, "curl");

    if setopt setopt(curl);

    response: Curl_Response;
    response.curl_code = curl_easy_perform(curl);

    if response.curl_code == .OK {
        if getinfo getinfo(curl);

        curl_easy_getinfo(curl, .RESPONSE_CODE, *response.code);

        if builder_string_length(*body_builder)    response.body          = builder_to_string(*body_builder);
        if builder_string_length(*headers_builder) response.headers       = builder_to_string(*headers_builder);
        if response.headers                        response.headers_table = parse_headers(response.headers);
    }

    return false, response;
}
