import Stencil

final class CollectNode: NodeType {
    var token: Stencil.Token?
    private let targetName: String
    private let keyed: Bool
    private var nodes: [AppendNode] = []

    init(targetName: String, keyed: Bool) {
        self.targetName = targetName
        self.keyed = keyed
    }

    class func parse(_ parser: TokenParser, token: Token) throws -> NodeType {
        let components = token.components

        guard components.count >= 2 && components.count <= 3 else {
            throw TemplateSyntaxError(
                "'collect' tag takes a variable name and optionally 'keyed' as arguments"
            )
        }

        let keyed = components.count == 3 && components[2] == "keyed"
        let collectNode = CollectNode(targetName: components[1], keyed: keyed)

        // Parse the block content
        let nodes = try parser.parse(until(["endcollect"]))
        guard parser.nextToken() != nil else {
            throw TemplateSyntaxError("`collect` block was not closed with `endcollect`")
        }

        // Validate that only append nodes are used within the block
        for node in nodes {
            guard let appendNode = node as? AppendNode else {
                guard let textNode = node as? TextNode, textNode.text.trimmed.isEmpty else {
                    throw TemplateSyntaxError("Only `append` tags are allowed within a `collect` block")
                }
                continue
            }

            // Validate append node matches collection type
            if keyed && appendNode.key == nil {
                throw TemplateSyntaxError("Keyed collection requires keyed append operations")
            }
            if !keyed && appendNode.key != nil {
                throw TemplateSyntaxError(
                    "Unkeyed collection does not support keyed append operations")
            }

            collectNode.nodes.append(appendNode)
        }

        return collectNode
    }

    func render(_ context: Context) throws -> String {
        if keyed {
            // Dictionary case
            var dictionary: [String: Any] = [:]

            if let existingDict = context[targetName] as? [String: Any] {
                dictionary = existingDict
            }

            for node in nodes {
                guard let value = try node.value.resolve(context),
                    let key = try node.key?.resolve(context)
                else {
                    continue
                }
                dictionary[String(describing: key)] = value
            }

            context[targetName] = dictionary
        } else {
            // Array case
            var array: [Any] = []

            if let existingArray = context[targetName] as? [Any] {
                array = existingArray
            }

            for node in nodes {
                if let value = try node.value.resolve(context) {
                    array.append(value)
                }
            }

            context[targetName] = array
        }

        return ""
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
        return ""
    }
}
