import Nimble
import PathKit
import Quick
import SourceryStencil

@testable import SourceryFramework
@testable import SourceryRuntime

#if SWIFT_PACKAGE
    import Foundation
    @testable import SourceryLib
#else
    @testable import Sourcery
#endif

class StencilTemplateSpec: QuickSpec {
    // swiftlint:disable:next function_body_length
    override func spec() {

        describe("StencilTemplate") {

            func generate(_ template: String) -> String {
                let arrayAnnotations = Variable(
                    name: "annotated1", typeName: TypeName(name: "MyClass"))
                arrayAnnotations.annotations = ["Foo": ["Hello", "beautiful", "World"] as NSArray]
                let singleAnnotation = Variable(
                    name: "annotated2", typeName: TypeName(name: "MyClass"))
                singleAnnotation.annotations = ["Foo": "HelloWorld" as NSString]
                return
                    (try? Generator.generate(
                        nil,
                        types: Types(types: [
                            Class(
                                name: "MyClass",
                                variables: [
                                    Variable(
                                        name: "lowerFirstLetter",
                                        typeName: TypeName(name: "myClass")),
                                    Variable(
                                        name: "upperFirstLetter",
                                        typeName: TypeName(name: "MyClass")),
                                    arrayAnnotations,
                                    singleAnnotation,
                                ])
                        ]), functions: [], template: StencilTemplate(templateString: template)))
                    ?? ""
            }

            describe("json") {
                context("given dictionary") {
                    let context = TemplateContext(
                        parserResult: nil,
                        types: Types(types: []),
                        functions: [],
                        arguments: ["json": ["Version": 1] as NSDictionary]
                    )

                    it("renders unpretty json") {
                        let result = try? StencilTemplate(
                            templateString: "{{ argument.json | json }}"
                        ).render(context)
                        expect(result).to(equal("{\"Version\":1}"))
                    }
                    it("renders pretty json") {
                        let result = try? StencilTemplate(
                            templateString: "{{ argument.json | json:true }}"
                        ).render(context)
                        expect(result).to(equal("{\n  \"Version\" : 1\n}"))
                    }
                }
                context("given array") {
                    let context = TemplateContext(
                        parserResult: nil,
                        types: Types(types: []),
                        functions: [],
                        arguments: ["json": ["a", "b"] as NSArray]
                    )

                    it("renders unpretty json") {
                        let result = try? StencilTemplate(
                            templateString: "{{ argument.json | json }}"
                        ).render(context)
                        expect(result).to(equal("[\"a\",\"b\"]"))
                    }
                    it("renders pretty json") {
                        let result = try? StencilTemplate(
                            templateString: "{{ argument.json | json:true }}"
                        ).render(context)
                        expect(result).to(equal("[\n  \"a\",\n  \"b\"\n]"))
                    }
                }
            }

            describe("toArray") {
                #if canImport(ObjectiveC)
                    context("given array") {
                        it("doesnt modify the value") {
                            let result = generate(
                                "{% for key,value in type.MyClass.variables.2.annotations %}{{ value | toArray }}{% endfor %}"
                            )
                            expect(result).to(equal("[Hello, beautiful, World]"))
                        }
                    }
                #else
                    context("given array") {
                        it("doesnt modify the value") {
                            let result = generate(
                                "{% for key,value in type.MyClass.variables.2.annotations %}{{ value | toArray }}{% endfor %}"
                            )
                            expect(result).to(equal("[\"Hello\", \"beautiful\", \"World\"]"))
                        }
                    }
                #endif

                context("given something") {
                    it("transforms it into array") {
                        let result = generate(
                            "{% for key,value in type.MyClass.variables.3.annotations %}{{ value | toArray }}{% endfor %}"
                        )
                        expect(result).to(equal("[HelloWorld]"))
                    }
                }
            }

            describe("count") {
                context("given array") {
                    it("counts it") {
                        let result = generate("{{ type.MyClass.allVariables | count }}")
                        expect(result).to(equal("4"))
                    }
                }
            }

            describe("isEmpty") {
                context("given empty array") {
                    it("returns true") {
                        let result = generate("{{ type.MyClass.allMethods | isEmpty }}")
                        expect(result).to(equal("true"))
                    }
                }

                context("given non-empty array") {
                    it("returns false") {
                        let result = generate("{{ type.MyClass.allVariables | isEmpty }}")
                        expect(result).to(equal("false"))
                    }
                }
            }

            describe("lines") {
                context("given string with newlines") {
                    it("splits it into lines") {
                        let result = generate(
                            "{% set value %}Hello\nWorld{% endset %}{{ value|lines|join:\",\" }}")
                        let expected = "Hello,World"
                        expect(result).to(equal(expected))
                    }

                    it("splits it into non-empty lines") {
                        let result = generate(
                            "{% set value %}Hello\n\n\nWorld{% endset %}{{ value|lines:true|join:\",\" }}"
                        )
                        let expected = "Hello,World"
                        expect(result).to(equal(expected))
                    }
                }
            }

            describe("grouped") {
                context("given array") {
                    it("groups it") {
                        let result = generate(
                            "{% for group, variables in type.MyClass.variables|grouped:\"typeName.name\" %}{{ group }}: {% for v in variables %}{{ v.name }}{% if not forloop.last %}, {% endif %}{% endfor %}{% if not forloop.last %}, {% endif %}{% endfor %}"
                        )
                        let expected =
                            "MyClass: upperFirstLetter, annotated1, annotated2, myClass: lowerFirstLetter"
                        expect(result).to(equal(expected))
                    }
                }
            }

            describe("collect") {
                context("arrays") {
                    it("collects basic values into array") {
                        let result = generate("""
                        {%- collect collected -%}
                        {% append "Hello" into collected %}
                        {% append "beautiful" into collected %}
                        {% append "World" into collected %}
                        {%- endcollect -%}
                        {{ collected|join:", "}}
                        """)
                        expect(result).to(equal("Hello, beautiful, World"))
                    }
                    
                    it("collects nested values into array") {
                        let result = generate("""
                        {%- collect collected -%}
                        {% for v in type.MyClass.variables %}
                        {% append v.name into collected %}
                        {% endfor %}
                        {%- endcollect -%}
                        {{ collected|join:", " }}
                        """)
                        let expected = "lowerFirstLetter, upperFirstLetter, annotated1, annotated2"
                        expect(result).to(equal(expected))
                        
                    }
                }
                
                context("dictionaries") {
                    it("collects basic values into dictionary") {
                        let result = generate("""
                        {%- collect collected keyed -%}
                        {% append "Hello" into collected keyed "one" %}
                        {% append "beautiful" into collected keyed "two" %}
                        {% append "World" into collected keyed "three" %}
                        {%- endcollect -%}
                        {{ collected.one }}, {{ collected.two }}, {{ collected.three }}
                        """)
                        expect(result).to(equal("Hello, beautiful, World"))
                    }
                    
                    it("collects nested values into dictionary") {
                        let result = generate("""
                        {%- collect collected keyed -%}
                        {% for v in type.MyClass.variables %}
                        {% append v.typeName into collected keyed v.name %}
                        {% endfor %}
                        {%- endcollect -%}
                        {{ collected.lowerFirstLetter }}, {{ collected.upperFirstLetter }}
                        """)
                        let expected = "myClass, MyClass"
                        expect(result).to(equal(expected))
                    }
                    
                    it("collects and does boolean checks in nested dictionaries") {
                        let result = generate("""
                        {%- collect collected keyed -%}
                            {% for v in type.MyClass.variables %}
                            {% if collected.lowerFirstLetter %}{% continue %}{% endif %}
                            {% append v.typeName into collected keyed v.name %}
                            {% endfor %}
                        {%- endcollect -%}
                        {{ collected.lowerFirstLetter }}, {{ collected.upperFirstLetter }}
                        """)
                        let expected = "myClass, "
                        expect(result).to(equal(expected))
                    }
                }
            }

            describe("sorted") {
                #if canImport(ObjectiveC)
                    context("given array") {
                        it("sorts it") {
                            let result = generate(
                                "{% for key,value in type.MyClass.variables.2.annotations %}{{ value | sorted:\"description\" }}{% endfor %}"
                            )
                            expect(result).to(equal("[beautiful, Hello, World]"))
                        }
                    }
                #else
                    context("given array") {
                        it("sorts it") {
                            let result = generate(
                                "{% for key,value in type.MyClass.variables.2.annotations %}{{ value | sorted:\"description\" }}{% endfor %}"
                            )
                            expect(result).to(equal("[\"beautiful\", \"Hello\", \"World\"]"))
                        }
                    }
                #endif
            }

            describe("sortedDescending") {
                context("given array") {
                    #if canImport(ObjectiveC)
                        it("sorts it descending") {
                            let result = generate(
                                "{% for key,value in type.MyClass.variables.2.annotations %}{{ value | sortedDescending:\"description\" }}{% endfor %}"
                            )
                            expect(result).to(equal("[World, Hello, beautiful]"))
                        }
                    #else
                        it("sorts it descending") {
                            let result = generate(
                                "{% for key,value in type.MyClass.variables.2.annotations %}{{ value | sortedDescending:\"description\" }}{% endfor %}"
                            )
                            expect(result).to(equal("[\"World\", \"Hello\", \"beautiful\"]"))
                        }
                    #endif
                }
            }

            describe("reversed") {
                context("given array") {
                    #if canImport(ObjectiveC)
                        it("reverses it") {
                            let result = generate(
                                "{% for key,value in type.MyClass.variables.2.annotations %}{{ value | reversed }}{% endfor %}"
                            )
                            expect(result).to(equal("[World, beautiful, Hello]"))
                        }
                    #else
                        it("reverses it") {
                            let result = generate(
                                "{% for key,value in type.MyClass.variables.2.annotations %}{{ value | reversed }}{% endfor %}"
                            )
                            expect(result).to(equal("[\"World\", \"beautiful\", \"Hello\"]"))
                        }
                    #endif
                }
            }

            context("given string") {
                it("generates upperFirstLetter") {
                    expect(generate("{{\"helloWorld\" | upperFirstLetter }}")).to(
                        equal("HelloWorld"))
                }

                it("generates lowerFirstLetter") {
                    expect(generate("{{\"HelloWorld\" | lowerFirstLetter }}")).to(
                        equal("helloWorld"))
                }

                it("generates uppercase") {
                    expect(generate("{{ \"HelloWorld\" | uppercase }}")).to(equal("HELLOWORLD"))
                }

                it("generates lowercase") {
                    expect(generate("{{ \"HelloWorld\" | lowercase }}")).to(equal("helloworld"))
                }

                it("generates capitalise") {
                    expect(generate("{{ \"helloWorld\" | capitalise }}")).to(equal("Helloworld"))
                }

                it("generates deletingLastComponent") {
                    expect(generate("{{ \"/Path/Class.swift\" | deletingLastComponent }}")).to(
                        equal("/Path"))
                }

                it("checks for string in name") {
                    expect(generate("{{ \"FooBar\" | contains:\"oo\" }}")).to(equal("true"))
                    expect(generate("{{ \"FooBar\" | contains:\"xx\" }}")).to(equal("false"))
                    expect(generate("{{ \"FooBar\" | !contains:\"oo\" }}")).to(equal("false"))
                    expect(generate("{{ \"FooBar\" | !contains:\"xx\" }}")).to(equal("true"))
                }

                it("checks for string in prefix") {
                    expect(generate("{{ \"FooBar\" | hasPrefix:\"Foo\" }}")).to(equal("true"))
                    expect(generate("{{ \"FooBar\" | hasPrefix:\"Bar\" }}")).to(equal("false"))
                    expect(generate("{{ \"FooBar\" | !hasPrefix:\"Foo\" }}")).to(equal("false"))
                    expect(generate("{{ \"FooBar\" | !hasPrefix:\"Bar\" }}")).to(equal("true"))
                }

                it("checks for string in suffix") {
                    expect(generate("{{ \"FooBar\" | hasSuffix:\"Bar\" }}")).to(equal("true"))
                    expect(generate("{{ \"FooBar\" | hasSuffix:\"Foo\" }}")).to(equal("false"))
                    expect(generate("{{ \"FooBar\" | !hasSuffix:\"Bar\" }}")).to(equal("false"))
                    expect(generate("{{ \"FooBar\" | !hasSuffix:\"Foo\" }}")).to(equal("true"))
                }

                it("removes instances of a substring") {
                    expect(
                        generate(
                            "{{\"helloWorld\" | replace:\"he\",\"bo\" | replace:\"llo\",\"la\" }}")
                    ).to(equal("bolaWorld"))
                    expect(generate("{{\"helloWorldhelloWorld\" | replace:\"hello\",\"hola\" }}"))
                        .to(equal("holaWorldholaWorld"))
                    expect(generate("{{\"helloWorld\" | replace:\"hello\",\"\" }}")).to(
                        equal("World"))
                    expect(generate("{{\"helloWorld\" | replace:\"foo\",\"bar\" }}")).to(
                        equal("helloWorld"))
                }
            }

            context("given TypeName") {
                it("generates upperFirstLetter") {
                    expect(generate("{{ type.MyClass.variables.0.typeName }}")).to(equal("myClass"))
                }

                it("generates upperFirstLetter") {
                    expect(generate("{{ type.MyClass.variables.0.typeName | upperFirstLetter }}"))
                        .to(equal("MyClass"))
                }

                it("generates lowerFirstLetter") {
                    expect(generate("{{ type.MyClass.variables.1.typeName | lowerFirstLetter }}"))
                        .to(equal("myClass"))
                }

                it("generates uppercase") {
                    expect(generate("{{ type.MyClass.variables.0.typeName | uppercase }}")).to(
                        equal("MYCLASS"))
                }

                it("generates lowercase") {
                    expect(generate("{{ type.MyClass.variables.1.typeName | lowercase }}")).to(
                        equal("myclass"))
                }

                it("generates capitalise") {
                    expect(generate("{{ type.MyClass.variables.1.typeName | capitalise }}")).to(
                        equal("Myclass"))
                }

                it("checks for string in name") {
                    expect(generate("{{ type.MyClass.variables.0.typeName | contains:\"my\" }}"))
                        .to(equal("true"))
                    expect(generate("{{ type.MyClass.variables.0.typeName | contains:\"xx\" }}"))
                        .to(equal("false"))
                    expect(generate("{{ type.MyClass.variables.0.typeName | !contains:\"my\" }}"))
                        .to(equal("false"))
                    expect(generate("{{ type.MyClass.variables.0.typeName | !contains:\"xx\" }}"))
                        .to(equal("true"))
                }

                it("checks for string in prefix") {
                    expect(generate("{{ type.MyClass.variables.0.typeName | hasPrefix:\"my\" }}"))
                        .to(equal("true"))
                    expect(generate("{{ type.MyClass.variables.0.typeName | hasPrefix:\"My\" }}"))
                        .to(equal("false"))
                    expect(generate("{{ type.MyClass.variables.0.typeName | !hasPrefix:\"my\" }}"))
                        .to(equal("false"))
                    expect(generate("{{ type.MyClass.variables.0.typeName | !hasPrefix:\"My\" }}"))
                        .to(equal("true"))
                }

                it("checks for string in suffix") {
                    expect(
                        generate("{{ type.MyClass.variables.0.typeName | hasSuffix:\"Class\" }}")
                    ).to(equal("true"))
                    expect(
                        generate("{{ type.MyClass.variables.0.typeName | hasSuffix:\"class\" }}")
                    ).to(equal("false"))
                    expect(
                        generate("{{ type.MyClass.variables.0.typeName | !hasSuffix:\"Class\" }}")
                    ).to(equal("false"))
                    expect(
                        generate("{{ type.MyClass.variables.0.typeName | !hasSuffix:\"class\" }}")
                    ).to(equal("true"))
                }

                it("removes instances of a substring") {
                    expect(
                        generate(
                            "{{type.MyClass.variables.0.typeName | replace:\"my\",\"My\" | replace:\"Class\",\"Struct\" }}"
                        )
                    ).to(equal("MyStruct"))
                    expect(generate("{{type.MyClass.variables.0.typeName | replace:\"s\",\"z\" }}"))
                        .to(equal("myClazz"))
                    expect(generate("{{type.MyClass.variables.0.typeName | replace:\"my\",\"\" }}"))
                        .to(equal("Class"))
                    expect(
                        generate("{{type.MyClass.variables.0.typeName | replace:\"foo\",\"bar\" }}")
                    ).to(equal("myClass"))
                }

            }

            it("rethrows template parsing errors") {
                expect {
                    try Generator.generate(
                        nil, types: Types(types: []), functions: [],
                        template: StencilTemplate(templateString: "{% tag %}"))
                }
                .to(
                    throwError(closure: { (error) in
                        expect("\(error)").to(equal(": Unknown template tag 'tag'"))
                    }))
            }

            it("includes partial templates") {
                var outputDir = Path("/tmp")
                outputDir = Stubs.cleanTemporarySourceryDir()

                let templatePath = Stubs.templateDirectory + Path("Include.stencil")
                let expectedResult =
                    "// Generated using Sourcery Major.Minor.Patch — https://github.com/krzysztofzablocki/Sourcery\n"
                    + "// DO NOT EDIT\n" + "partial template content\n"

                expect {
                    try Sourcery(cacheDisabled: true).processFiles(
                        .sources(Paths(include: [Stubs.sourceDirectory])),
                        usingTemplates: Paths(include: [templatePath]), output: Output(outputDir),
                        baseIndentation: 0)
                }.toNot(throwError())

                let result =
                    (try? (outputDir + Sourcery().generatedPath(for: templatePath)).read(.utf8))
                expect(result).to(equal(expectedResult))
            }
        }
    }
}
