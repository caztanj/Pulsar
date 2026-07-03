function test() {
    let a = 1;

    return function() {
        print(a);
    }
}

test()()