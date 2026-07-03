test_file :: () {
    test(() => {
        write_entire_file("test_file_for_js_test.txt", "Hello World!");

        code := #string JS
            let content = File.read_entire_file("test_file_for_js_test.txt");
            let isString = typeof content === "string";
            let stringLen = content.length;

            let binary = File.read_entire_file("test_file_for_js_test.txt", true);
            let isUint8Array = binary instanceof Uint8Array;
            let binaryLen = binary.length;

            let firstByte = binary[0];
            let secondByte = binary[1];

            binary[0] = 65;
            let newFirstByte = binary[0];

            File.write_entire_file("test_file_write.txt", "Test");
            File.append_to_file("test_file_write.txt", " Append");
            let written = File.read_entire_file("test_file_write.txt");

            let exists_true = File.exists("test_file_write.txt");
            let exists_false = File.exists("does_not_exist.txt");

            let size = File.get_size("test_file_write.txt");

            File.copy("test_file_write.txt", "test_file_copy.txt");
            let copy_exists = File.exists("test_file_copy.txt");

            File.move("test_file_copy.txt", "test_file_move.txt");
            let move_exists = File.exists("test_file_move.txt");
            let copy_gone = !File.exists("test_file_copy.txt");

            File.delete("test_file_move.txt");
            let move_gone = !File.exists("test_file_move.txt");

            let is_dir = File.is_directory(".");
            let is_not_dir = File.is_directory("test_file_write.txt");

            let list = File.list_directory(".");
            let list_is_array = Array.isArray(list);
            let list_has_files = list.length > 0;

            File.delete("test_file_write.txt");
        JS

        run_test(code, permissions = .FILESYSTEM);
        expect_global("content", .STRING, "Hello World!");
        expect_global("isString", .BOOLEAN, true);
        expect_global("stringLen", .NUMBER, 12.0);

        expect_global("isUint8Array", .BOOLEAN, true);
        expect_global("binaryLen", .NUMBER, 12.0);

        expect_global("firstByte", .NUMBER, 72.0);
        expect_global("secondByte", .NUMBER, 101.0);

        expect_global("newFirstByte", .NUMBER, 65.0);

        expect_global("written", .STRING, "Test Append");
        expect_global("exists_true", .BOOLEAN, true);
        expect_global("exists_false", .BOOLEAN, false);
        expect_global("size", .NUMBER, 11.0);
        expect_global("copy_exists", .BOOLEAN, true);
        expect_global("move_exists", .BOOLEAN, true);
        expect_global("copy_gone", .BOOLEAN, true);
        expect_global("move_gone", .BOOLEAN, true);
        expect_global("is_dir", .BOOLEAN, true);
        expect_global("is_not_dir", .BOOLEAN, false);
        expect_global("list_is_array", .BOOLEAN, true);
        expect_global("list_has_files", .BOOLEAN, true);

        file_delete("test_file_for_js_test.txt");
    });
}
