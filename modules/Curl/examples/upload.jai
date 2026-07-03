// This example shows how you can upload a file to a remote location using Curl
// In contrast to the basic download example, this one passes a pointer to a custom struct to the callback
//
// Made by Rafał "Veeq7" Jurkiewicz, Special thanks to ryanneph for quality assurance.
//
// This code is licensed under the MIT license.
//

#import "Basic";
#import "File";
#import "String";
#import "System";
#import "Curl";

FILENAME :: "epic.txt";

main :: () {
    // Target is a dummy filepath into a local folder called target;
    // in a real application this path would be remote. For now we use the path to the executable
    // in order to find the file, just so that something weird doesn't happen incorrectly if you
    // run it from another folder.
    directory_path := path_strip_filename(get_path_of_running_executable());
    make_directory_if_it_does_not_exist(tprint("%target", directory_path));
    file   := tprint("%1%2",              directory_path, FILENAME);
    target := tprint("file:///%target/%", directory_path, FILENAME);
    upload(file, target);
}

// Since callback allows a user_data pointer, we will just pass a pointer to our custom struct
User_Data :: struct {
    curl: *CURL;
    file: File;
}

// Curl expects a C function, that's why we have to use #c_call, and since #c_call doesn't provide a context and JAI function need it, we push_context
// The final parameter is originally a void pointer intended for user data, this means we can use it to pass a pointer to any data
// In this example we are passing pointer to our own structure, with all the necessery data. This resolves the potential problem mentioned in download.jai
read_callback :: (contents: *u8, count: u64, size: u64, user_data: *User_Data) -> u64 #c_call {
    total_size := count * size;

    push_context {
        // Read data to send
        ok, bytes_read := file_read(user_data.file, contents, cast(s64) total_size);

        // Print stats
        print_curl_stats(user_data.curl);

        // Here it's important we return bytes_read from file_read, because otherwise the file transfer will never end
        return cast(u64) bytes_read;
    }
}

print_curl_stats :: (curl: *CURL) {
    // Fetch and prints stats
    total_time    : float64;
    upload_speed  : float64;
    size_uploaded : float64;

    curl_easy_getinfo(curl, .TOTAL_TIME,   *total_time);
    curl_easy_getinfo(curl, .SPEED_UPLOAD, *upload_speed);
    curl_easy_getinfo(curl, .SIZE_UPLOAD,  *size_uploaded);

    print("Time: %s, Speed: %MB/s, Size: %MB\n", total_time, upload_speed / 1024.0 / 1024.0, size_uploaded / 1024.0 / 1024.0);
}

upload :: (file: string, target: string) -> bool {
    // Init Curl and setup a deferred cleanup
    curl := curl_easy_init();
    if !curl {
        print("An error occured while initting up the Curl connection, but Curl doesn't tell us why.\n");
        return false;
    }
    defer curl_easy_cleanup(curl);

    // Set target URL and inform Curl we are uploading
    curl_easy_setopt(curl, .URL, temp_c_string(target));
    curl_easy_setopt(curl, .UPLOAD, 1);

    // Open a file handle and defer it's cleanup
    in_file, ok := file_open(file);
    if !ok {
        print("Failed to open the input file '%' for uploading it's data.\n", target);
        return false;
    }

    defer file_close(*in_file);

    // Set input info
    user_data: User_Data;
    user_data.curl = curl;
    user_data.file = in_file;

    curl_easy_setopt(curl, .READFUNCTION, read_callback);
    curl_easy_setopt(curl, .READDATA, *user_data);

    // Perform the "easy" action
    print("Uploading %...\n", file);
    error_code := curl_easy_perform(curl);
    if error_code != .OK {
        error_message := to_string(curl_easy_strerror(error_code)); // This would benefit from temp alloc
        defer free(error_message);
        print("Curl Error: %\n", error_message);
        return false;
    }

    print_curl_stats(curl);
    print("File % uploaded successfully!\n", file);
    return true;
}
