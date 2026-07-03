#if OS == .WINDOWS {
    #assert(CPU == .X64);
    #load "windows_x64.jai";

    Bcrypt   :: #library,system,link_always "Bcrypt";
    oldnames :: #library,system,link_always "oldnames";
} else #if OS == .LINUX {
    #if CPU == .ARM64 {
        #load "linux_arm64.jai";
    } else #if CPU == .X64 {
        #load "linux_x64.jai";
    } else {
        #assert(false);
    }
} else #if OS == .MACOS {
    #if CPU == .ARM64 {
        #load "macos_arm64.jai";
    } else #if CPU == .X64 {
        #load "macos_x64.jai";
    } else {
        #assert(false);
    }
} else {
    #assert(false);
}