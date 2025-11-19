#!/usr/bin/env crystal

# Proper List Coloring using the Spectral-Multiplicative Framework's Graph Approach
require "../src/multiplicative_constraint"

puts "🎯 PROPER LIST COLORING: Using Framework's Graph-Based Approach"
puts "=" * 70
puts "Based on the working SAT graph encoding pattern from the framework tests"
puts

# Example: Path graph with 4 nodes - should be 2-colorable
puts "EXAMPLE: Path Graph (4 nodes) - 2-Colorable"
puts "-" * 50

# Define the graph
num_vertices = 4
edges = [
  {0, 1},  # 0-1 
  {1, 2},  # 1-2
  {2, 3}   # 2-3
]

# Define list constraints
color_lists = {
  0 => Set{1, 2},  # Vertex 0: can be color 1 or 2
  1 => Set{1, 2},  # Vertex 1: can be color 1 or 2  
  2 => Set{1, 2},  # Vertex 2: can be color 1 or 2
  3 => Set{1, 2}   # Vertex 3: can be color 1 or 2
}

puts "Graph: Path 0-1-2-3 (should be 2-colorable)"
puts "Lists: #{color_lists}"

# Create a node for each possible vertex-color assignment
# This is the key insight: each (vertex, allowed_color) pair is a graph node
assignment_nodes = [] of {Int32, Int32}  # {vertex, color}
assignment_to_graph_index = {} of {Int32, Int32} => Int32

node_idx = 0
num_vertices.times do |v|
  color_lists[v]?.try do |colors|
    colors.each do |c|
      assignment_nodes << {v, c}
      assignment_to_graph_index[{v, c}] = node_idx
      node_idx += 1
    end
  end
end

num_assignments = assignment_nodes.size
puts "Created #{num_assignments} assignment nodes (vertex-color pairs)"

# Set up graph structure
weights = Array(Float64).new(num_assignments, 1.0)  # Uniform weights
adjacency = Array(Array(Float64)).new(num_assignments) { Array(Float64).new(num_assignments, 0.0) }

# Constraint 1: For each vertex, connect all its color assignments with negative weights
# (only one color per vertex allowed)
num_vertices.times do |v|
  v_colors = [] of Int32
  color_lists[v]?.try do |colors|
    colors.each do |c|
      if assignment_to_graph_index[{v, c}]?
        v_colors << assignment_to_graph_index[{v, c}]
      end
    end
  end
  
  # Connect each pair of color assignments for the same vertex (negative - can't both be selected)
  v_colors.each_with_index do |idx1, i|
    v_colors.each_with_index do |idx2, j|
      next if i >= j  # Avoid duplicates
      adjacency[idx1][idx2] = -50.0  # Strong negative connection
      adjacency[idx2][idx1] = -50.0
    end
  end
end

# Constraint 2: For each edge (u,v), connect same-color assignments with negative weights
# (adjacent vertices can't have same color)
edges.each do |u, v|
  color_lists[u]?.try do |u_colors|
    color_lists[v]?.try do |v_colors|
      # For each color, if both u and v can have it, connect their assignments negatively
      (u_colors & v_colors).each do |c|
        if assignment_to_graph_index[{u, c}]? && assignment_to_graph_index[{v, c}]?
          idx_u = assignment_to_graph_index[{u, c}]
          idx_v = assignment_to_graph_index[{v, c}]
          adjacency[idx_u][idx_v] = -50.0  # Can't both have same color
          adjacency[idx_v][idx_u] = -50.0
        end
      end
    end
  end
end

puts "Added constraints to adjacency matrix"

# Create and solve with the framework
start_time = Time.utc

graph = MultiplicativeConstraint::Graph.new(weights, adjacency)

# Use the framework's optimization engine
engine = MultiplicativeConstraint::Engine.new(
  graph, 
  2,  # 2 segments: one for "selected" assignments, one for "unselected"
  penalty_weight: 10.0,   # Strong penalty for constraint violations
  fairness_weight: 1.0,   # Balance between segments
  calibrate: true,        # Use neural calibration
  enable_corr_guard: true # Maintain correlation
)

