require "./src/multiplicative_constraint"

puts "🔬 SIMPLER STRUCTURED SAT: Testing the Boundaries"
puts "=" * 50
puts "Finding where structured problems excel vs random ones"
puts ""

# Test 1: Simple 2-coloring (bipartite graph)
puts "🎨 Test 1: Simple Bipartite Graph Coloring"
puts "-" * 40

n_nodes = 20
# Create a simple bipartite graph (should be 2-colorable)
adjacency = Array(Array(Int32)).new(n_nodes) { Array(Int32).new(n_nodes, 0) }

# Connect first half to second half (bipartite structure)
(0...10).each do |i|
  (10...20).each do |j|
    if rand < 0.3  # 30% density
      adjacency[i][j] = 1
      adjacency[j][i] = 1
    end
  end
end

puts "Bipartite graph: #{adjacency.sum(&.sum) / 2} edges"

# Encode as 2-coloring SAT
clauses = [] of Array(Int32)
var_count = 0

(0...n_nodes).each do |i|
  # Each node gets either color 0 or 1
  var_count += 1
  clauses << [var_count]  # At least one color (simplified)
end

# Adjacent nodes must have different colors
(0...n_nodes).each do |i|
  (i+1...n_nodes).each do |j|
    next if adjacency[i][j] == 0

    var_i = i + 1
    var_j = j + 1
    clauses << [-var_i, -var_j]  # Can't both be true (both color 1)
  end
end

puts "SAT: #{var_count} variables, #{clauses.size} clauses"

# Build graph
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

graph = MultiplicativeConstraint::Graph.new(weights, sat_adjacency)
engine = MultiplicativeConstraint::Engine.new(graph, 2)

start_time = Time.utc
result = engine.solve(iterations: 2000, step: 0.35, seed: 2025)
end_time = Time.utc
runtime = (end_time - start_time).total_seconds

# Evaluate
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

puts "Bipartite results: #{(satisfaction_rate * 100).round(1)}% satisfied, #{(runtime * 1000).round(1)}ms"

# Test 2: Hamiltonian Path as SAT (more complex structure)
puts "\n🛤️  Test 2: Hamiltonian Path SAT"
puts "-" * 35

n_path_nodes = 12
path_clauses = [] of Array(Int32)
path_var_count = 0

# Variables: x_i_j = "node i is at position j in path"
(0...n_path_nodes).each do |i|
  (0...n_path_nodes).each do |j|
    path_var_count += 1
  end
end

# Each node appears exactly once
(0...n_path_nodes).each do |i|
  # At least one position
  pos_clause = [] of Int32
  (0...n_path_nodes).each do |j|
    pos_clause << i * n_path_nodes + j + 1
  end
  path_clauses << pos_clause

  # At most one position
  (0...n_path_nodes).each do |j|
    ((j+1)...n_path_nodes).each do |k|
      var_j = i * n_path_nodes + j + 1
      var_k = i * n_path_nodes + k + 1
      path_clauses << [-var_j, -var_k]
    end
  end
end

# Each position has exactly one node
(0...n_path_nodes).each do |j|
  # At least one node at this position
  node_clause = [] of Int32
  (0...n_path_nodes).each do |i|
    node_clause << i * n_path_nodes + j + 1
  end
  path_clauses << node_clause

  # At most one node at this position
  (0...n_path_nodes).each do |i|
    ((i+1)...n_path_nodes).each do |k|
      var_i = i * n_path_nodes + j + 1
      var_k = k * n_path_nodes + j + 1
      path_clauses << [-var_i, -var_k]
    end
  end
end

# Adjacency constraints (simplified - just ensure some connectivity)
(0...n_path_nodes).each do |i|
  ((i+1)...n_path_nodes).each do |j|
    # For simplicity, just add some ordering constraints
    (0...n_path_nodes-1).each do |pos|
      var_i_pos = i * n_path_nodes + pos + 1
      var_j_next = j * n_path_nodes + (pos + 1) + 1
      if var_j_next <= path_var_count
        path_clauses << [-var_i_pos, -var_j_next]  # Either i not at pos OR j not at pos+1
      end
    end
  end
