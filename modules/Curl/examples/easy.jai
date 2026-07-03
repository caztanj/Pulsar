//
// This code is licensed under the MIT license.
//

#import "Curl";
#import "Basic";

main :: () {
    handle := curl_easy_init();
    assert(handle != null);

    curl_easy_setopt(handle, .URL, "http://example.com");

    print("[Easy] Perform URL request...\n");
    res : CURLcode = curl_easy_perform(handle);
    print("[Easy] %\n", res);

    curl_easy_cleanup(handle);
}
