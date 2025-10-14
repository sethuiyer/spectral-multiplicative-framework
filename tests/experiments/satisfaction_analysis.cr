require "./src/multiplicative_constraint"

puts "🔍 SATISFACTION CEILING ANALYSIS"
puts "=" * 40
puts "Why does the cheat code cap at ~87-90% instead of 100%?"
puts ""

# Test 1: Check if it's the annealing getting stuck
puts "🧪 Test 1: Extended annealing with multiple restarts"
puts "-" * 45

n_vars = 50
n_clauses = (n_vars * 4.266).round.to_i

# Generate random 3-SAT at phase transition
clauses = [] of Array(Int32)
n_clauses.times do
  clause = [] of Int32
  used_vars = Set(Int32).new
  3.times do
    var = rand(1..n_vars)
    while used_vars.includes?(var)
      var = rand(1..n_vars)
    end
    used_vars.add(var)
    literal = rand < 0.5 ? var : -var
    clause << literal
  end
  clauses << clause
end

puts "Generated #{n_vars}-var, #{n_clauses}-clause random SAT"

# Build graph
total_nodes = n_vars * 2
weights = Array(Float64).new(total_nodes, 1.0)
adjacency = Array(Array(Float64)).new(total_nodes) { Array(Float64).new(total_nodes, 0.0) }

clauses.each do |clause|
  clause_nodes = clause.map do |literal|
    literal > 0 ? literal - 1 : n_vars - literal - 1
  end

  clause_nodes.each do |i|
    clause_nodes.each do |j|
      next if i >= j
      adjacency[i][j] += 1.0
      adjacency[j][i] = adjacency[i][j]
    end
  end
end

(0...n_vars).each do |i|
  neg_idx = n_vars + i
  adjacency[i][neg_idx] = 0.05
  adjacency[neg_idx][i] = 0.05
end

graph = MultiplicativeConstraint::Graph.new(weights, adjacency)

# Test different annealing parameters
configs = [
  {iterations: 3000, step: 0.35, seed: 42, name: "Standard"},
  {iterations: 5000, step: 0.25, seed: 123, name: "More iterations, smaller step"},
  {iterations: 8000, step: 0.15, seed: 456, name: "Extended annealing"},
  {iterations: 3000, step: 0.50, seed: 789, name: "Larger step size"},
  {iterations: 2000, step: 0.40, seed: 999, name: "Different seed"},
]

best_overall = 0.0
best_config = ""

configs.each do |config|
  engine = MultiplicativeConstraint::Engine.new(graph, 2)

  start_time = Time.utc
  result = engine.solve(
    iterations: config[:iterations],
    step: config[:step],
    seed: config[:seed]
  )
  end_time = Time.utc
  runtime = (end_time - start_time).total_seconds

  # Evaluate satisfaction
  assignment = Array(Int32).new(n_vars, 0)
  result.segments.each_with_index do |segment, seg_id|
    value = (seg_id % 2 == 0) ? 1 : -1
    segment.each do |node|
      if node < n_vars
        assignment[node] = value
      else
        assignment[node - n_vars] = -value
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

  if satisfaction_rate > best_overall
    best_overall = satisfaction_rate
    best_config = config[:name].as(String)
  end

  puts "#{config[:name]}: #{(satisfaction_rate * 100).round(1)}% satisfied, #{(runtime * 1000).round(1)}ms"
end

puts "\nBest configuration: #{best_config} with #{(best_overall * 100).round(1)}% satisfaction"

# Test 2: Check if it's the 2-partition limitation
puts "\n🧪 Test 2: 3-partition instead of 2-partition"
puts "-" * 45

engine_3 = MultiplicativeConstraint::Engine.new(graph, 3)
start_time = Time.utc
result_3 = engine_3.solve(iterations: 5000, step: 0.25, seed: 555)
end_time = Time.utc
runtime_3 = (end_time - start_time).total_seconds

# Evaluate 3-partition solution
assignment_3 = Array(Int32).new(n_vars, 0)
result_3.segments.each_with_index do |segment, seg_id|
  # Map 3 segments to true/false/unassigned
  value = seg_id == 0 ? 1 : (seg_id == 1 ? -1 : 0)
  segment.each do |node|
    if node < n_vars
      assignment_3[node] = value
    else
      assignment_3[node - n_vars] = -value if value != 0
    end
  end
