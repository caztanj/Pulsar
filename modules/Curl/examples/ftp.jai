// Here's a more sophisticated download example for Curl.
// It combines lessons learned from other Curl examples.
// It shows how to authenticate an FTP connection and adds argument parsing on top of it,
// which is commonly useful in utility programs.
//
// Made by Rafał "Veeq7" Jurkiewicz, Special thanks to ryanneph for quality assurance.
//
// This code is licensed under the MIT license.
//

#import "Basic";
#import "File";
#import "Command_Line";
#import "Curl";

// It's pretty common for utility programs to need customizablity.
// Thankfully, command line arguments are pretty trivial to parse in JAI, here we provide the fields, defaults, and descriptions.
Arguments :: struct {
    ftp      := "ftp://test.rebex.net/readme.txt"; @"?FTP Target"
    username := "demo";       @"?FTP Username"
    password := "password";   @"?FTP Password"
    target   := "readme.txt"; @"?Target filepath"
}

main :: () {
    // Here we pass our Arguments struct type 
    ok, args, is_set := parse_arguments(Arguments);
    if !ok {
        // Return when showing help menu and/or errors
        return;
    }
    
    // Arguments parsed! Let's download.
    ftp_download(args.ftp, args.target, args.username, args.password);
}

// Since callback allows a user_data pointer, we will just pass a pointer to our custom struct
User_Data :: struct {
    curl: *CURL;
    file: File;
}

// Curl expects a C function, that's why we have to use #c_call; since #c_call doesn't provide a context and JAI functions need one, we push_context.
write_callback :: (contents: *u8, count: u64, size: u64, user_data: *User_Data) -> u64 #c_call {
    total_size := count * size;
    push_context {
        // Write data to the file
        file_write(*user_data.file, contents, cast(s64) total_size);

        // Print stats
        print_curl_stats(user_data.curl);
    }
    
    return total_size;
}

print_curl_stats :: (curl: *CURL) {
    // Fetch and print stats
    total_time      : float64;
    download_speed  : float64;
    size_downloaded : float64;

    curl_easy_getinfo(curl, .TOTAL_TIME,     *total_time);
    curl_easy_getinfo(curl, .SPEED_DOWNLOAD, *download_speed);
    curl_easy_getinfo(curl, .SIZE_DOWNLOAD,  *size_downloaded);

    print("Time: %s, Speed: %MB/s, Downloaded: %MB\n", total_time, download_speed / (1024.0 * 1024), size_downloaded / (1024.0 * 1024));
}

ftp_download :: (ftp: string, target: string, username: string, password: string) -> bool {
    // Init a Curl connection and defer cleanup until the end of file scope
    curl := curl_easy_init();
    if !curl {
        print("An error occured while initting up the Curl connection, but Curl doesn't tell us why.\n");
        return false;
    }
    defer curl_easy_cleanup(curl);
    
    // Set target URL
    curl_easy_setopt(curl, .URL, temp_c_string(ftp));
    curl_easy_setopt(curl, .USERNAME, temp_c_string(username));
    curl_easy_setopt(curl, .PASSWORD, temp_c_string(password));

    // Open a file handle and defer it's cleanup
    out_file, ok := file_open(target, for_writing=true);
    if !ok {
        print("Failed to open the output file '%' for storing the download.\n", target);
        return false;
    }
    defer file_close(*out_file);

    // Set output info
    user_data: User_Data;
    user_data.curl = curl;
    user_data.file = out_file;

    curl_easy_setopt(curl, .WRITEFUNCTION, write_callback);
    curl_easy_setopt(curl, .WRITEDATA, *user_data);

    // Perform the "easy" action
    print("Downloading %...\n", target);
    error_code := curl_easy_perform(curl);
    if error_code != .OK {
        error_message := to_string(curl_easy_strerror(error_code));
        defer free(error_message);
        print("Curl Error: %\n", error_message);
        return false;
    }
    print_curl_stats(curl);
    print("File % downloaded successfully!\n", target);
    return true;
}
