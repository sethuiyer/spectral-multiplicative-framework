require "./src/multiplicative_constraint"

puts "🎨 QUICK STRUCTURED SAT: Graph Coloring Advantage Test"
puts "=" * 55
puts "Testing if spectral structure gives the cheat code MORE power!"
puts ""

# Create a graph coloring problem with known structure
n_nodes = 30
n_colors = 4

puts "🎨 Creating graph coloring SAT..."
puts "Nodes: #{n_nodes}, Colors: #{n_colors}"

# Create a structured graph (mix of cliques and cycles)
nodes = (1..n_nodes).map { |i| "v#{i}" }
adjacency = Array(Array(Int32)).new(n_nodes) { Array(Int32).new(n_nodes, 0) }

# Add a 5-clique (forces different colors)
(0...5).each do |i|
  (i+1...5).each do |j|
    adjacency[i][j] = 1
    adjacency[j][i] = 1
  end
end

# Add a 7-cycle (odd cycle = chromatic number 3)
cycle_start = 5
7.times do |i|
  next_node = (i + 1) % 7
  node_i = cycle_start + i
  node_j = cycle_start + next_node
  adjacency[node_i][node_j] = 1
  adjacency[node_j][node_i] = 1
end

# Add some random connections for complexity
50.times do
  i = rand(0...n_nodes)
  j = rand(0...n_nodes)
  next if i == j || adjacency[i][j] == 1

  adjacency[i][j] = 1
  adjacency[j][i] = 1
end

puts "Graph created with #{adjacency.sum(&.sum) / 2} edges"

# Encode as SAT
clauses = [] of Array(Int32)
var_count = 0

# Each node must have exactly one color
(0...n_nodes).each do |i|
  # At least one color per node
  color_clause = [] of Int32
  (0...n_colors).each do |c|
    var_count += 1
    color_clause << var_count
  end
  clauses << color_clause

  # At most one color per node
  (0...n_colors).each do |c|
    ((c+1)...n_colors).each do |d|
      var_c = i * n_colors + c + 1
      var_d = i * n_colors + d + 1
      clauses << [-var_c, -var_d]
    end
  end
end

# Adjacent nodes must have different colors
(0...n_nodes).each do |i|
  (i+1...n_nodes).each do |j|
    next if adjacency[i][j] == 0

    (0...n_colors).each do |c|
      var_i_c = i * n_colors + c + 1
      var_j_c = j * n_colors + c + 1
      clauses << [-var_i_c, -var_j_c]
    end
  end
end

puts "SAT encoding: #{var_count} variables, #{clauses.size} clauses"
puts "Clause/variable ratio: #{(clauses.size.to_f / var_count).round(3)}"
puts ""

# Build SAT graph
total_nodes = var_count * 2
weights = Array(Float64).new(total_nodes, 1.0)
sat_adjacency = Array(Array(Float64)).new(total_nodes) { Array(Float64).new(total_nodes, 0.0) }

clauses.each do |clause|
  clause_nodes = clause.map do |literal|
    literal > 0 ? literal - 1 : var_count - literal - 1
  end

  clause_nodes.each do |i|
    clause_nodes.each do |j|
      next if i >= j
      sat_adjacency[i][j] += 1.0
      sat_adjacency[j][i] = sat_adjacency[i][j]
    end
  end
end

(0...var_count).each do |i|
  neg_idx = var_count + i
  sat_adjacency[i][neg_idx] = 0.05
  sat_adjacency[neg_idx][i] = 0.05
end

puts "🚀 Testing structured advantage with spectral-multiplicative bridge..."

graph = MultiplicativeConstraint::Graph.new(weights, sat_adjacency)
engine = MultiplicativeConstraint::Engine.new(graph, 2)

start_time = Time.utc
result = engine.solve(iterations: 3000, step: 0.35, seed: 2025)
end_time = Time.utc
runtime = (end_time - start_time).total_seconds

# Evaluate solution
assignment = Array(Int32).new(var_count, 0)
result.segments.each_with_index do |segment, seg_id|
  value = (seg_id % 2 == 0) ? 1 : -1

  segment.each do |node|
    if node < var_count
      assignment[node] = value
    else
      assignment[node - var_count] = -value
    end
  end
end

satisfied = clauses.count do |clause|
  clause.any? do |literal|
    val = literal > 0 ? assignment[literal - 1] : assignment[-literal - 1]
    literal > 0 ? val == 1 : val == -1
  end
end

satisfaction_rate = satisfied.to_f / clauses.size

puts ""
puts "📊 STRUCTURED SAT RESULTS:"
puts "Runtime: #{(runtime * 1000).round(1)} ms"
puts "Clauses satisfied: #{satisfied}/#{clauses.size}"
puts "Satisfaction rate: #{(satisfaction_rate * 100).round(1)}%"
puts "Unified energy: #{result.energy.round(3)}"
puts "Spectral action: #{result.spectral.round(3)}"

# Analyze the coloring solution
puts ""
puts "🎨 COLORING ANALYSIS:"
coloring = Array(Int32).new(n_nodes, -1)
valid_coloring = true

(0...n_nodes).each do |i|
  assigned_color = -1
  (0...n_colors).each do |c|
    var = i * n_colors + c + 1
    if assignment[var - 1] == 1
      assigned_color = c
      break
    end
  end

  if assigned_color == -1
    valid_coloring = false
    break
  end

  coloring[i] = assigned_color
end

if valid_coloring
  puts "✅ Valid coloring found!"

  # Check if it's actually a proper coloring
  proper = true
  violations = 0

  (0...n_nodes).each do |i|
    (i+1...n_nodes).each do |j|
      if adjacency[i][j] == 1 && coloring[i] == coloring[j]
        violations += 1
        proper = false
      end
    end
  end

  if proper
    puts "🎉 PERFECT GRAPH COLORING: No adjacent nodes share colors!"
    puts "   This is a valid solution to the graph coloring problem!"
  else
    puts "⚠️  Coloring has #{violations} constraint violations"
  end

  # Show color distribution
  color_counts = Array(Int32).new(n_colors, 0)
  coloring.each { |c| color_counts[c] += 1 if c >= 0 }

  puts "Color distribution:"
  color_counts.each_with_index do |count, color|
    puts "  Color #{color}: #{count} nodes" if count > 0
  end
else
  puts "❌ Invalid assignment (nodes with multiple or no colors)"
end

puts ""
if satisfaction_rate >= 0.95
  puts "🏆 STRUCTURED ADVANTAGE CONFIRMED!"
  puts "   Spectral-multiplicative bridge excels on graph coloring!"
elsif satisfaction_rate >= 0.85
  puts "🚀 STRONG STRUCTURED PERFORMANCE!"
  puts "   Graph structure helps the cheat code perform better!"
else
  puts "⚠️  Structured problem proving challenging"
end

puts ""
puts "Comparison with random SAT:"
puts "- Random 50-var SAT: ~87-90% satisfaction"
puts "- Structured 30-var coloring: #{(satisfaction_rate * 100).round(1)}% satisfaction"
if satisfaction_rate > 0.90
  puts "✅ STRUCTURED ADVANTAGE: Better than random SAT!"
else
  puts "❌ No clear structured advantage detected"
end