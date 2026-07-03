test_switch :: () {
    test(() => {
        code := #string JS
            let x = 1;
            let result = 0;
            switch(x) {
                case 1:
                    result = 10;
                    break;
                case 2:
                    result = 20;
                    break;
            }
        JS

        run_test(code);
        expect_global("result", .NUMBER, 10);
    });

    test(() => {
        code := #string JS
            let x = 2;
            let result = 0;
            switch(x) {
                case 1:
                    result = 10;
                    break;
                case 2:
                    result = 20;
                    break;
            }
        JS

        run_test(code);
        expect_global("result", .NUMBER, 20);
    });

    test(() => {
        code := #string JS
            let x = 3;
            let result = 0;
            switch(x) {
                case 1:
                    result = 10;
                    break;
                case 2:
                    result = 20;
                    break;
                default:
                    result = 30;
            }
        JS

        run_test(code);
        expect_global("result", .NUMBER, 30);
    });

    test(() => {
        code := #string JS
            let x = 1;
            let result = 0;
            switch(x) {
                case 1:
                    result = 10;
                case 2:
                    result = 20;
                    break;
            }
        JS

        run_test(code);
        expect_global("result", .NUMBER, 20);
    });

    test(() => {
        code := #string JS
            let x = 1;
            let result = 0;
            switch(x) {
                case 1:
                case 2:
                    result = 20;
                    break;
            }
        JS

        run_test(code);
        expect_global("result", .NUMBER, 20);
    });

    test(() => {
        code := #string JS
            let result = 0;
            for (let i = 0; i < 3; i = i + 1) {
                switch(i) {
                    case 0:
                        result = result + 10;
                        break;
                    case 1:
                        result = result + 20;
                        break;
                    default:
                        result = result + 30;
                }
            }
        JS

        run_test(code);
        expect_global("result", .NUMBER, 60);
    });

    test(() => {
        code := #string JS
            let result = 0;
            for (let i = 0; i < 3; i = i + 1) {
                switch(i) {
                    case 0:
                        continue;
                    case 1:
                        result = result + 20;
                        break;
                }
                result = result + 1;
            }
        JS

        run_test(code);
        expect_global("result", .NUMBER, 22);
    });

    test(() => {
        code := #string JS
            let x = 'a';
            let result = 0;
            switch(x) {
                case 'a':
                    result = 1;
                    break;
                case 'b':
                    result = 2;
                    break;
            }
        JS

        run_test(code);
        expect_global("result", .NUMBER, 1);
    });

    test(() => {
        code := #string JS
            let x = 1;
            let result = 0;
            switch(x) {
                default:
                    result = 30;
                    break;
                case 1:
                    result = 10;
                    break;
            }
        JS

        run_test(code);
        expect_global("result", .NUMBER, 10);
    });
}
