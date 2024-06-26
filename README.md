# JsonModel

JsonModel is a set of utilities built on top of the Swift Codable protocol to allow 
for polymorphic serialization and documentation using a subset of 
[JSON Schema draft 7](https://json-schema.org/understanding-json-schema/index.html).

See the unit tests and the `ResultModel` target for examples for how to use this 
library to support polymorphic serialization.

### Version 1.1

Moved definitions for the `ResultData` protocol used by Sage Bionetworks
into this library to simplify the dependency chain for the libraries and 
frameworks used by our organization.

### Version 1.6

Added ResultModel library with a placeholder file so that libraries that depend
on the `ResultData` protocol can support both a version of the library where the 
actual model is defined using `import JsonModel` and version
2 where the model for results is defined using `import ResultModel`.

```
    .package(name: "JsonModel",
             url: "https://github.com/Sage-Bionetworks/JsonModel-Swift.git",
             "1.6.0"..<"3.0.0"),
```

### Version 2

Moved the results protocols and objects into a separate target within the JsonModel
library. To migrate to this version, you will need to `import ResultModel` anywhere
that you reference `ResultData` model objects.

### Version 2.1

- Added property wrappers that can be used in polymorphic serialization.
- Deprecated `PolymorphicSerializer` and replaced with `GenericPolymorphicSerializer`

Note: Polymorphic encoding using the static `typeName` defined by the `PolymorphicStaticTyped`
protocol is not currently supported for encoding root objects, and is therefore *not* 
used by any of the `SerializableResultData` model objects defined within this library.

A root object can be encoded and decoded using the `PolymorphicValue` as a wrapper or 
by defining the `typeName` as a read/write instance property.

For example,

```
public protocol GooProtocol {
    var value: Int { get }
}

public struct FooObject : Codable, PolymorphicStaticTyped, GooProtocol {
    public static var typeName: String { "foo" }

    public let value: Int

    public init(value: Int = 0) {
        self.value = value
    }
}

public struct MooObject : Codable, PolymorphicTyped, GooProtocol {
    private enum CodingKeys : String, CodingKey {
        case typeName = "type", goos
    }
    public private(set) var typeName: String = "moo"
    
    public var value: Int {
        goos.count
    }

    @PolymorphicArray public var goos: [GooProtocol]

    public init(goos: [GooProtocol] = []) {
        self.goos = goos
    }
}

public struct RaguObject : Codable, PolymorphicStaticTyped, GooProtocol {
    public static let typeName: String = "ragu"

    public let value: Int
    @PolymorphicValue public private(set) var goo: GooProtocol

    public init(value: Int, goo: GooProtocol) {
        self.value = value
        self.goo = goo
    }
}

open class GooFactory : SerializationFactory {
    
    public let gooSerializer = GenericPolymorphicSerializer<GooProtocol>([
        MooObject(),
        FooObject(),
    ])
    
    public required init() {
        super.init()
        self.registerSerializer(gooSerializer)
        gooSerializer.add(typeOf: RaguObject.self)
    }
}

```

In this example, `MooObject` can be directly serialized because the `typeName` is a read/write
instance property. Decoding can be handled like this:

```
    let factory = GooFactory()
    let decoder = factory.createJSONDecoder()
    
    let json = """
    {
        "type" : "moo",
        "goos" : [
            { "type" : "foo", "value" : 2 },
            { "type" : "moo", "goos" : [{ "type" : "foo", "value" : 5 }] }
        ]
    }
    """.data(using: .utf8)!
    
    let decodedObject = try decoder.decode(MooObject.self, from: json)

```

And because the root object does *not* use a static `typeName`, can be encoded as follows:

```
    let encoder = JSONEncoder()
    let encodedData = try encoder.encode(decodedObject)
```

Whereas `RaguObject` must be wrapped:

```
    let factory = GooFactory()
    let decoder = factory.createJSONDecoder()
    let encoder = factory.createJSONEncoder()
    
    let json = """
    {
        "type" : "ragu",
        "value" : 7,
        "goo" : { "type" : "foo", "value" : 2 }
    }
    """.data(using: .utf8)!
    
    let decodedObject = try decoder.decode(PolymorphicValue<GooProtocol>.self, from: json)
    let encodedData = try encoder.encode(decodedObject)

```
