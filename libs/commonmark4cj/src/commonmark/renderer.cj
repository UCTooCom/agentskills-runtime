/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2024. All rights reserved.
 */

package commonmark4cj.commonmark

public interface Renderer {
    /**
     * Render the tree of nodes to output.
     *
     * @param node the root node
     * @param output output for rendering
     */
    func render(node: Node, output: StringBuilder): Unit
    /**
     * Render the tree of nodes to string.
     *
     * @param node the root node
     * @return the rendered string
     */
    func render(node: Node): String
}

/**
 * A renderer for a set of node types.
 */
public interface NodeRenderer {

    /**
     * @return the types of nodes that this renderer handles
     */
    func getNodeTypes(): HashSet<NodeType>

    /**
     * Render the specified node.
     *
     * @param node the node to render, will be an instance of one of {@link #getNodeTypes()}
     */
    func render(node: Node): Unit
}

class NodeRendererMap {
    private let renderers: HashMap<NodeType, NodeRenderer> = HashMap<NodeType, NodeRenderer>()

    public func add(nodeRenderer: NodeRenderer): Unit {
        for (nodeType in nodeRenderer.getNodeTypes()) {
            // Overwrite existing renderer
            renderers.add(nodeType, nodeRenderer)
        }
    }

    public func render(node: Node): Unit {
        let nodeRenderer: ?NodeRenderer = renderers.get(node.getNodeType())
        if (nodeRenderer.isSome()) {
            nodeRenderer?.render(node)
        }
    }
}