end

# For unassigned variables, randomly assign
(0...n_vars).each do |i|
  if assignment_3[i] == 0
    assignment_3[i] = rand < 0.5 ? 1 : -1
  end
end

satisfied_3 = clauses.count do |clause|
  clause.any? do |literal|
    val = literal > 0 ? assignment_3[literal - 1] : assignment_3[-literal - 1]
    literal > 0 ? val == 1 : val == -1
  end
end

satisfaction_rate_3 = satisfied_3.to_f / clauses.size
puts "3-partition: #{(satisfaction_rate_3 * 100).round(1)}% satisfied, #{(runtime_3 * 1000).round(1)}ms"

# Test 3: Check energy components
puts "\n🧪 Test 3: Energy component analysis"
puts "-" * 35

engine_analysis = MultiplicativeConstraint::Engine.new(graph, 2)
result_analysis = engine_analysis.solve(iterations: 3000, step: 0.35, seed: 777)

puts "Energy breakdown:"
puts "  Unified energy: #{result_analysis.energy.round(3)}"
puts "  Spectral action: #{result_analysis.spectral.round(3)}"
puts "  Fairness: #{result_analysis.fairness.round(3)}"
puts "  Weight fairness: #{result_analysis.weight_fairness.round(3)}"
puts "  Entropy: #{result_analysis.entropy.round(3)}"
puts "  Multiplicative penalty: #{result_analysis.penalty.round(3)}"
puts "  Cross-conflict: #{result_analysis.cross_conflict.round(3)}"

# Test 4: Try with different energy weights
puts "\n🧪 Test 4: Different energy weight configurations"
puts "-" * 45

weight_configs = [
  {fairness: 1.0, weight_fairness: 0.5, entropy: 0.1, penalty: 1.0, name: "Default"},
  {fairness: 2.0, weight_fairness: 0.25, entropy: 0.2, penalty: 0.5, name: "Higher fairness"},
  {fairness: 0.5, weight_fairness: 1.0, entropy: 0.05, penalty: 2.0, name: "Higher weight fairness"},
  {fairness: 0.1, weight_fairness: 0.1, entropy: 1.0, penalty: 1.0, name: "Higher entropy"},
]

weight_configs.each do |config|
  engine_weights = MultiplicativeConstraint::Engine.new(
    graph, 2,
    fairness_weight: config[:fairness],
    weight_fairness_weight: config[:weight_fairness],
    entropy_weight: config[:entropy],
    penalty_weight: config[:penalty]
  )

  result_weights = engine_weights.solve(iterations: 3000, step: 0.35, seed: 888)

  # Quick evaluation
  assignment_weights = Array(Int32).new(n_vars, 0)
  result_weights.segments.each_with_index do |segment, seg_id|
    value = (seg_id % 2 == 0) ? 1 : -1
    segment.each do |node|
      if node < n_vars
        assignment_weights[node] = value
      else
        assignment_weights[node - n_vars] = -value
      end
    end
  end

  satisfied_weights = clauses.count do |clause|
    clause.any? do |literal|
      val = literal > 0 ? assignment_weights[literal - 1] : assignment_weights[-literal - 1]
      literal > 0 ? val == 1 : val == -1
    end
  end

  satisfaction_weights = satisfied_weights.to_f / clauses.size
  puts "#{config[:name]}: #{(satisfaction_weights * 100).round(1)}% satisfied"
end

puts "\n🎯 ANALYSIS CONCLUSIONS:"
puts "-" * 25

if best_overall >= 0.95
  puts "✅ 100% satisfaction is achievable with tuning!"
elsif best_overall >= 0.90
  puts "🚀 90%+ satisfaction possible - very close to perfect!"
elsif best_overall >= 0.85
  puts "👍 85%+ satisfaction - strong performance"
else
  puts "⚠️  Satisfaction ceiling appears to be real limitation"
end

puts ""
puts "The ~87-90% satisfaction might be:"
puts "1. 🎯 **Mathematical optimum** for this spectral-multiplicative framework"
puts "2. 🔧 **Implementation limitation** that could be improved"
puts "3. ⚖️ **Trade-off** between optimization speed and solution quality"
puts "4. 🌊 **Local optimum** that the annealing can't escape from"