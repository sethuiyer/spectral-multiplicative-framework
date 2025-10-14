require "./src/multiplicative_constraint"

# Quick phase transition test - 500 variables at hardest point
variables = (1..500).map { |i| "x#{i}" }
n_vars = 500
n_clauses = (n_vars * 4.266).round.to_i  # Phase transition!

puts "🔥 QUICK PHASE TRANSITION TEST"
puts "#{n_vars} variables, #{n_clauses} clauses"
puts "Ratio: #{(n_clauses.to_f / n_vars).round(3)} - HARDEST REGION!"
puts ""

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

# Build graph
n = n_vars
total_nodes = n * 2
weights = Array(Float64).new(total_nodes, 1.0)
adjacency = Array(Array(Float64)).new(total_nodes) { Array(Float64).new(total_nodes, 0.0) }

clauses.each do |clause|
  clause_nodes = clause.map do |literal|
    literal > 0 ? literal - 1 : n - literal - 1
  end

  clause_nodes.each do |i|
    clause_nodes.each do |j|
      next if i >= j
      adjacency[i][j] += 1.0
      adjacency[j][i] = adjacency[i][j]
    end
  end
end

(0...n).each do |i|
  neg_idx = n + i
  adjacency[i][neg_idx] = 0.05
  adjacency[neg_idx][i] = 0.05
end

puts "🚀 Testing cheat code at phase transition..."

graph = MultiplicativeConstraint::Graph.new(weights, adjacency)
engine = MultiplicativeConstraint::Engine.new(graph, 2)

start_time = Time.utc
result = engine.solve(iterations: 3000, step: 0.35, seed: 2025)
end_time = Time.utc
runtime = (end_time - start_time).total_seconds

puts "Runtime: #{(runtime * 1000).round(1)} ms"

# Evaluate satisfaction
assignment = Array(Int32).new(n, 0)
result.segments.each_with_index do |segment, seg_id|
  value = (seg_id % 2 == 0) ? 1 : -1
  segment.each do |node|
    if node < n
      assignment[node] = value
    else
      assignment[node - n] = -value
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
puts "📊 RESULTS:"
puts "Clauses satisfied: #{satisfied}/#{clauses.size}"
puts "Satisfaction rate: #{(satisfaction_rate * 100).round(1)}%"

if satisfaction_rate >= 0.95
  puts "🎉 CHEAT CODE CONQUERS PHASE TRANSITION!"
  puts "   Traditional SAT solvers would struggle here!"
elsif satisfaction_rate >= 0.80
  puts "🚀 STRONG PERFORMANCE at computational complexity event horizon!"
elsif satisfaction_rate >= 0.60
  puts "✅ RESPECTABLE performance in the hardest region"
else
  puts "⚠️  Phase transition proving challenging even for cheat code"
end

puts ""
puts "Unified energy: #{result.energy.round(3)}"
puts "Spectral action: #{result.spectral.round(3)}"