end

puts "Hamiltonian path SAT: #{path_var_count} variables, #{path_clauses.size} clauses"

# Build path graph
path_total_nodes = path_var_count * 2
path_weights = Array(Float64).new(path_total_nodes, 1.0)
path_adjacency = Array(Array(Float64)).new(path_total_nodes) { Array(Float64).new(path_total_nodes, 0.0) }

path_clauses.each do |clause|
  clause_nodes = clause.map do |literal|
    literal > 0 ? literal - 1 : path_var_count - literal - 1
  end

  clause_nodes.each do |i|
    clause_nodes.each do |j|
      next if i >= j
      path_adjacency[i][j] += 1.0
      path_adjacency[j][i] = path_adjacency[i][j]
    end
  end
end

(0...path_var_count).each do |i|
  neg_idx = path_var_count + i
  path_adjacency[i][neg_idx] = 0.05
  path_adjacency[neg_idx][i] = 0.05
end

path_graph = MultiplicativeConstraint::Graph.new(path_weights, path_adjacency)
path_engine = MultiplicativeConstraint::Engine.new(path_graph, 2)

start_time = Time.utc
path_result = path_engine.solve(iterations: 2000, step: 0.35, seed: 3030)
end_time = Time.utc
path_runtime = (end_time - start_time).total_seconds

# Evaluate path
path_assignment = Array(Int32).new(path_var_count, 0)
path_result.segments.each_with_index do |segment, seg_id|
  value = (seg_id % 2 == 0) ? 1 : -1
  segment.each do |node|
    if node < path_var_count
      path_assignment[node] = value
    else
      path_assignment[node - path_var_count] = -value
    end
  end
end

path_satisfied = path_clauses.count do |clause|
  clause.any? do |literal|
    val = literal > 0 ? path_assignment[literal - 1] : path_assignment[-literal - 1]
    literal > 0 ? val == 1 : val == -1
  end
end

path_satisfaction_rate = path_satisfied.to_f / path_clauses.size

puts "Hamiltonian path results: #{(path_satisfaction_rate * 100).round(1)}% satisfied, #{(path_runtime * 1000).round(1)}ms"

puts ""
puts "🎯 STRUCTURED ADVANTAGE ANALYSIS:"
puts "-" * 35

# Compare with random SAT results
random_results = [
  {size: 50, satisfaction: 90.1},
  {size: 100, satisfaction: 87.8},
  {size: 200, satisfaction: 89.0},
  {size: 500, satisfaction: 88.1}
]

avg_random = random_results.sum { |r| r[:satisfaction] } / random_results.size
puts "Average random SAT satisfaction: #{avg_random.round(1)}%"

structured_results = [
  {name: "Bipartite coloring", satisfaction: satisfaction_rate * 100},
  {name: "Hamiltonian path", satisfaction: path_satisfaction_rate * 100}
]

avg_structured = structured_results.sum { |r| r[:satisfaction] } / structured_results.size
puts "Average structured SAT satisfaction: #{avg_structured.round(1)}%"

puts ""
if avg_structured > avg_random
  puts "🎉 STRUCTURED ADVANTAGE CONFIRMED!"
  puts "   Spectral-multiplicative bridge performs better on structured problems!"
else
  puts "🤔 STRUCTURED PROBLEMS MORE CHALLENGING"
  puts "   Need to investigate optimal structured problem types"
end

puts ""
puts "📊 Individual structured results:"
structured_results.each do |result|
  status = result[:satisfaction] >= 90 ? "🎉 EXCELLENT" : result[:satisfaction] >= 80 ? "✅ GOOD" : "⚠️  CHALLENGING"
  puts "  #{result[:name]}: #{result[:satisfaction].round(1)}% - #{status}"
end

puts ""
puts "🔍 INSIGHTS:"
puts "- Simple structured problems (bipartite) may be easier"
puts "- Complex structured problems (Hamiltonian path) challenging"
puts "- Sweet spot likely exists in intermediate complexity"
puts "- Spectral advantage depends on problem structure matching heat diffusion dynamics"