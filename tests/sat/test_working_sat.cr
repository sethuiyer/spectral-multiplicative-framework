require "../../src/multiplicative_constraint"

puts "🧠 WORKING SAT TEST: Following the 3SAT Pattern"
puts "Using the graph encoding approach that works in the examples"
puts "="*70

# Test the nested logic formula using the working graph encoding approach
# Variables: v1, v2, v3, v4, v5, v6, v7, v8, v9, v10

variables = ["v1", "v2", "v3", "v4", "v5", "v6", "v7", "v8", "v9", "v10"]

puts "🔧 Setting up SAT constraints with graph encoding..."

# CNF clauses from our previous proper conversion
clauses = [
  [3, 4, 7, 8],   # v3 ∨ v4 ∨ v7 ∨ v8
  [3, -4, 7, -8], # v3 ∨ ¬v4 ∨ v7 ∨ ¬v8
  [-3, 4, -7, 8], # ¬v3 ∨ v4 ∨ ¬v7 ∨ v8
  [7, 8, 3, 4],   # v7 ∨ v8 ∨ v3 ∨ v4
  [7, -8, 3, -4], # v7 ∨ ¬v8 ∨ v3 ∨ ¬v4
  [-7, 8, -3, 4], # ¬v7 ∨ v8 ∨ ¬v3 ∨ v4
  [7, -8, 1, 2],  # v7 ∨ ¬v8 ∨ v1 ∨ v2
  [-7, 8, -1, -2], # ¬v7 ∨ v8 ∨ ¬v1 ∨ ¬v2
  [1, 2, 7, 8],   # v1 ∨ v2 ∨ v7 ∨ v8
  [1, -2, 5, 6],  # v1 ∨ ¬v2 ∨ v5 ∨ v6
  [1, -2, -5, -6], # v1 ∨ ¬v2 ∨ ¬v5 ∨ ¬v6
  [-1, 2, 5, 6],  # ¬v1 ∨ v2 ∨ v5 ∨ v6
  [-1, -2, 5, -6], # ¬v1 ∨ ¬v2 ∨ v5 ∨ ¬v6
  [-1, -2, -9, 10], # ¬v1 ∨ ¬v2 ∨ ¬v9 ∨ v10
  [9, 10, 1, -2], # v9 ∨ v10 ∨ v1 ∨ ¬v2
  [9, -10, 1, -2], # v9 ∨ ¬v10 ∨ v1 ∨ ¬v2
  [-9, 10, -1, -2], # ¬v9 ∨ v10 ∨ ¬v1 ∨ ¬v2
  [1, 2],         # v1 ∨ v2
  [-1, 2],        # ¬v1 ∨ v2
  [1, -2]         # v1 ∨ ¬v2
]

puts "\n📊 SAT PROBLEM STATISTICS:"
puts "Variables: #{variables.size}"
puts "Clauses: #{clauses.size}"
puts "Constraint complexity: High - Complex nested logic with 4-literal clauses"

# Create graph using the working 3SAT pattern
n = variables.size * 2  # Variables + negations
weights = Array(Float64).new(n, 1.0)
adjacency = Array(Array(Float64)).new(n) { Array(Float64).new(n, 0.0) }

puts "🏗️ Building SAT graph with #{n} nodes (variables + negations)..."

# Convert clauses to graph connections
clauses.each_with_index do |clause, clause_idx|
  clause_nodes = clause.map do |literal|
    if literal > 0
      literal - 1  # Positive literal: vi becomes node i-1
    else
      variables.size - literal - 1  # Negative literal: ¬vi becomes node n - |vi|
    end
  end

  # Variables in same clause should be positively connected
  clause_nodes.each do |i|
    clause_nodes.each do |j|
      next if i >= j
      adjacency[i][j] += 1.0  # Strong connection for clause mates
      adjacency[j][i] = adjacency[i][j]
    end
  end
end

# Variables and their negations should be negatively connected
variables.each_with_index do |var, i|
  neg_idx = variables.size + i
  adjacency[i][neg_idx] = -0.5  # Negative connection (they can't both be true)
  adjacency[neg_idx][i] = -0.5
end

puts "Graph created with #{n} nodes and #{clauses.size} clause connections"

# Run the optimization using the working 3SAT approach
puts "\n🚀 Running SAT solver using working 3SAT pattern..."
start_time = Time.utc

graph = MultiplicativeConstraint::Graph.new(weights, adjacency)
# Partition into 2 groups (true/false assignments)
engine = MultiplicativeConstraint::Engine.new(graph, 2)

result = engine.solve(iterations: 5000, step: 0.35, seed: 1234)

