require "../../src/multiplicative_constraint"

puts "🎨 GRAPH COLORING TEST: 5-VERTICES, 3-COLORS (RGB)"
puts "Representing colors with 2 bits: 11=red, 10=green, 01=blue, 00=invalid"
puts "="*70

# 5 vertices, each represented by 2 bits
# v1v2 = vertex1 color, v3v4 = vertex2 color, v5v6 = vertex3 color
# v7v8 = vertex4 color, v9v10 = vertex5 color
# Colors: 11=red, 10=green, 01=blue, 00=invalid

vertices = 5
variables = 10  # 2 bits per vertex

puts "📊 GRAPH COLORING PROBLEM:"
puts "Vertices: #{vertices}"
puts "Colors: 3 (Red=11, Green=10, Blue=01)"
puts "Bit representation: 2 bits per vertex"

# Define the graph edges (which vertices are connected)
# Based on your formula, I can infer some edges
# Let's create a sample graph
edges = [
  [1, 3],  # vertex1 connected to vertex3
  [1, 2],  # vertex1 connected to vertex2
  [2, 3],  # vertex2 connected to vertex3
  [3, 4],  # vertex3 connected to vertex4
  [4, 5],  # vertex4 connected to vertex5
  [1, 5],  # vertex1 connected to vertex5
]

puts "\n🔗 Graph edges:"
edges.each do |edge|
  u, v = edge
  puts "  Vertex #{u} -- Vertex #{v}"
end

# Convert to SAT constraints
clauses = [] of Array(Int32)

puts "\n🧠 Converting graph coloring to SAT constraints..."

# 1. Each vertex must have exactly one valid color (no invalid colors)
(1..vertices).each do |v|
  bit1 = 2*v - 1
  bit2 = 2*v

  # Not 00 (invalid color)
  clauses << [bit1, bit2]  # v1 OR v2 (at least one must be true)

  # Encourage valid colors by penalizing invalid combinations
  # We'll add constraints to make valid colors more likely
end

# 2. Connected vertices must have different colors
edges.each_with_index do |edge, edge_idx|
  u, v = edge
  puts "\nEdge #{edge_idx + 1}: Vertex #{u} != Vertex #{v}"

  u_bit1 = 2*u - 1
  u_bit2 = 2*u
  v_bit1 = 2*v - 1
  v_bit2 = 2*v

  # Colors are encoded as:
  # Red: 11, Green: 10, Blue: 01, Invalid: 00

  # Constraint: NOT(color_u == color_v)
  # This expands to: NOT((u_bit1 == v_bit1) AND (u_bit2 == v_bit2))
  # Which is: (u_bit1 != v_bit1) OR (u_bit2 != v_bit2)

  # (u_bit1 != v_bit1) OR (u_bit2 != v_bit2)
  # = (u_bit1 XOR v_bit1) OR (u_bit2 XOR v_bit2)
  # = (u_bit1 AND NOT v_bit1) OR (NOT u_bit1 AND v_bit1) OR (u_bit2 AND NOT v_bit2) OR (NOT u_bit2 AND v_bit2)

  clauses << [u_bit1, -v_bit1, u_bit2, -v_bit2]  # (u1 AND NOT v1) OR (u2 AND NOT v2)
  clauses << [-u_bit1, v_bit1, u_bit2, -v_bit2]  # (NOT u1 AND v1) OR (u2 AND NOT v2)
  clauses << [u_bit1, -v_bit1, -u_bit2, v_bit2]  # (u1 AND NOT v1) OR (NOT u2 AND v2)
  clauses << [-u_bit1, v_bit1, -u_bit2, v_bit2]  # (NOT u1 AND v1) OR (NOT u2 AND v2)
end

puts "\n📋 Generated #{clauses.size} SAT clauses for graph coloring"

# Create node mapping
all_literals = clauses.flatten.uniq
literal_to_node = {} of Int32 => Int32
node_to_literal = {} of Int32 => Int32

all_literals.each_with_index do |literal, idx|
  literal_to_node[literal] = idx
  node_to_literal[idx] = literal
end

total_nodes = all_literals.size
weights = Array(Float64).new(total_nodes, 1.0)
adjacency = Array(Array(Float64)).new(total_nodes) { Array(Float64).new(total_nodes, 0.0) }

puts "\n🔗 Building quantum graph coloring network with #{total_nodes} nodes..."

# Add constraint weights
clauses.each_with_index do |clause, clause_idx|
  clause.each do |literal1|
    clause.each do |literal2|
      next if literal1 == literal2

      node1 = literal_to_node[literal1]
      node2 = literal_to_node[literal2]

      # Strong negative weight for literals in same clause
      adjacency[node1][node2] = -30.0
      adjacency[node2][node1] = -30.0
    end
  end
end

