import Foundation
import Testing

@testable import JSONSchema

// Helper function to compare JSON schemas by their sorted JSON representation
func assertJSONSchemaEquivalent(
    _ schema1: JSONSchema, _ schema2: JSONSchema, fileID: String = #fileID,
    filePath: String = #filePath, line: Int = #line, column: Int = #column
) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted]

    let data1 = try encoder.encode(schema1)
    let data2 = try encoder.encode(schema2)

    let json1 = String(data: data1, encoding: .utf8)!
    let json2 = String(data: data2, encoding: .utf8)!

    #expect(
        json1 == json2,
        sourceLocation: SourceLocation(
            fileID: fileID, filePath: filePath, line: line, column: column))
}

@Suite("JSONSchema Tests")
struct JSONSchemaTests {
    @Test func testObjectSchema() throws {
        let schema: JSONSchema = .object(
            title: "Person",
            description: "A person schema",
            default: ["name": "John Doe"],
            examples: [["name": "Jane Doe", "age": 25]],
            enum: [["name": "Option 1"], ["name": "Option 2"]],
            const: ["type": "constant"],
            properties: [
                "name": .string(),
                "age": .integer(minimum: 0, maximum: 120),
                "address": .object(
                    properties: [
                        "street": .string(),
                        "city": .string(),
                        "zip": .string(pattern: "^[0-9]{5}$"),
                    ]
                ),
            ],
            required: ["name", "age"],
            additionalProperties: .boolean(false)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(schema)

        let decoder = JSONDecoder()
        let decodedSchema = try decoder.decode(JSONSchema.self, from: data)

        // Verify schemas are equivalent using sorted JSON comparison
        try assertJSONSchemaEquivalent(decodedSchema, schema)

        // Verify properties were encoded and decoded correctly
        if case let .object(
            title, description, defaultValue, examples, enumValue, constValue, properties, required,
            additionalProperties) = decodedSchema
        {
            #expect(title == "Person")
            #expect(description == "A person schema")
            #expect(defaultValue?.objectValue?["name"]?.stringValue == "John Doe")
            #expect(examples?.count == 1)
            #expect(enumValue?.count == 2)
            #expect(constValue?.objectValue?["type"]?.stringValue == "constant")
            #expect(properties.count == 3)
            #expect(required.count == 2)
            #expect(required.contains("name"))
            #expect(required.contains("age"))

            if case let .boolean(value) = additionalProperties {
                #expect(value == false)
            } else {
                Issue.record("additionalProperties should be .boolean(false)")
            }
        } else {
            Issue.record("Decoded schema should be an object schema")
        }
    }

    @Test func testObjectSchemaWithLiteral() throws {
        let schema: JSONSchema = [
            "name": .string(),
            "age": .integer(minimum: 0, maximum: 120),
            "address": [
                "street": .string(),
                "city": .string(),
            ],
            "zip": .string(pattern: "^[0-9]{5}$"),
        ]

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(schema)

        let decoder = JSONDecoder()
        let decodedSchema = try decoder.decode(JSONSchema.self, from: data)

        // Verify schemas are equivalent using sorted JSON comparison
        try assertJSONSchemaEquivalent(decodedSchema, schema)

        // Verify properties were encoded and decoded correctly
        if case let .object(
            title, description, defaultValue, examples, enumValue, constValue, properties, required,
            additionalProperties) = decodedSchema
        {
            #expect(title == nil)
            #expect(description == nil)
            #expect(defaultValue == nil)
            #expect(examples == nil)
            #expect(enumValue == nil)
            #expect(constValue == nil)
            #expect(properties.count == 4)
            #expect(required == [])
            #expect(additionalProperties == nil)
        }
    }

    @Test func testArraySchema() throws {
        let schema: JSONSchema = .array(
            title: "Numbers",
            description: "An array of numbers",
            default: [1, 2, 3],
            examples: [[4, 5, 6], [7, 8, 9]],
            enum: [[1, 2], [3, 4]],
            const: [9, 8, 7],
            items: .number(minimum: 0),
            minItems: 1,
            maxItems: 10,
            uniqueItems: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(schema)

        let decoder = JSONDecoder()
        let decodedSchema = try decoder.decode(JSONSchema.self, from: data)

        #expect(decodedSchema == schema)

        if case let .array(
            title, description, defaultValue, examples, enumValue, constValue, items, minItems,
            maxItems, uniqueItems) = decodedSchema
        {
            #expect(title == "Numbers")
            #expect(description == "An array of numbers")
            #expect(defaultValue?.arrayValue?.count == 3)
            #expect(examples?.count == 2)
            #expect(enumValue?.count == 2)
            #expect(constValue?.arrayValue?.count == 3)

            if case let .number(_, _, _, _, _, _, minimum, _, _, _, _) = items {
                #expect(minimum == 0)
            } else {
                Issue.record("items should be a number schema")
            }

            #expect(minItems == 1)
            #expect(maxItems == 10)
            #expect(uniqueItems == true)
        } else {
            Issue.record("Decoded schema should be an array schema")
        }
    }

    @Test func testStringSchema() throws {
        let schema: JSONSchema = .string(
            title: "Email",
            description: "A valid email address",
            default: "john@example.com",
            examples: ["jane@example.com", "support@example.com"],
            enum: ["admin@example.com", "user@example.com"],
            const: "constant@example.com",
            minLength: 5,
            maxLength: 100,
            pattern: "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$",
            format: .email
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(schema)

        let decoder = JSONDecoder()
        let decodedSchema = try decoder.decode(JSONSchema.self, from: data)

        #expect(decodedSchema == schema)

        if case let .string(
            title, description, defaultValue, examples, enumValue, constValue, minLength, maxLength,
            pattern, format) = decodedSchema
        {
            #expect(title == "Email")
            #expect(description == "A valid email address")
            #expect(defaultValue?.stringValue == "john@example.com")
            #expect(examples?.count == 2)
            #expect(enumValue?.count == 2)
            #expect(constValue?.stringValue == "constant@example.com")
            #expect(minLength == 5)
            #expect(maxLength == 100)
            #expect(pattern == "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$")
            #expect(format == .email)
        } else {
            Issue.record("Decoded schema should be a string schema")
        }
    }

    @Test func testNumberSchema() throws {
        let schema: JSONSchema = .number(
            title: "Temperature",
            description: "Temperature in Celsius",
            default: 20.5,
            examples: [18.0, 22.5],
            enum: [0.0, 100.0],
            const: 37.0,
            minimum: -273.15,
            maximum: 1000.0,
            exclusiveMinimum: -273.15,
            exclusiveMaximum: 1000.0,
            multipleOf: 0.5
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(schema)

        let decoder = JSONDecoder()
        let decodedSchema = try decoder.decode(JSONSchema.self, from: data)

        // Verify schemas are equivalent using sorted JSON comparison
        try assertJSONSchemaEquivalent(decodedSchema, schema)

        if case let .number(
            title, description, defaultValue, examples, enumValue, constValue, minimum, maximum,
            exclusiveMinimum, exclusiveMaximum, multipleOf) = decodedSchema
        {
            #expect(title == "Temperature")
            #expect(description == "Temperature in Celsius")
            #expect(defaultValue?.doubleValue == 20.5)
            #expect(examples?.count == 2)
            #expect(enumValue?.count == 2)
            #expect(constValue?.doubleValue == 37.0)
            #expect(minimum == -273.15)
            #expect(maximum == 1000.0)
            #expect(exclusiveMinimum == -273.15)
            #expect(exclusiveMaximum == 1000.0)
            #expect(multipleOf == 0.5)
        } else {
            Issue.record("Decoded schema should be a number schema")
        }
    }

    @Test func testIntegerSchema() throws {
        let schema: JSONSchema = .integer(
            title: "Age",
            description: "Age in years",
            default: 30,
            examples: [25, 40],
            enum: [18, 21, 65],
            const: 42,
            minimum: 0,
            maximum: 120,
            exclusiveMinimum: 0,
            exclusiveMaximum: 120,
            multipleOf: 1
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(schema)

        let decoder = JSONDecoder()
        let decodedSchema = try decoder.decode(JSONSchema.self, from: data)

        #expect(decodedSchema == schema)

        if case let .integer(
            title, description, defaultValue, examples, enumValue, constValue, minimum, maximum,
            exclusiveMinimum, exclusiveMaximum, multipleOf) = decodedSchema
        {
            #expect(title == "Age")
            #expect(description == "Age in years")
            #expect(defaultValue?.intValue == 30)
            #expect(examples?.count == 2)
            #expect(enumValue?.count == 3)
            #expect(constValue?.intValue == 42)
            #expect(minimum == 0)
            #expect(maximum == 120)
            #expect(exclusiveMinimum == 0)
            #expect(exclusiveMaximum == 120)
            #expect(multipleOf == 1)
        } else {
            Issue.record("Decoded schema should be an integer schema")
        }
    }

    @Test func testBooleanSchema() throws {
        let schema: JSONSchema = .boolean(
            title: "Active",
            description: "Whether the user is active",
            default: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(schema)

        let decoder = JSONDecoder()
        let decodedSchema = try decoder.decode(JSONSchema.self, from: data)

        #expect(decodedSchema == schema)

        if case let .boolean(title, description, defaultValue) = decodedSchema {
            #expect(title == "Active")
            #expect(description == "Whether the user is active")
            #expect(defaultValue?.boolValue == true)
        } else {
            Issue.record("Decoded schema should be a boolean schema")
        }
    }

    @Test func testNullSchema() throws {
        let schema: JSONSchema = .null

        let encoder = JSONEncoder()
        let data = try encoder.encode(schema)

        let decoder = JSONDecoder()
        let decodedSchema = try decoder.decode(JSONSchema.self, from: data)

        #expect(decodedSchema == schema)

        if case .null = decodedSchema {
            // This is expected
        } else {
            Issue.record("Decoded schema should be a null schema")
        }
    }

    @Test func testReferenceSchema() throws {
        let schema: JSONSchema = .reference("#/definitions/Person")

        let encoder = JSONEncoder()
        let data = try encoder.encode(schema)

        let decoder = JSONDecoder()
        let decodedSchema = try decoder.decode(JSONSchema.self, from: data)

        #expect(decodedSchema == schema)

        if case let .reference(ref) = decodedSchema {
            #expect(ref == "#/definitions/Person")
        } else {
            Issue.record("Decoded schema should be a reference schema")
        }
    }

    @Test func testAnyOfSchema() throws {
        let schema: JSONSchema = .anyOf([
            .string(),
            .integer(),
            .boolean(),
        ])

        let encoder = JSONEncoder()
        let data = try encoder.encode(schema)

        let decoder = JSONDecoder()
        let decodedSchema = try decoder.decode(JSONSchema.self, from: data)

        #expect(decodedSchema == schema)

        if case let .anyOf(schemas) = decodedSchema {
            #expect(schemas.count == 3)
        } else {
            Issue.record("Decoded schema should be an anyOf schema")
        }
    }

    @Test func testAllOfSchema() throws {
        let schema: JSONSchema = .allOf([
            .object(properties: ["name": .string()]),
            .object(properties: ["age": .integer()]),
        ])

        let encoder = JSONEncoder()
        let data = try encoder.encode(schema)

        let decoder = JSONDecoder()
        let decodedSchema = try decoder.decode(JSONSchema.self, from: data)

        // Verify schemas are equivalent using sorted JSON comparison
        try assertJSONSchemaEquivalent(decodedSchema, schema)

        if case let .allOf(schemas) = decodedSchema {
            #expect(schemas.count == 2)
        } else {
            Issue.record("Decoded schema should be an allOf schema")
        }
    }

    @Test func testOneOfSchema() throws {
        let schema: JSONSchema = .oneOf([
            .object(properties: ["type": .string(const: "dog"), "bark": .boolean()]),
            .object(properties: ["type": .string(const: "cat"), "meow": .boolean()]),
        ])

        let encoder = JSONEncoder()
        let data = try encoder.encode(schema)

        let decoder = JSONDecoder()
        let decodedSchema = try decoder.decode(JSONSchema.self, from: data)

        // Verify schemas are equivalent using sorted JSON comparison
        try assertJSONSchemaEquivalent(decodedSchema, schema)

        if case let .oneOf(schemas) = decodedSchema {
            #expect(schemas.count == 2)
        } else {
            Issue.record("Decoded schema should be a oneOf schema")
        }
    }

    @Test func testNotSchema() throws {
        let schema: JSONSchema = .not(.string())

        let encoder = JSONEncoder()
        let data = try encoder.encode(schema)

        let decoder = JSONDecoder()
        let decodedSchema = try decoder.decode(JSONSchema.self, from: data)

        #expect(decodedSchema == schema)

        if case let .not(notSchema) = decodedSchema {
            if case .string = notSchema {
                // This is expected
            } else {
                Issue.record("Inner schema should be a string schema")
            }
        } else {
            Issue.record("Decoded schema should be a not schema")
        }
    }

    @Test func testEmptySchema() throws {
        let schema: JSONSchema = .empty

        let encoder = JSONEncoder()
        let data = try encoder.encode(schema)

        let decoder = JSONDecoder()
        let decodedSchema = try decoder.decode(JSONSchema.self, from: data)

        #expect(decodedSchema == schema)

        if case .empty = decodedSchema {
            // This is expected
        } else {
            Issue.record("Decoded schema should be an empty schema")
        }
    }

    @Test func testAnySchema() throws {
        let schema: JSONSchema = .any

        let encoder = JSONEncoder()
        let data = try encoder.encode(schema)

        let decoder = JSONDecoder()
        let decodedSchema = try decoder.decode(JSONSchema.self, from: data)

        #expect(decodedSchema == schema)

        if case .any = decodedSchema {
            // This is expected
        } else {
            Issue.record("Decoded schema should be an any schema")
        }
    }

    @Test func testStringFormatEncoding() throws {
        // Test each format
        let formats: [StringFormat] = [
            .dateTime, .date, .time, .duration, .email, .idnEmail,
            .hostname, .idnHostname, .ipv4, .ipv6, .uri, .uriReference,
            .iriReference, .uriTemplate, .jsonPointer, .relativeJsonPointer,
            .regex, .uuid, .custom("custom-format"),
        ]

        for format in formats {
            let schema: JSONSchema = .string(format: format)

            let encoder = JSONEncoder()
            let data = try encoder.encode(schema)

            let decoder = JSONDecoder()
            let decodedSchema = try decoder.decode(JSONSchema.self, from: data)

            if case let .string(_, _, _, _, _, _, _, _, _, decodedFormat) = decodedSchema,
                let decodedFormat = decodedFormat
            {
                #expect(decodedFormat == format)
            } else {
                Issue.record("Format \(format) was not correctly encoded/decoded")
            }
        }
    }

    @Test func testStringFormatRawValue() {
        #expect(StringFormat.dateTime.rawValue == "date-time")
        #expect(StringFormat.date.rawValue == "date")
        #expect(StringFormat.time.rawValue == "time")
        #expect(StringFormat.duration.rawValue == "duration")
        #expect(StringFormat.email.rawValue == "email")
        #expect(StringFormat.idnEmail.rawValue == "idn-email")
        #expect(StringFormat.hostname.rawValue == "hostname")
        #expect(StringFormat.idnHostname.rawValue == "idn-hostname")
        #expect(StringFormat.ipv4.rawValue == "ipv4")
        #expect(StringFormat.ipv6.rawValue == "ipv6")
        #expect(StringFormat.uri.rawValue == "uri")
        #expect(StringFormat.uriReference.rawValue == "uri-reference")
        #expect(StringFormat.iriReference.rawValue == "iri-reference")
        #expect(StringFormat.uriTemplate.rawValue == "uri-template")
        #expect(StringFormat.jsonPointer.rawValue == "json-pointer")
        #expect(StringFormat.relativeJsonPointer.rawValue == "relative-json-pointer")
        #expect(StringFormat.regex.rawValue == "regex")
        #expect(StringFormat.uuid.rawValue == "uuid")
        #expect(StringFormat.custom("custom-format").rawValue == "custom-format")
    }

    @Test func testAdditionalPropertiesEncoding() throws {
        // Test boolean variant
        let schemaWithBooleanAdditionalProps: JSONSchema = .object(
            additionalProperties: .boolean(true)
        )

        let encoder = JSONEncoder()
        var data = try encoder.encode(schemaWithBooleanAdditionalProps)

        let decoder = JSONDecoder()
        var decodedSchema = try decoder.decode(JSONSchema.self, from: data)

        if case let .object(_, _, _, _, _, _, _, _, additionalProperties) = decodedSchema,
            let additionalProperties = additionalProperties
        {
            if case let .boolean(value) = additionalProperties {
                #expect(value == true)
            } else {
                Issue.record("additionalProperties should be .boolean(true)")
            }
        } else {
            Issue.record("Decoded schema should be an object with additionalProperties")
        }

        // Test schema variant
        let schemaWithSchemaAdditionalProps: JSONSchema = .object(
            additionalProperties: .schema(.string(minLength: 1))
        )

        data = try encoder.encode(schemaWithSchemaAdditionalProps)
        decodedSchema = try decoder.decode(JSONSchema.self, from: data)

        if case let .object(_, _, _, _, _, _, _, _, additionalProperties) = decodedSchema,
            let additionalProperties = additionalProperties
        {
            if case let .schema(additionalPropsSchema) = additionalProperties {
                if case let .string(_, _, _, _, _, _, minLength, _, _, _) = additionalPropsSchema {
                    #expect(minLength == 1)
                } else {
                    Issue.record("Expected string schema")
                }
            } else {
                Issue.record("Expected schema variant")
            }
        } else {
            Issue.record("Decoded schema should be an object with additionalProperties")
        }
    }

    @Test func testAdditionalPropertiesBooleanVariant() throws {
        let trueVariant: AdditionalProperties = .boolean(true)
        let falseVariant: AdditionalProperties = .boolean(false)

        // Test equality
        #expect(trueVariant == trueVariant)
        #expect(falseVariant == falseVariant)
        #expect(trueVariant != falseVariant)

        // Test encoding and decoding
        let encoder = JSONEncoder()

        let trueData = try encoder.encode(trueVariant)
        let falseData = try encoder.encode(falseVariant)

        let decoder = JSONDecoder()
        let decodedTrueVariant = try decoder.decode(AdditionalProperties.self, from: trueData)
        let decodedFalseVariant = try decoder.decode(AdditionalProperties.self, from: falseData)

        #expect(decodedTrueVariant == trueVariant)
        #expect(decodedFalseVariant == falseVariant)

        if case let .boolean(value) = decodedTrueVariant {
            #expect(value == true)
        } else {
            Issue.record("Expected boolean variant with true value")
        }

        if case let .boolean(value) = decodedFalseVariant {
            #expect(value == false)
        } else {
            Issue.record("Expected boolean variant with false value")
        }

        // Verify the encoded JSON
        let trueJson = String(data: trueData, encoding: .utf8)
        let falseJson = String(data: falseData, encoding: .utf8)

        #expect(trueJson == "true")
        #expect(falseJson == "false")
    }

    @Test func testAdditionalPropertiesSchemaVariant() throws {
        let stringSchema: JSONSchema = .string(minLength: 1, maxLength: 100)
        let schemaVariant: AdditionalProperties = .schema(stringSchema)

        // Test equality
        #expect(schemaVariant == schemaVariant)
        #expect(schemaVariant != .boolean(true))
        #expect(schemaVariant != .schema(.integer()))

        // Test encoding and decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(schemaVariant)

        let decoder = JSONDecoder()
        let decodedVariant = try decoder.decode(AdditionalProperties.self, from: data)

        #expect(decodedVariant == schemaVariant)

        if case let .schema(decodedSchema) = decodedVariant {
            if case let .string(_, _, _, _, _, _, minLength, _, _, _) = decodedSchema {
                #expect(minLength == 1)
            } else {
                Issue.record("Expected string schema")
            }
        } else {
            Issue.record("Expected schema variant")
        }
    }

    @Test func testExpressibleByLiteralProtocols() {
        // Dictionary literal for object schema
        let objectSchema: JSONSchema = [
            "name": .string(),
            "age": .integer(),
        ]

        if case let .object(_, _, _, _, _, _, properties, _, _) = objectSchema {
            #expect(properties.count == 2)
            #expect(properties["name"] != nil)
            #expect(properties["age"] != nil)
        } else {
            Issue.record("Schema should be an object schema")
        }

        // Boolean literal
        let trueSchema: JSONSchema = true
        let falseSchema: JSONSchema = false

        if case .any = trueSchema {
            // This is expected
        } else {
            Issue.record("trueSchema should be .any")
        }

        if case .not(let schema) = falseSchema, case .any = schema {
            // This is expected
        } else {
            Issue.record("falseSchema should be .not(.any)")
        }

        // Nil literal
        let nilSchema: JSONSchema = nil

        if case .empty = nilSchema {
            // This is expected
        } else {
            Issue.record("nilSchema should be .empty")
        }
    }

    @Test func testComplexSchema() throws {
        // Create a complex schema with nested objects, arrays, and constraints
        let schema: JSONSchema = .object(
            title: "Person",
            description: "A person schema with various fields",
            properties: [
                "name": .string(minLength: 2, maxLength: 100),
                "age": .integer(minimum: 0, maximum: 120),
                "email": .string(format: .email),
                "address": .object(
                    properties: [
                        "street": .string(),
                        "city": .string(),
                        "state": .string(minLength: 2, maxLength: 2),
                        "zip": .string(pattern: "^[0-9]{5}$"),
                        "country": .string(),
                    ],
                    required: ["street", "city", "country"]
                ),
                "phoneNumbers": .array(
                    items: .object(
                        properties: [
                            "type": .string(enum: ["home", "work", "mobile"]),
                            "number": .string(pattern: "^[0-9-+()\\s]+$"),
                        ],
                        required: ["type", "number"]
                    ),
                    minItems: 1
                ),
                "status": .oneOf([
                    .string(enum: ["active", "inactive", "pending"]),
                    .object(
                        properties: [
                            "code": .integer(),
                            "message": .string(),
                        ],
                        required: ["code", "message"]
                    ),
                ]),
                "metadata": .object(additionalProperties: .boolean(true)),
            ],
            required: ["name", "email"]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(schema)

        let decoder = JSONDecoder()
        let decodedSchema = try decoder.decode(JSONSchema.self, from: data)

        // Verify schemas are equivalent using sorted JSON comparison
        try assertJSONSchemaEquivalent(decodedSchema, schema)

        // Perform more detailed checks on the complex structure
        if case let .object(_, _, _, _, _, _, properties, required, _) = decodedSchema {
            #expect(properties.count == 7)
            #expect(required.contains("name"))
            #expect(required.contains("email"))

            // Check nested address object
            if case let .object(_, _, _, _, _, _, addressProperties, addressRequired, _) =
                properties[
                    "address"]
            {
                #expect(addressProperties.count == 5)
                #expect(addressRequired.contains("street"))
                #expect(addressRequired.contains("city"))
                #expect(addressRequired.contains("country"))
            } else {
                Issue.record("address should be an object schema")
            }

            // Check phoneNumbers array
            if case let .array(_, _, _, _, _, _, phoneItemsSchema, minItems, _, _) = properties[
                "phoneNumbers"]
            {
                #expect(minItems == 1)

                if case let .object(_, _, _, _, _, _, phoneProperties, phoneRequired, _) =
                    phoneItemsSchema
                {
                    #expect(phoneProperties.count == 2)
                    #expect(phoneRequired.contains("type"))
                    #expect(phoneRequired.contains("number"))

                    if case let .string(_, _, _, _, enumValues, _, _, _, _, _) = phoneProperties[
                        "type"]
                    {
                        #expect(enumValues?.count == 3)
                        if let enumValues = enumValues {
                            #expect(enumValues.contains("home"))
                            #expect(enumValues.contains("work"))
                            #expect(enumValues.contains("mobile"))
                        }
                    } else {
                        Issue.record("type should be a string schema with enum values")
                    }
                } else {
                    Issue.record("phoneNumbers items should be an object schema")
                }
            } else {
                Issue.record("phoneNumbers should be an array schema")
            }

            // Check oneOf in status
            if case let .oneOf(statusSchemas) = properties["status"] {
                #expect(statusSchemas.count == 2)

                if case let .string(_, _, _, _, enumValues, _, _, _, _, _) = statusSchemas[0] {
                    #expect(enumValues?.count == 3)
                    if let enumValues = enumValues {
                        #expect(enumValues.contains("active"))
                        #expect(enumValues.contains("inactive"))
                        #expect(enumValues.contains("pending"))
                    }
                } else {
                    Issue.record("First status schema should be a string schema with enum values")
                }

                if case let .object(_, _, _, _, _, _, statusObjProperties, statusObjRequired, _) =
                    statusSchemas[1]
                {
                    #expect(statusObjProperties.count == 2)
                    #expect(statusObjRequired.contains("code"))
                    #expect(statusObjRequired.contains("message"))
                } else {
                    Issue.record("Second status schema should be an object schema")
                }
            } else {
                Issue.record("status should be a oneOf schema")
            }
        } else {
            Issue.record("Decoded schema should be an object schema")
        }
    }

    @Test func testJSONValueConversions() throws {
        // Test creating JSONValues and converting between types

        // Test null
        let nullValue: JSONValue = .null
        #expect(nullValue.isNull)

        // Test boolean
        let boolValue: JSONValue = true
        #expect(boolValue.boolValue == true)

        // Test integer
        let intValue: JSONValue = 42
        #expect(intValue.intValue == 42)

        // Test double
        let doubleValue: JSONValue = 3.14
        #expect(doubleValue.doubleValue == 3.14)

        // Test string
        let stringValue: JSONValue = "hello"
        #expect(stringValue.stringValue == "hello")

        // Test array
        let arrayValue: JSONValue = [1, "string", true]
        #expect(arrayValue.arrayValue?.count == 3)

        // Test object
        let objectValue: JSONValue = ["key1": "value1", "key2": 42]
        #expect(objectValue.objectValue?.count == 2)
        #expect(objectValue.objectValue?["key1"]?.stringValue == "value1")
        #expect(objectValue.objectValue?["key2"]?.intValue == 42)

        // Test encoding and decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(objectValue)

        let decoder = JSONDecoder()
        let decodedValue = try decoder.decode(JSONValue.self, from: data)

        #expect(decodedValue == objectValue)
    }

    @Test func testConvenienceProperties() {
        // Test object schema
        let objectSchema: JSONSchema = .object(
            title: "Person",
            description: "A person object",
            default: ["name": "John"],
            examples: [["name": "Jane"]],
            enum: [["name": "Option 1"]],
            const: ["name": "Constant"]
        )

        #expect(objectSchema.title == "Person")
        #expect(objectSchema.description == "A person object")
        #expect(objectSchema.default?.objectValue?["name"]?.stringValue == "John")
        #expect(objectSchema.examples?.count == 1)
        #expect(objectSchema.examples?.first?.objectValue?["name"]?.stringValue == "Jane")
        #expect(objectSchema.enum?.count == 1)
        #expect(objectSchema.enum?.first?.objectValue?["name"]?.stringValue == "Option 1")
        #expect(objectSchema.const?.objectValue?["name"]?.stringValue == "Constant")

        // Test array schema
        let arraySchema: JSONSchema = .array(
            title: "Numbers",
            description: "An array of numbers",
            default: [1, 2, 3],
            examples: [[4, 5, 6]],
            enum: [[7, 8, 9]],
            const: [10, 11, 12]
        )

        #expect(arraySchema.title == "Numbers")
        #expect(arraySchema.description == "An array of numbers")
        #expect(arraySchema.default?.arrayValue?.count == 3)
        #expect(arraySchema.examples?.count == 1)
        #expect(arraySchema.examples?.first?.arrayValue?.count == 3)
        #expect(arraySchema.enum?.count == 1)
        #expect(arraySchema.enum?.first?.arrayValue?.count == 3)
        #expect(arraySchema.const?.arrayValue?.count == 3)

        // Test string schema
        let stringSchema: JSONSchema = .string(
            title: "Email",
            description: "An email address",
            default: "john@example.com",
            examples: ["jane@example.com"],
            enum: ["admin@example.com"],
            const: "constant@example.com"
        )

        #expect(stringSchema.title == "Email")
        #expect(stringSchema.description == "An email address")
        #expect(stringSchema.default?.stringValue == "john@example.com")
        #expect(stringSchema.examples?.count == 1)
        #expect(stringSchema.examples?.first?.stringValue == "jane@example.com")
        #expect(stringSchema.enum?.count == 1)
        #expect(stringSchema.enum?.first?.stringValue == "admin@example.com")
        #expect(stringSchema.const?.stringValue == "constant@example.com")

        // Test number schema
        let numberSchema: JSONSchema = .number(
            title: "Temperature",
            description: "Temperature in Celsius",
            default: 20.5,
            examples: [18.0],
            enum: [0.0],
            const: 37.0
        )

        #expect(numberSchema.title == "Temperature")
        #expect(numberSchema.description == "Temperature in Celsius")
        #expect(numberSchema.default?.doubleValue == 20.5)
        #expect(numberSchema.examples?.count == 1)
        #expect(numberSchema.examples?.first?.doubleValue == 18.0)
        #expect(numberSchema.enum?.count == 1)
        #expect(numberSchema.enum?.first?.doubleValue == 0.0)
        #expect(numberSchema.const?.doubleValue == 37.0)

        // Test integer schema
        let integerSchema: JSONSchema = .integer(
            title: "Age",
            description: "Age in years",
            default: 30,
            examples: [25],
            enum: [18],
            const: 42
        )

        #expect(integerSchema.title == "Age")
        #expect(integerSchema.description == "Age in years")
        #expect(integerSchema.default?.intValue == 30)
        #expect(integerSchema.examples?.count == 1)
        #expect(integerSchema.examples?.first?.intValue == 25)
        #expect(integerSchema.enum?.count == 1)
        #expect(integerSchema.enum?.first?.intValue == 18)
        #expect(integerSchema.const?.intValue == 42)

        // Test boolean schema
        let booleanSchema: JSONSchema = .boolean(
            title: "Active",
            description: "Whether the user is active",
            default: true
        )

        #expect(booleanSchema.title == "Active")
        #expect(booleanSchema.description == "Whether the user is active")
        #expect(booleanSchema.default?.boolValue == true)

        // Test schemas without metadata
        let emptyObjectSchema: JSONSchema = .object()
        #expect(emptyObjectSchema.title == nil)
        #expect(emptyObjectSchema.description == nil)
        #expect(emptyObjectSchema.default == nil)
        #expect(emptyObjectSchema.examples == nil)
        #expect(emptyObjectSchema.enum == nil)
        #expect(emptyObjectSchema.const == nil)

        // Test special schemas
        let nullSchema: JSONSchema = .null
        #expect(nullSchema.title == nil)
        #expect(nullSchema.description == nil)
        #expect(nullSchema.default == nil)
        #expect(nullSchema.examples == nil)
        #expect(nullSchema.enum == nil)
        #expect(nullSchema.const == nil)

        let anySchema: JSONSchema = .any
        #expect(anySchema.title == nil)
        #expect(anySchema.description == nil)
        #expect(anySchema.default == nil)
        #expect(anySchema.examples == nil)
        #expect(anySchema.enum == nil)
        #expect(anySchema.const == nil)

        let emptySchema: JSONSchema = .empty
        #expect(emptySchema.title == nil)
        #expect(emptySchema.description == nil)
        #expect(emptySchema.default == nil)
        #expect(emptySchema.examples == nil)
        #expect(emptySchema.enum == nil)
        #expect(emptySchema.const == nil)

        let referenceSchema: JSONSchema = .reference("#/definitions/Person")
        #expect(referenceSchema.title == nil)
        #expect(referenceSchema.description == nil)
        #expect(referenceSchema.default == nil)
        #expect(referenceSchema.examples == nil)
        #expect(referenceSchema.enum == nil)
        #expect(referenceSchema.const == nil)

        let anyOfSchema: JSONSchema = .anyOf([.string(), .integer()])
        #expect(anyOfSchema.title == nil)
        #expect(anyOfSchema.description == nil)
        #expect(anyOfSchema.default == nil)
        #expect(anyOfSchema.examples == nil)
        #expect(anyOfSchema.enum == nil)
        #expect(anyOfSchema.const == nil)

        let allOfSchema: JSONSchema = .allOf([.string(), .integer()])
        #expect(allOfSchema.title == nil)
        #expect(allOfSchema.description == nil)
        #expect(allOfSchema.default == nil)
        #expect(allOfSchema.examples == nil)
        #expect(allOfSchema.enum == nil)
        #expect(allOfSchema.const == nil)

        let oneOfSchema: JSONSchema = .oneOf([.string(), .integer()])
        #expect(oneOfSchema.title == nil)
        #expect(oneOfSchema.description == nil)
        #expect(oneOfSchema.default == nil)
        #expect(oneOfSchema.examples == nil)
        #expect(oneOfSchema.enum == nil)
        #expect(oneOfSchema.const == nil)

        let notSchema: JSONSchema = .not(.string())
        #expect(notSchema.title == nil)
        #expect(notSchema.description == nil)
        #expect(notSchema.default == nil)
        #expect(notSchema.examples == nil)
        #expect(notSchema.enum == nil)
        #expect(notSchema.const == nil)
    }

    @Test func testTypeName() {
        // Test object schema
        let objectSchema: JSONSchema = .object()
        #expect(objectSchema.typeName == "object")

        // Test array schema
        let arraySchema: JSONSchema = .array()
        #expect(arraySchema.typeName == "array")

        // Test string schema
        let stringSchema: JSONSchema = .string()
        #expect(stringSchema.typeName == "string")

        // Test number schema
        let numberSchema: JSONSchema = .number()
        #expect(numberSchema.typeName == "number")

        // Test integer schema
        let integerSchema: JSONSchema = .integer()
        #expect(integerSchema.typeName == "integer")

        // Test boolean schema
        let booleanSchema: JSONSchema = .boolean()
        #expect(booleanSchema.typeName == "boolean")

        // Test null schema
        let nullSchema: JSONSchema = .null
        #expect(nullSchema.typeName == "null")

        // Test reference schema
        let referenceSchema: JSONSchema = .reference("#/definitions/Person")
        #expect(referenceSchema.typeName == "reference")

        // Test anyOf schema
        let anyOfSchema: JSONSchema = .anyOf([.string(), .integer()])
        #expect(anyOfSchema.typeName == "anyOf")

        // Test allOf schema
        let allOfSchema: JSONSchema = .allOf([.string(), .integer()])
        #expect(allOfSchema.typeName == "allOf")

        // Test oneOf schema
        let oneOfSchema: JSONSchema = .oneOf([.string(), .integer()])
        #expect(oneOfSchema.typeName == "oneOf")

        // Test not schema
        let notSchema: JSONSchema = .not(.string())
        #expect(notSchema.typeName == "not")

        // Test empty schema
        let emptySchema: JSONSchema = .empty
        #expect(emptySchema.typeName == "empty")

        // Test any schema
        let anySchema: JSONSchema = .any
        #expect(anySchema.typeName == "any")
    }

    @Test func testTypeDefault() {
        // Test object schema
        let objectSchema: JSONSchema = .object()
        #expect(objectSchema.typeDefault?.objectValue?.isEmpty == true)

        // Test array schema
        let arraySchema: JSONSchema = .array()
        #expect(arraySchema.typeDefault?.arrayValue?.isEmpty == true)

        // Test string schema
        let stringSchema: JSONSchema = .string()
        #expect(stringSchema.typeDefault?.stringValue == "")

        // Test number schema
        let numberSchema: JSONSchema = .number()
        #expect(numberSchema.typeDefault?.doubleValue == 0.0)

        // Test integer schema
        let integerSchema: JSONSchema = .integer()
        #expect(integerSchema.typeDefault?.intValue == 0)

        // Test boolean schema
        let booleanSchema: JSONSchema = .boolean()
        #expect(booleanSchema.typeDefault?.boolValue == false)

        // Test null schema
        let nullSchema: JSONSchema = .null
        #expect(nullSchema.typeDefault?.isNull == true)

        // Test reference schema
        let referenceSchema: JSONSchema = .reference("#/definitions/Person")
        #expect(referenceSchema.typeDefault == nil)

        // Test anyOf schema
        let anyOfSchema: JSONSchema = .anyOf([.string(), .integer()])
        #expect(anyOfSchema.typeDefault == nil)

        // Test allOf schema
        let allOfSchema: JSONSchema = .allOf([.string(), .integer()])
        #expect(allOfSchema.typeDefault == nil)

        // Test oneOf schema
        let oneOfSchema: JSONSchema = .oneOf([.string(), .integer()])
        #expect(oneOfSchema.typeDefault == nil)

        // Test not schema
        let notSchema: JSONSchema = .not(.string())
        #expect(notSchema.typeDefault == nil)

        // Test empty schema
        let emptySchema: JSONSchema = .empty
        #expect(emptySchema.typeDefault == nil)

        // Test any schema
        let anySchema: JSONSchema = .any
        #expect(anySchema.typeDefault == nil)
    }

    @Test func testPropertiesPreservation() throws {
        // Create a schema with properties that don't follow lexicographic ordering
        let schema: JSONSchema = .object(
            title: "Test Object",
            description: "Object with non-lexicographic property names",
            properties: [
                "one": .string(minLength: 1),
                "two": .integer(minimum: 2),
                "three": .boolean(),
                "four": .array(items: .number()),
                "alpha": .string(),
                "zero": .null,
                "beta": .object(properties: ["nested": .string()]),
            ],
            required: ["one", "three"]
        )

        if case let .object(_, _, _, _, _, _, properties, _, _) = schema {
            // Check that keys are in the order we inserted them
            let orderedKeys = Array(properties.keys)
            #expect(orderedKeys == ["one", "two", "three", "four", "alpha", "zero", "beta"])
        } else {
            Issue.record("Schema should be an object schema")
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(schema)

        let decoder = JSONDecoder()
        let decodedSchema = try decoder.decode(JSONSchema.self, from: data)

        // Verify schemas are equivalent using sorted JSON comparison
        try assertJSONSchemaEquivalent(decodedSchema, schema)

        // Verify properties are preserved
        if case let .object(title, description, _, _, _, _, properties, _, _) = decodedSchema {
            #expect(title == "Test Object")
            #expect(description == "Object with non-lexicographic property names")

            // Verify all properties are present
            #expect(properties.count == 7)
            #expect(
                Array(properties.keys) == ["one", "two", "three", "four", "alpha", "zero", "beta"])
        } else {
            Issue.record("Decoded schema should be an object schema")
        }

        // Also test with dictionary literal syntax
        let literalSchema: JSONSchema = [
            "one": .string(),
            "two": .integer(),
            "three": .boolean(),
            "four": .array(),
        ]

        let literalData = try encoder.encode(literalSchema)
        let decodedLiteralSchema = try decoder.decode(JSONSchema.self, from: literalData)

        if case let .object(_, _, _, _, _, _, properties, _, _) = decodedLiteralSchema {
            #expect(properties.count == 4)
            #expect(Array(properties.keys) == ["one", "two", "three", "four"])
        } else {
            Issue.record("Decoded literal schema should be an object schema")
        }
    }

    @Test func testJSONSchemaRoundTrip() throws {
        // Array of test schemas covering all types and features
        let testSchemas: [JSONSchema] = [
            // Basic types
            .null,
            .any,
            .empty,
            .boolean(),
            .boolean(title: "Is Active", description: "User active status", default: true),

            // String schemas with various properties
            .string(),
            .string(
                title: "Username",
                description: "User's username",
                default: "guest",
                examples: ["alice", "bob", "charlie"],
                enum: ["admin", "user", "guest"],
                const: "fixed_value",
                minLength: 3,
                maxLength: 50,
                pattern: "^[a-zA-Z0-9_]+$",
                format: .email
            ),

            // Number schemas
            .number(),
            .number(
                title: "Temperature",
                description: "Temperature reading",
                default: 20.5,
                examples: [15, 25, 30],
                enum: [0, 50, 100],
                const: 37.5,
                minimum: -273.15,
                maximum: 1000,
                exclusiveMinimum: -273.15,
                exclusiveMaximum: 1000,
                multipleOf: 0.5
            ),

            // Integer schemas
            .integer(),
            .integer(
                title: "Age",
                description: "Person's age",
                default: 30,
                examples: [18, 25, 65],
                enum: [18, 21, 65],
                const: 42,
                minimum: 0,
                maximum: 150,
                exclusiveMinimum: 0,
                exclusiveMaximum: 150,
                multipleOf: 1
            ),

            // Array schemas
            .array(),
            .array(
                title: "Tags",
                description: "List of tags",
                default: ["default", "tag"],
                examples: [["tag1", "tag2"], ["tagA", "tagB"]],
                enum: [["option1"], ["option2", "option3"]],
                const: ["const1", "const2"],
                items: .string(minLength: 1),
                minItems: 0,
                maxItems: 10,
                uniqueItems: true
            ),

            // Object schemas
            .object(),
            .object(
                title: "User",
                description: "User object",
                default: ["id": 1, "name": "Default User"],
                examples: [["id": 2, "name": "Example User"]],
                enum: [["type": "standard"], ["type": "premium"]],
                const: ["type": "fixed"],
                properties: [
                    "id": .integer(minimum: 1),
                    "name": .string(minLength: 1),
                    "email": .string(format: .email),
                    "tags": .array(items: .string()),
                ],
                required: ["id", "name"],
                additionalProperties: .boolean(false)
            ),

            // Object with schema additional properties
            .object(
                properties: ["known": .string()],
                additionalProperties: .schema(.number(minimum: 0))
            ),

            // Reference schema
            .reference("#/definitions/User"),
            .reference("#/components/schemas/Address"),

            // Composite schemas
            .anyOf([.string(), .number(), .boolean()]),
            .allOf([
                .object(properties: ["name": .string()]),
                .object(properties: ["age": .integer()]),
            ]),
            .oneOf([
                .object(properties: ["type": .string(const: "cat"), "meow": .boolean()]),
                .object(properties: ["type": .string(const: "dog"), "bark": .boolean()]),
            ]),
            .not(.string(pattern: "^[0-9]+$")),

            // Nested complex schema
            .object(
                title: "Company",
                description: "Company with employees",
                properties: [
                    "name": .string(minLength: 1),
                    "founded": .integer(minimum: 1800, maximum: 2100),
                    "employees": .array(
                        items: .object(
                            properties: [
                                "id": .integer(),
                                "name": .string(),
                                "role": .string(enum: ["developer", "manager", "designer"]),
                                "skills": .array(items: .string(), minItems: 1),
                                "contact": .oneOf([
                                    .object(properties: [
                                        "type": .string(const: "email"),
                                        "value": .string(format: .email),
                                    ]),
                                    .object(properties: [
                                        "type": .string(const: "phone"),
                                        "value": .string(pattern: "^\\+?[0-9-]+$"),
                                    ]),
                                ]),
                            ],
                            required: ["id", "name", "role"]
                        ),
                        minItems: 1
                    ),
                    "address": .object(
                        properties: [
                            "street": .string(),
                            "city": .string(),
                            "country": .string(),
                            "coordinates": .object(
                                properties: [
                                    "lat": .number(minimum: -90, maximum: 90),
                                    "lng": .number(minimum: -180, maximum: 180),
                                ],
                                required: ["lat", "lng"]
                            ),
                        ],
                        required: ["city", "country"]
                    ),
                ],
                required: ["name", "founded", "employees"]
            ),

            // String with all formats
            .string(format: .dateTime),
            .string(format: .date),
            .string(format: .time),
            .string(format: .duration),
            .string(format: .email),
            .string(format: .idnEmail),
            .string(format: .hostname),
            .string(format: .idnHostname),
            .string(format: .ipv4),
            .string(format: .ipv6),
            .string(format: .uri),
            .string(format: .uriReference),
            .string(format: .iriReference),
            .string(format: .uriTemplate),
            .string(format: .jsonPointer),
            .string(format: .relativeJsonPointer),
            .string(format: .regex),
            .string(format: .uuid),
            .string(format: .custom("custom-format")),

            // Edge cases
            .object(properties: [:]),  // Empty properties
            .array(items: .array(items: .array(items: .string()))),  // Triple nested arrays
            .anyOf([]),  // Empty anyOf (though this might be invalid in real use)
            .allOf([.any]),  // Single item allOf
            .oneOf([.empty]),  // Single item oneOf
        ]

        // Test each schema
        for (index, originalSchema) in testSchemas.enumerated() {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .prettyPrinted]

            // Encode to JSON
            let encodedData = try encoder.encode(originalSchema)

            // Decode back
            let decoder = JSONDecoder()
            let decodedSchema = try decoder.decode(JSONSchema.self, from: encodedData)

            // Compare using our helper function
            try assertJSONSchemaEquivalent(
                decodedSchema,
                originalSchema,
                fileID: #fileID,
                filePath: #filePath,
                line: #line,
                column: #column
            )

            // Also verify direct equality where applicable
            #expect(
                decodedSchema == originalSchema,
                "Schema at index \(index) failed round-trip equality test"
            )

            // Double round-trip to ensure stability
            let reEncodedData = try encoder.encode(decodedSchema)
            let reDecodedSchema = try decoder.decode(JSONSchema.self, from: reEncodedData)

            try assertJSONSchemaEquivalent(
                reDecodedSchema,
                decodedSchema,
                fileID: #fileID,
                filePath: #filePath,
                line: #line,
                column: #column
            )

            #expect(
                reDecodedSchema == decodedSchema,
                "Schema at index \(index) failed double round-trip equality test"
            )

            // Verify JSON strings are identical after sorting
            let json1 = String(data: encodedData, encoding: .utf8)!
            let json2 = String(data: reEncodedData, encoding: .utf8)!
            #expect(
                json1 == json2,
                "Schema at index \(index) produced different JSON on re-encoding"
            )
        }
    }
}
