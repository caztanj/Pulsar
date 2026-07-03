main :: () {
    source, success := read_entire_file("benchmarks/suite.js");
    if !success {
        source, success = read_entire_file("suite.js");
        if !success {
            print("Could not read suite.js or benchmarks/suite.js\n");
            return;
        }
    }

    print("Running benchmark...\n");
    vm := run(source);
    defer { deinit(vm.program); deinit(vm); }
}

#import "Basic";
#import "File";
#import "String";

#import,file "../module.jai";