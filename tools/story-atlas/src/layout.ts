import dagre from "@dagrejs/dagre";
import type { Edge, Node } from "@xyflow/react";
import type { StoryEdge, StoryNode } from "./types";

export interface FlowNodeData extends Record<string, unknown> {
  story: StoryNode;
  imagePath?: string;
  imageFit?: "cover" | "contain";
}

const NODE_WIDTH = 244;
const NODE_HEIGHT = 166;

export function toFlowElements(nodes: StoryNode[], edges: StoryEdge[]) {
  const graph = new dagre.graphlib.Graph().setDefaultEdgeLabel(() => ({}));
  graph.setGraph({
    rankdir: "LR",
    ranksep: 96,
    nodesep: 42,
    edgesep: 18,
    marginx: 40,
    marginy: 40
  });

  for (const node of nodes) {
    graph.setNode(node.id, { width: NODE_WIDTH, height: NODE_HEIGHT });
  }
  for (const edge of edges) {
    if (edge.kind !== "return") graph.setEdge(edge.source, edge.target);
  }
  dagre.layout(graph);

  const flowNodes: Array<Node<FlowNodeData>> = nodes.map((story) => {
    const point = graph.node(story.id) || { x: 0, y: 0 };
    const imagePath = story.assetPaths.find((path) => /\.(png|jpe?g|webp)$/i.test(path));
    const imageFit = imagePath && /^game\/assets\/(ritual|gear|cups)\//.test(imagePath)
      ? "contain"
      : "cover";
    return {
      id: story.id,
      type: "story",
      position: {
        x: point.x - NODE_WIDTH / 2,
        y: point.y - NODE_HEIGHT / 2
      },
      data: {
        story,
        imagePath,
        imageFit
      }
    };
  });

  const flowEdges: Edge[] = edges.map((edge) => ({
    id: edge.id,
    source: edge.source,
    target: edge.target,
    label: edge.label,
    type: "default",
    animated: edge.kind === "input",
    className: `edge-${edge.kind}`,
    markerEnd: {
      type: "arrowclosed" as const,
      color: "#394b3a",
      width: 14,
      height: 14
    }
  }));

  return { nodes: flowNodes, edges: flowEdges };
}
