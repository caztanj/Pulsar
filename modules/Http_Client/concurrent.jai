http_client_init :: (client: *Http_Client) -> bool {
    client.multi_handle = curl_multi_init();
    if !client.multi_handle return false;

    client.events.allocator = context.default_allocator;

    return true;
}

http_client_deinit :: (client: *Http_Client) {
    for client.active_requests {
        curl_multi_remove_handle(client.multi_handle, it.curl);
        curl_easy_cleanup(it.curl);
        free_buffers(*it.headers_builder);
        free_buffers(*it.body_builder);
        free(it);
    }

    deinit(*client.active_requests);

    if client.multi_handle {
        curl_multi_cleanup(client.multi_handle);
        client.multi_handle = null;
    }

    array_reset(*client.events);
}

http_client_request :: (client: *Http_Client, url: string, data := "", method := "", headers := string.[], user_data: *void = null, follow_redirects := false, setopt: (curl: *CURL) -> () = null, getinfo: (curl: *CURL) -> () = null) -> error: bool {
    curl := curl_easy_init();
    if curl == null return true;

    request_context := New(Request_Context);
    request_context.curl = curl;
    request_context.user_data = user_data;
    request_context.getinfo = getinfo;

    request_context.headers_builder.allocator = context.allocator;
    request_context.body_builder.allocator    = context.allocator;

    curl_easy_setopt(curl, .URL, temp_c_string(url));

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

    curl_easy_setopt(curl, .HEADERFUNCTION, header_callback);
    curl_easy_setopt(curl, .HEADERDATA,     *request_context.headers_builder);

    curl_easy_setopt(curl, .WRITEFUNCTION, write_callback);
    curl_easy_setopt(curl, .WRITEDATA,     *request_context.body_builder);

    curl_easy_setopt(curl, .USERAGENT, "curl");

    if setopt setopt(curl);

    table_add(*client.active_requests, curl, request_context);

    code := curl_multi_add_handle(client.multi_handle, curl);
    if code != .OK {
        table_remove(*client.active_requests, curl);
        curl_easy_cleanup(curl);
        free(request_context);
        return true;
    }

    return false;
}

http_client_poll :: (client: *Http_Client) -> [] Http_Client_Event {
    array_reset(*client.events);

    running_handles: s32;
    curl_multi_perform(client.multi_handle, *running_handles);

    msg_remaining: s32;
    msg := curl_multi_info_read(client.multi_handle, *msg_remaining);
    while msg {
        if msg.msg == .DONE {
            curl := msg.easy_handle;
            result := msg.data.result;

            request_context_pointer := table_find_pointer(*client.active_requests, curl);
            if request_context_pointer {
                request_context := request_context_pointer.*;

                response: Curl_Response;
                response.curl_code = result;

                if result == .OK {
                    if request_context.getinfo request_context.getinfo(curl);

                    curl_easy_getinfo(curl, .RESPONSE_CODE, *response.code);

                    if builder_string_length(*request_context.body_builder)    response.body          = builder_to_string(*request_context.body_builder);
                    if builder_string_length(*request_context.headers_builder) response.headers       = builder_to_string(*request_context.headers_builder);
                    if response.headers                                        response.headers_table = parse_headers(response.headers);
                }

                event: Http_Client_Event;
                event.response = response;
                event.user_data = request_context.user_data;
                array_add(*client.events, event);

                curl_multi_remove_handle(client.multi_handle, curl);
                curl_easy_cleanup(curl);
                free_buffers(*request_context.headers_builder);
                free_buffers(*request_context.body_builder);
                table_remove(*client.active_requests, curl);
                free(request_context);
            }
        }

        msg = curl_multi_info_read(client.multi_handle, *msg_remaining);
    }

    return client.events;
}

Http_Client :: struct {
    multi_handle:    *CURLM;
    active_requests: Table(*CURL, *Request_Context);
    events:          [..] Http_Client_Event;
}

Http_Client_Event :: struct {
    response:  Curl_Response;
    user_data: *void;
}