result = engine.solve(iterations: 2000, step: 0.35, seed: 12345)
solve_time = (Time.utc - start_time).total_seconds

puts "\n⚡ SOLVING RESULTS"
puts "================="
puts "Variables: #{num_assignments} assignment nodes"
puts "Runtime: #{(solve_time * 1000).round(1)} ms"
puts "Final Energy: #{result.energy.round(3)}"
puts "Spectral Action: #{result.spectral.round(3)}"

# Extract coloring from result
puts "\n🔍 SOLUTION EXTRACTION"
puts "===================="

# Create coloring by checking which assignment nodes are in which segment
coloring = {} of Int32 => Int32

result.segments.each_with_index do |segment_nodes, seg_id|
  segment_nodes.each do |node_idx|
    vertex, color = assignment_nodes[node_idx]
    # In the optimal solution, we want exactly one assignment per vertex to be "selected"
    if seg_id == 0  # Assume segment 0 contains selected assignments
      # Only assign if this vertex doesn't already have a color assigned
      if !coloring[vertex]?
        coloring[vertex] = color
      end
    end
  end
end

# Better approach: Find the most "active" assignment for each vertex
vertex_color_assignments = {} of Int32 => Array({Int32, Int32, Int32, Float64})  # v -> [(color, node_idx, segment, alpha_val)]

assignment_nodes.each_with_index do |(vertex, color), node_idx|
  segment_id = result.discrete_solution[node_idx] || 0
  alpha_val = if node_idx < result.alpha.size
                result.alpha[node_idx]
              else
                0.0  # Default if not available
              end
  
  if vertex_color_assignments[vertex]?
    vertex_color_assignments[vertex] << {color, node_idx, segment_id, alpha_val}
  else
    vertex_color_assignments[vertex] = [{color, node_idx, segment_id, alpha_val}]
  end
end

# For each vertex, select the color with the "most active" assignment
final_coloring = {} of Int32 => Int32
vertex_color_assignments.each do |vertex, assignments|
  # Sort by segment_id (lower is "more selected") or by alpha values
  best_assignment = assignments.min_by { |_, _, seg_id, alpha_val| [seg_id, -alpha_val] }
  final_coloring[vertex] = best_assignment[0] if best_assignment
end

puts "Extracted coloring: #{final_coloring}"

# Validate the result
valid = true
violations = 0

# Check if all vertices are assigned
num_vertices.times do |v|
  if !final_coloring[v]?
    puts "❌ Vertex #{v} not assigned a color"
    valid = false
    violations += 1
  elsif !color_lists[v]?.try(&.includes?(final_coloring[v]))
    puts "❌ Vertex #{v} assigned color #{final_coloring[v]} not in its list #{color_lists[v]}"
    valid = false
    violations += 1
  end
end

# Check adjacency constraints
edges.each do |u, v|
  if final_coloring[u]? && final_coloring[v]? && final_coloring[u] == final_coloring[v]
    puts "❌ Adjacent vertices #{u} and #{v} both assigned same color #{final_coloring[u]}"
    valid = false
    violations += 1
  end
end

if valid
  puts "✅ VALID LIST COLORING FOUND!"
  puts "🎯 All constraints satisfied"
else
  puts "❌ SOLUTION HAS #{violations} VIOLATIONS"
end

puts "\n📊 FINAL RESULTS:"
puts "Graph: Path with #{num_vertices} nodes"
puts "Solved: #{valid ? "SUCCESS" : "FAILED"}"
puts "Violations: #{violations}"
puts "Time: #{(solve_time * 1000).round(1)} ms"
puts "Energy: #{result.energy.round(2)}"

if final_coloring.size > 0
  puts "Coloring: #{final_coloring}"
end

puts
puts "🎯 KEY INSIGHT:"
puts "- Uses framework's native graph optimization approach"
puts "- Each (vertex, color) pair is a node in the optimization graph"
puts "- Constraints are encoded as edge weights in the adjacency matrix"
puts "- Negative weights enforce mutually exclusive assignments"
puts "- Positive weights (if any) would encourage certain assignments"
puts "- Segmentation finds the optimal assignment satisfying constraints"