test_modules :: () {
    test(() => {
        test_module_1 := #string JS
            export const a = 1;
            export const b = 2;
            export default 3;
        JS

        test_module_2 := #string JS
            export * from 'test_module_1.js';
            export const c = 4;
        JS

        write_entire_file("test_module_1.js", test_module_1);
        write_entire_file("test_module_2.js", test_module_2);

        code := #string JS
            import { a, b } from 'test_module_1.js';
            import def from 'test_module_1.js';
            import * as module1 from 'test_module_1.js';
            import { a as aliasedA } from 'test_module_1.js';
            import { a as reA, c } from 'test_module_2.js';

            let result_a = a;
            let result_b = b;
            let result_def = def;
            let result_module1_a = module1.a;
            let result_module1_def = module1.default;
            let result_alias = aliasedA;
            let result_re_a = reA;
            let result_c = c;
        JS

        run_test(code);
        expect_global("result_a", .NUMBER, 1);
        expect_global("result_b", .NUMBER, 2);
        expect_global("result_def", .NUMBER, 3);
        expect_global("result_module1_a", .NUMBER, 1);
        expect_global("result_module1_def", .NUMBER, 3);
        expect_global("result_alias", .NUMBER, 1);
        expect_global("result_re_a", .NUMBER, 1);
        expect_global("result_c", .NUMBER, 4);

        file_delete("test_module_1.js");
        file_delete("test_module_2.js");
    });

    test(() => {
        test_cache := #string JS
            export const x = { a: 1 };
        JS

        write_entire_file("test_cache.js", test_cache);

        code := #string JS
            import * as mod1 from 'test_cache.js';
            import * as mod2 from 'test_cache.js';
            let areSame = (mod1 === mod2);
            let areExportsSame = (mod1.x === mod2.x);
        JS

        run_test(code);
        expect_global("areSame", .BOOLEAN, true);
        expect_global("areExportsSame", .BOOLEAN, true);

        file_delete("test_cache.js");
    });
}