# Add preferences for valid color combinations
(1..vertices).each do |v|
  bit1 = 2*v - 1
  bit2 = 2*v

  # Prefer valid colors: 11 (red), 10 (green), 01 (blue)
  if literal_to_node.has_key?(bit1) && literal_to_node.has_key?(bit2)
    node1 = literal_to_node[bit1]
    node2 = literal_to_node[bit2]

    # Positive correlation for valid colors
    adjacency[node1][node2] = 10.0
    adjacency[node2][node1] = 10.0
  end
end

puts "\n🎨 Launching quantum graph coloring solver..."
puts "Total nodes: #{total_nodes}"
puts "Constraint complexity: High - Graph coloring with bit encoding"

# Run quantum solver
start_time = Time.utc

graph = MultiplicativeConstraint::Graph.new(weights, adjacency)
engine = MultiplicativeConstraint::Engine.new(graph, 4)
result = engine.solve(iterations: 4000, seed: 444)

solve_time = (Time.utc - start_time).total_seconds

puts "\n⚡ GRAPH COLORING PERFORMANCE RESULTS"
puts "======================================"
puts "Runtime: #{(solve_time * 1000).round(1)} ms"
puts "Segments: #{result.segments.size}"
puts "Final Energy: #{result.energy.round(3)}"
puts "Spectral Action: #{result.spectral.round(3)}"

# Interpret segments as graph coloring assignment
assignment = Hash(Int32, Bool).new

result.segments.each_with_index do |segment, seg_idx|
  puts "\nSegment #{seg_idx + 1}: #{segment.size} literals"

  segment.each do |node_idx|
    literal = node_to_literal[node_idx]
    var = literal.abs
    is_positive = literal > 0

    if !assignment.has_key?(var)
      assignment[var] = is_positive
    end
  end
end

# Convert bit assignment to colors
puts "\n🎨 GRAPH COLORING ASSIGNMENT:"
colors = {} of Int32 => String

(1..vertices).each do |v|
  bit1 = assignment[2*v - 1]? ? assignment[2*v - 1] : false
  bit2 = assignment[2*v]? ? assignment[2*v] : false

  color = if bit1 && bit2
    "RED (11)"
  elsif bit1 && !bit2
    "GREEN (10)"
  elsif !bit1 && bit2
    "BLUE (01)"
  else
    "INVALID (00)"
  end

  colors[v] = color
  puts "  Vertex #{v}: #{color}"
end

# Verify graph coloring constraints
puts "\n🔍 GRAPH COLORING VERIFICATION:"
puts "================================"

valid_coloring = true

# Check all vertices have valid colors
(1..vertices).each do |v|
  if colors[v].includes?("INVALID")
    puts "❌ Vertex #{v} has invalid color!"
    valid_coloring = false
  end
end

# Check all edges have different colors
edges.each do |edge|
  u, v = edge
  if colors[u] == colors[v]
    puts "❌ Edge (#{u},#{v}): Same color #{colors[u]} == #{colors[v]}"
    valid_coloring = false
  else
    puts "✅ Edge (#{u},#{v}): Different colors #{colors[u]} != #{colors[v]}"
  end
end

# Evaluate SAT satisfaction
puts "\n🔍 SATISFIABILITY ANALYSIS:"
satisfied_clauses = 0
clauses.each_with_index do |clause, clause_idx|
  clause_satisfied = clause.any? do |literal|
    var = literal.abs
    is_positive = literal > 0
    assignment[var]? == is_positive
  end

  if clause_satisfied
    satisfied_clauses += 1
  end
end

satisfaction_rate = (satisfied_clauses.to_f64 / clauses.size * 100).round(1)
puts "Clauses satisfied: #{satisfied_clauses}/#{clauses.size} (#{satisfaction_rate}%)"

# Quality assessment
puts "\n🏆 GRAPH COLORING RESULTS"
puts "=========================="
puts "Vertices: #{vertices}"
puts "Edges: #{edges.size}"
puts "SAT satisfaction: #{satisfaction_rate}%"
puts "Valid coloring: #{valid_coloring ? "✅ YES" : "❌ NO"}"
puts "Runtime: #{(solve_time * 1000).round(1)} ms"

if valid_coloring && satisfaction_rate == 100.0
  puts "🎉 PERFECT! Quantum solved graph coloring!"
  puts "🚀 All vertices colored differently on connected edges!"
  puts "🔬 Quantum methods master combinatorial optimization!"
elsif valid_coloring
  puts "👍 EXCELLENT! Found valid graph coloring!"
  puts "🎯 Successfully colored graph with constraints!"
elsif satisfaction_rate >= 90.0
  puts "✅ VERY GOOD! High satisfaction on graph coloring!"
  puts "🔬 Strong performance on combinatorial problem"
else
  puts "⚠️  CHALLENGING: Graph coloring is NP-complete!"
  puts "💡 This is a classic hard optimization problem"
end

puts "\n🎯 CONCLUSION: Testing quantum methods on graph coloring!"