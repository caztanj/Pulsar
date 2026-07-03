//
// Examples of error checking and log-based debugging when using libcurl
//
//
// Libcurl is a client-side wrapper around several protocols (http, ftp, ssl, ...) and tries to
// offer an "easy" interface for using all of these. In reality, this means exposing a small
// user-facing API, but forcing all configurability through a single multi-purpose option setter
// `curl_easy_setopt()` and getter `curl_easy_getinfo()`.
//
// This makes the debugging process frustrating but there are a few ways to reduce the pain ranging
// from lightweight macros to heavyweight detailed logging.
//
// Example provided by Ryan Neph with feedback from by Rafał "Veeq7" Jurkiewicz.
//
// This code is licensed under the MIT license.
//

#import "Basic";
#import "Curl";

//
// Set a curl option and log errors
//
set_curl_option :: (curl: *CURL, option: CURLoption, parameter: $T) -> success: bool, CURLcode {
    #if type_of(parameter) == string {
        error_code := curl_easy_setopt(curl, option, temp_c_string(parameter));
    } else {
        error_code := curl_easy_setopt(curl, option, parameter);
    }

    if error_code != .OK {
        print("Curl error (%) while setting option '%': %.\n",
              error_code, option, to_string(curl_easy_strerror(error_code)));
        return false, error_code;
    }

    return true, error_code;
}

//
// Peform a curl action and log errors
//
perform_curl_action :: (curl: *CURL) -> success: bool, CURLcode {
    error_code := curl_easy_perform(curl);
    if error_code != .OK {
        print("Curl error (%) while performing action: %.\n",
              error_code, to_string(curl_easy_strerror(error_code)));
        return false, error_code;
    }

    return true, error_code;
}

//
// Show how to check every return status for errors and log them
//
do_basic_error_checking :: (curl: *CURL) {
    // set some options and log errors for each
    set_curl_option(curl, .URL,          "https://example.com/");
    set_curl_option(curl, .PORT,         -9999                 ); // expected to fail since ports < 0 are invalid
    set_curl_option(curl, .USERNAME,     "some_user"           );
    set_curl_option(curl, .PASSWORD,     "some_password"       );
    perform_curl_action(curl);
}

do_detailed_error_messages :: (curl: *CURL) {
    error_buf: [256]u8;
    set_curl_option(curl, .ERRORBUFFER, *error_buf);

    // now set some bad options and observe the output
    set_curl_option(curl, .URL, "a_bad_url");
    if !perform_curl_action(curl) && error_buf[0] != #char "\0" {
        log_error("(detailed curl error): %\n", to_string(error_buf.data, c_style_strlen(error_buf.data)));
    }

    // we can disable this behavior by passing null instead.
    set_curl_option(curl, .ERRORBUFFER, null);
}

// The generated bindings don't include this, so we can define it locally.
CURLinfotype :: enum s32 {
    TEXT         :: 0;
    HEADER_IN    :: 1;
    HEADER_OUT   :: 2;
    DATA_IN      :: 3;
    DATA_OUT     :: 4;
    SSL_DATA_IN  :: 5;
    SSL_DATA_OUT :: 6;
}

debug_callback :: (curl: *CURL, info_type: CURLinfotype, data: *u8, data_count: u64,
                   userdata: *void) #c_call
{
    // C library callbacks (marked with #c_call) don't provide a context, but jai functions called
    // within (such as print()) require it, so one must created and pushed.
    push_context {
        temp_string := to_string(data, xx data_count);
        if info_type == {
            case .TEXT;         #through;
            case .HEADER_IN;    #through;
            case .HEADER_OUT;
                print("  (%): %", info_type, temp_string);

            case .DATA_IN;      #through;
            case .DATA_OUT;     #through;
            case .SSL_DATA_IN;  #through;
            case .SSL_DATA_OUT;
                print("  (%): [data length=%]\n", info_type, temp_string.count);
        }
    }
}

//
// Show how to override the default VERBOSE output with our own debug messages
//
do_custom_debug_logging :: (curl: *CURL) {
    set_curl_option(curl, .URL, "https://example.com/");

    // First see how the VERBOSE output looks
    print("Here is the VERBOSE output for a simple connection initiation:\n");
    curl_easy_setopt(curl, .VERBOSE, 1);
    // send a GET request to the server so we have some interesting output
    curl_easy_perform(curl);
    print("\n");


    // Next override with our own callback
    print("Here is our custom debug output instead:\n");
    curl_easy_setopt(curl, .DEBUGFUNCTION, debug_callback);
    // send another GET request
    curl_easy_perform(curl);

    // we can disable this behavior by passing null instead
    curl_easy_setopt(curl, .DEBUGFUNCTION, null);
    curl_easy_setopt(curl, .VERBOSE, 0);
}

//
// Setup a session that is automatically closed at the end of the caller's scope
//
Setup_Scoped_Curl_Session :: () -> *CURL #expand {
    curl := curl_easy_init();
    if curl == null {
        // libcurl doesn't tell us why this failed, so this is the best we can do when reporting the
        // error.
        print("Curl failed to initialize\n");
        return null;
    }

    // as a backticked defer, this is executed at the end of the caller's scope
    `defer curl_easy_cleanup(curl);

    return curl;
}

main :: () {
    curl := Setup_Scoped_Curl_Session();
    if !curl  exit(1);

    // For this example, we set an empty WRITEFUNCTION callback to discard the downloaded html and
    // avoid spamming the terminal with its contents.
    // For an actual example of how to define the WRITEFUNCTION callback see the "download.jai" example.
    no_write_callback :: (data: *void, data_count: u64, nmemb: u64, userdata: *void) ->u64 #c_call {
        return data_count * nmemb;
    }

    set_curl_option(curl, .WRITEFUNCTION, no_write_callback);

    // After setting up the curl session, it is configured with one or more options by calling
    // curl_easy_setopt() for each and actions are performed with curl_easy_perform(). Each call
    // produces an error code.

    // We can check the result code for each call, and log generic error strings immediately.
    print("1. Basic error checking\n");
    do_basic_error_checking(curl);
    print("\n");

    // Alternatively, we can provide a buffer to the library and obtain more detailed error messages.
    print("2. Detailed error messages\n");
    do_detailed_error_messages(curl);
    print("\n");

    // We can also log our own custom messages when the default VERBOSE logging isn't enough.
    print("3. Custom debug logging\n");
    do_custom_debug_logging(curl);
    print("\n");

    // By default, HTTP requests that receive a response containing one of the HTTP error codes
    // (>=400) are silently ignored, and a CURLcode.OK is returned to the caller.
    // If we want to get CURLcode.HTTP_RETURNED_ERROR instead, we can do the following:
    print("4. Fail on HTTP error responses\n");
    set_curl_option(curl, .FAILONERROR, 1);
    set_curl_option(curl, .URL, "https://example.com/not_a_real_page");
    success, error_code := perform_curl_action(curl);

    if error_code == .HTTP_RETURNED_ERROR {
        print("HTTP GET request resulted in an HTTP error response\n");
    }

    print("\n");

    // the curl session is cleaned up now due to the backticked defer in Setup_Scoped_Curl_Session().
}