solve_time = (Time.utc - start_time).total_seconds

puts "\n⚡ PERFORMANCE RESULTS"
puts "===================="
puts "Runtime: #{(solve_time * 1000).round(1)} ms"
puts "Segments: #{result.segments.size}"
puts "Final Energy: #{result.energy.round(3)}"
puts "Spectral Action: #{result.spectral.round(3)}"

# Evaluate the SAT solution using the working 3SAT approach
puts "\n🔍 SATISFIABILITY ANALYSIS"
puts "============================"

assignment = Array(Int32).new(variables.size, 0)  # 0 = unassigned, 1 = true, -1 = false

result.segments.each_with_index do |segment, seg_id|
  value = (seg_id % 2 == 0) ? 1 : -1  # Alternate segments true/false

  segment.each do |node|
    if node < variables.size  # Positive literal
      assignment[node] = value
    else  # Negative literal
      assignment[node - variables.size] = -value
    end
  end
end

puts "Assignment interpretation:"
variables.each_with_index do |var, i|
  val = assignment[i]
  status = case val
           when 1 then "TRUE"
           when -1 then "FALSE"
           else "UNASSIGNED"
           end
  puts "  #{var}: #{status}"
end

# Check clause satisfaction
satisfied_clauses = 0
clauses.each_with_index do |clause, clause_idx|
  clause_satisfied = clause.any? do |literal|
    val = (literal > 0) ? assignment[literal - 1] : assignment[-literal - 1]
    literal > 0 ? val == 1 : val == -1
  end

  if clause_satisfied
    satisfied_clauses += 1
  end

  clause_str = clause.map { |l| l > 0 ? "v#{l}" : "¬v#{-l}" }.join(" ∨ ")
  puts "Clause #{clause_idx + 1}: #{clause_str} - #{clause_satisfied ? "✅ SATISFIED" : "❌ VIOLATED"}"
end

satisfaction_rate = (satisfied_clauses.to_f64 / clauses.size * 100).round(1)

puts "\n📊 SAT SOLVING RESULTS:"
puts "======================"
puts "Variables: #{variables.size}"
puts "Clauses: #{clauses.size}"
puts "Satisfaction: #{satisfaction_rate}%"
puts "Runtime: #{(solve_time * 1000).round(1)} ms"

# Verify key original constraints
puts "\n🧠 ORIGINAL CONSTRAINT VERIFICATION:"
puts "===================================="

# Check: ~((~v3 & ~v4) & (~v7 & ~v8))
constraint1 = !((assignment[2] != 1 && assignment[3] != 1) && (assignment[6] != 1 && assignment[7] != 1))
puts "~((~v3 & ~v4) & (~v7 & ~v8)): #{constraint1 ? "✅" : "❌"}"

# Check: ~((v1 & v2) & (v9 & ~v10))
constraint2 = !((assignment[0] == 1 && assignment[1] == 1) && (assignment[8] == 1 && assignment[9] != 1))
puts "~((v1 & v2) & (v9 & ~v10)): #{constraint2 ? "✅" : "❌"}"

# Check: ((~v1 & ~v2) | (v1 & ~v2) | (~v1 & v2))
constraint3 = (assignment[0] != 1 && assignment[1] != 1) || (assignment[0] == 1 && assignment[1] != 1) || (assignment[0] != 1 && assignment[1] == 1)
puts "XOR(v1, v2): #{constraint3 ? "✅" : "❌"}"

# Quality assessment
puts "\n🏆 WORKING SAT RESULTS"
puts "===================="
puts "Variables: #{variables.size}"
puts "Clauses: #{clauses.size}"
puts "Satisfaction: #{satisfaction_rate}%"
puts "Runtime: #{(solve_time * 1000).round(1)} ms"
puts "Method: Graph partitioning (working 3SAT pattern)"

if satisfaction_rate == 100.0
  puts "🎉 PERFECT SAT SOLVING! Graph approach works!"
  puts "🚀 All constraints satisfied with graph partitioning!"
  puts "🔬 This demonstrates the framework's capability!"
elsif satisfaction_rate >= 90.0
  puts "👍 EXCELLENT! High satisfaction on complex SAT!"
  puts "🎯 Shows strong optimization capability!"
elsif satisfaction_rate >= 75.0
  puts "✅ VERY GOOD! Good satisfaction on complex logic!"
  puts "🔬 Solid performance on nested constraints!"
else
  puts "⚠️  CHALLENGING: Complex SAT with graph approach!"
  puts "💡 May need different parameters or approach"
end

puts "\n🎯 CONCLUSION: Testing the working SAT solving approach!"