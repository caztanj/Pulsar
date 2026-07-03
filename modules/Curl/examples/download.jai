// Here's a pretty straightfoward example of how to download a file with Curl.
// It shows what you need to be aware to properly interact with a C language library from JAI.
// Shows how to setup a write callback and how to read connection stats.
//
// Made by Rafał "Veeq7" Jurkiewicz, Special thanks to ryanneph for quality assurance.

#import "Basic";
#import "File";
#import "Curl";

main :: () {
    URL             :: "https://curl.se/windows/dl-7.83.1/curl-7.83.1-win64-mingw.zip";
    TARGET_FILENAME :: "curl.zip";

    download(URL, TARGET_FILENAME);
}

// Curl expects a C function, that's why we have to use #c_call, and since #c_call doesn't provide a context and JAI function need it, we push_context
write_callback :: (contents: *u8, count: u64, size: u64, file: *File) -> u64 #c_call {
    total_size := count * size;
    push_context {
        // Write data to the file
        file_write(file, contents, cast(s64) total_size);

        // Print stats
        print_curl_stats();
    }

    return total_size;
}

print_curl_stats :: () {
    // Fetch and print stats
    total_time      : float64;
    download_speed  : float64;
    size_downloaded : float64;

    curl_easy_getinfo(curl, .TOTAL_TIME,     *total_time);
    curl_easy_getinfo(curl, .SPEED_DOWNLOAD, *download_speed);
    curl_easy_getinfo(curl, .SIZE_DOWNLOAD,  *size_downloaded);

    print("Time: %s, Speed: %MB/s, Downloaded: %MB\n", total_time, download_speed / 1024.0 / 1024.0, size_downloaded / 1024.0 / 1024.0);
}

download :: (url: string, target: string) -> bool {
    // Init Curl and setup a deferred cleanup
    curl = curl_easy_init();
    if !curl {
        print("An error occured while initting up the Curl connection, but Curl doesn't tell us why.\n");
        return false;
    }
    defer curl_easy_cleanup(curl);

    // Set target URL
    // Curl expect a null terminated string, since it's a C library.
    // We convert url to a c string, using temp_c_string (which uses a temporary allocator)
    curl_easy_setopt(curl, .URL, temp_c_string(url));

    // Set output info
    out_file, ok := file_open(target, for_writing=true);
    if !ok {
        print("Failed to open the output file '%' for storing the download.\n", target);
        return false;
    }
    defer file_close(*out_file);
    curl_easy_setopt(curl, .WRITEFUNCTION, write_callback);
    curl_easy_setopt(curl, .WRITEDATA, *out_file);

    // Perform the "easy" action
    print("Downloading %...\n", target);
    error_code := curl_easy_perform(curl);
    if error_code != .OK {
        error_message := to_string(curl_easy_strerror(error_code));
        defer free(error_message);
        print("Curl Error: %\n", error_message);
        return false;
    }
    print_curl_stats();
    print("File % downloaded successfully!\n", target);
    return true;
}

// We use a global to pass Curl instance to the callback, since we need it for fetching stats.
// Another potential solution is to pass a custom struct pointer in WRITEDATA, that includes both the file info and curl instance.
// That approach is probably more flexible in bigger applications, since it allows you to pass more things, without expossing them.
// It also doesn't limit you to one instance, which might not be desirable, for complex and/or multithreaded scenarios .
// Other curl examples explore that approach.
curl: *CURL;
