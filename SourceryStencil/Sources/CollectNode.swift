import Stencil

final class CollectNode: NodeType {
    var token: Stencil.Token?
    private let into: String
    private let keyed: Bool
    private var nodes: [NodeType]

    init(into: String, keyed: Bool, nodes: [NodeType]) {
        self.into = into
        self.keyed = keyed
        self.nodes = nodes
    }

    class func parse(_ parser: TokenParser, token: Token) throws -> NodeType {
        let components = token.components

        guard components.count >= 2 && components.count <= 3 else {
            throw TemplateSyntaxError(
                "'collect' tag takes a variable name and optionally 'keyed' as arguments"
            )
        }

        let keyed = components.count == 3 && components[2] == "keyed"
        
        // Parse the block content
        let nodes = try parser.parse(until(["endcollect"]))
        guard parser.nextToken() != nil else {
            throw TemplateSyntaxError("`collect` block was not closed with `endcollect`")
        }
        
        return CollectNode(into: components[1], keyed: keyed, nodes: nodes)
    }

    func render(_ context: Context) throws -> String {
        let result: CollectNodeResult = keyed ? CollectNodeDictionaryResult() : CollectNodeArrayResult()
        
        _ = try context.push(dictionary: [into: result]) {
            try renderNodes(nodes, context)
        }
        
        context[into] = result.value
        
        return ""
    }
}

fileprivate protocol CollectNodeResult {
    var value: Any { get }
    func append(value: Any) throws
    func append(value: Any, keyed: String) throws
}

fileprivate class CollectNodeArrayResult : CollectNodeResult {
    var result: [Any] = []
    
    var value: Any { result }
    
    func append(value: Any) throws {
        result.append(value)
    }
    
    func append(value: Any, keyed: String) throws {
        throw TemplateSyntaxError("Cannot append keyed values to unkeyed collect.")
    }
}

fileprivate class CollectNodeDictionaryResult : CollectNodeResult {
    var result: [String: Any] = [:]
    
    var value: Any { result }
    
    func append(value: Any) throws {
        throw TemplateSyntaxError("Cannot append unkeyed values to keyed collect.")
    }
    
    func append(value: Any, keyed: String) throws {
        result[keyed] = value
    }
}

final class AppendNode: NodeType {
    var token: Stencil.Token?
    let value: Resolvable
    let into: String
    let key: Resolvable?

    init(value: Resolvable, into: String, key: Resolvable? = nil) {
        self.value = value
        self.into = into
        self.key = key
    }

    class func parse(_ parser: TokenParser, token: Token) throws -> NodeType {
        let components = token.components
        
        func hasToken(_ token: String, at index: Int) -> Bool {
          components.indices ~= index + 1 && components[index] == token
        }

        func endsOrHasToken(_ token: String, at index: Int) -> Bool {
          components.count == index || hasToken(token, at: index)
        }
        
        guard hasToken("into", at: 2) && endsOrHasToken("keyed", at: 4) else {
            throw TemplateSyntaxError(
                """
                'append' statements should use the following 'append {value} into \
                {collection} [keyed {keyname}]
                """
            )
        }


        let value = try parser.compileResolvable(components[1], containedIn: token)
        let into = components[3]
        let key: Resolvable? = if hasToken("keyed", at: 4) {
            try parser.compileResolvable(components[5], containedIn: token)
        } else {
            nil
        }
        
        return AppendNode(value: value, into: into, key: key)
    }

    func render(_ context: Context) throws -> String {
        guard let result = context[into] as? CollectNodeResult else {
            throw TemplateSyntaxError("'append' into '\(into)' could not be resolved.")
        }
        
        // resolve the value
        guard var resolved = try value.resolve(context) else {
            return ""
        }
        
        // if the string can be bridged to String then force it
        if let string = resolved as? String {
            resolved = string
        }
        
        if let key {
            guard let string = try key.resolve(context) as? String else {
                throw TemplateSyntaxError("'append' tag could not resolve key to a string value.")
            }
            try result.append(value: resolved, keyed: string)
        } else {
            try result.append(value: resolved)
        }
        
        return ""
    }
}
