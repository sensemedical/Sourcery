import Stencil

final class CollectNode: NodeType {
    var token: Stencil.Token?
    private let targetName: String
    private let keyed: Bool
    private var nodes: [NodeType]

    init(targetName: String, keyed: Bool, nodes: [NodeType]) {
        self.targetName = targetName
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
        
        return CollectNode(targetName: components[1], keyed: keyed, nodes: nodes)
    }

    func render(_ context: Context) throws -> String {
        let result: CollectNodeResult = keyed ? CollectNodeDictionaryResult() : CollectNodeArrayResult()
        
        _ = try context.push(dictionary: [CollectNodeResultKey: result]) {
            try renderNodes(nodes, context)
        }
        
        context[targetName] = result.value
        
        return ""
    }
}

fileprivate let CollectNodeResultKey = "__collect_node_result__"

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
    let key: Resolvable?

    init(value: Resolvable, key: Resolvable? = nil) {
        self.value = value
        self.key = key
    }

    class func parse(_ parser: TokenParser, token: Token) throws -> NodeType {
        let components = token.components

        guard components.count >= 2 else {
            throw TemplateSyntaxError(
                "'append' tag requires at least a value to append"
            )
        }

        let value = try parser.compileResolvable(components[1], containedIn: token)

        // Check if this is a keyed append
        if components.count >= 4 && components[2] == "keyed" {
            let key = try parser.compileResolvable(components[3], containedIn: token)
            return AppendNode(value: value, key: key)
        }

        return AppendNode(value: value)
    }

    func render(_ context: Context) throws -> String {
        guard let result = context[CollectNodeResultKey] as? CollectNodeResult else {
            throw TemplateSyntaxError("'append' tag not inside of a 'collect' tag.")
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
