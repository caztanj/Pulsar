test_classes :: () {
    test(() => {
        code := #string JS
            class Person {
                constructor(name) {
                    this.name = name;
                }

                greet() {
                    return "Hello " + this.name;
                }
            }

            let p = new Person("Alice");

            let result = p.greet();
        JS;

        run_test(code);
        expect_global("Person", .FUNCTION, null);
        expect_global("p",      .OBJECT,   null);
        expect_global("result", .STRING,   "Hello Alice");
    });

    test(() => {
        code := #string JS
            class MathUtils {
                static add(a, b) {
                    return a + b;
                }
            }

            let sum = MathUtils.add(5, 7);
        JS;

        run_test(code);
        expect_global("sum", .NUMBER, 12);
    });

    test(() => {
        code := #string JS
            class Animal {
                constructor(name) {
                    this.name = name;
                }
                speak() {
                    return this.name + " makes a noise.";
                }
            }

            class Cat extends Animal {}
            Cat.prototype.speak = function() { return this.name + " meows."; };

            let cat = new Cat("Whiskers");
            cat.name = "Whiskers";

            let catSpeak = cat.speak();
        JS;

        run_test(code);
        expect_global("catSpeak", .STRING, "Whiskers meows.");
    });
}
