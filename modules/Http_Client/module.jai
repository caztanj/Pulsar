get_header :: (using response: Curl_Response, key: string) -> error: bool, string {
    found, value := table_find_new(*headers_table, key);
    return !found, value;
}

free :: (using response: Curl_Response) {
    if body                    free(body);
    if headers                 free(headers);
    if headers_table.allocated deinit(*headers_table);
}

Curl_Response :: struct {
    code:    int;

    headers:       string;
    headers_table: Table(string, string);

    body: string;

    curl_code: CURLcode;
}

#load "blocking.jai";
#load "concurrent.jai";

#scope_module

header_callback :: (ptr: *u8, size: size_t, nmemb: size_t, userdata: *void) -> size_t #c_call {
    headers_builder := cast(*String_Builder) userdata;

    push_context {
        header := string.{ data = ptr, count = xx nmemb };

        if starts_with(header, "HTTP/") {
            reset(headers_builder);
            return nmemb;
        }

        append(headers_builder, ptr, xx nmemb);
    }

    return nmemb;
}

parse_headers :: (headers: string) -> headers_table: Table(string, string) {
    headers_table: Table(string, string);

    start_of_line := 0;
    for i: 0..headers.count - 1 - 3 /* because we're looking 3 ahead */ {
        if headers[i] == "\r" && headers[i + 1] == "\n" {
            defer start_of_line = i + 2;

            header := string.{ data = headers.data + start_of_line, count = i - start_of_line };

            if starts_with(header, "HTTP/") continue;

            found, key, value := split_from_left(header, ":");
            if !found break;

            table_add(*headers_table, trim(key), trim(value));

            if headers[i + 2] == "\r" && headers[i + 3] == "\n" break;
        }
    }

    return headers_table;
}

write_callback :: (ptr: *u8, size: size_t, nmemb: size_t, userdata: *void) -> size_t #c_call {
    body_builder := cast(*String_Builder) userdata;

    push_context {
        append(body_builder, ptr, xx nmemb);
    }

    return nmemb;
}

size_t :: u64;

Request_Context :: struct {
    curl:            *CURL;
    user_data:       *void;
    headers_builder: String_Builder;
    body_builder:    String_Builder;
    getinfo:         (curl: *CURL) -> ();
}

#import "Basic";
#import "Curl";
#import "Hash_Table";
#import "String";
#import "System";
#import "File_Utilities";
