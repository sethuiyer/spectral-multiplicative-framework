require "../../src/multiplicative_constraint"

puts "🧠 NESTED LOGIC TEST: EXTREME QUANTUM REASONING!"
puts "Testing deeply nested logical constraints with complex relationships"
puts "="*70

# Convert the complex nested logical formula to SAT clauses
# Variables: v1, v2, v3, v4, v5, v6, v7, v8, v9, v10

variables = 10
clauses = [] of Array(Int32)

puts "🔍 Converting nested logical formula to SAT clauses..."

# Original: ~((~v3 & ~v4) & (~v7 & ~v8))
# This means: NOT((NOT v3 AND NOT v4) AND (NOT v7 AND NOT v8))
# Simplifies to: (v3 OR v4) OR (v7 OR v8)
# Which gives us clauses: [3, 4] and [7, 8]
clauses << [3, 4]
clauses << [7, 8]

# Original: ~((~v3 & v4) & (~v7 & v8))
# Simplifies to: (v3 OR NOT v4) OR (v7 OR NOT v8)
clauses << [3, -4]
clauses << [7, -8]

# Original: ~((v3 & ~v4) & (v7 & ~v8))
# Simplifies to: (NOT v3 OR v4) OR (NOT v7 OR v8)
clauses << [-3, 4]
clauses << [-7, 8]

# Original: ~((~v7 & ~v8) & (~v3 & ~v4))
# Simplifies to: (v7 OR v8) OR (v3 OR v4)
clauses << [7, 8]
clauses << [3, 4]

# Original: ~((~v7 & v8) & (~v3 & v4))
# Simplifies to: (v7 OR NOT v8) OR (v3 OR NOT v4)
clauses << [7, -8]
clauses << [3, -4]

# Original: ~((v7 & ~v8) & (v3 & ~v4))
# Simplifies to: (NOT v7 OR v8) OR (NOT v3 OR v4)
clauses << [-7, 8]
clauses << [-3, 4]

# Original: ~((~v7 & v8) & (~v1 & ~v2))
# Simplifies to: (v7 OR NOT v8) OR (v1 OR v2)
clauses << [7, -8]
clauses << [1, 2]

# Original: ~((v7 & ~v8) & (v1 & v2))
# Simplifies to: (NOT v7 OR v8) OR (NOT v1 OR NOT v2)
clauses << [-7, 8]
clauses << [-1, -2]

# Original: ~((~v1 & ~v2) & (~v7 & ~v8))
# Simplifies to: (v1 OR v2) OR (v7 OR v8)
clauses << [1, 2]
clauses << [7, 8]

# Original: ~((~v1 & v2) & (~v5 & ~v6))
# Simplifies to: (v1 OR NOT v2) OR (v5 OR v6)
clauses << [1, -2]
clauses << [5, 6]

# Original: ~((~v1 & v2) & (v5 & v6))
# Simplifies to: (v1 OR NOT v2) OR (NOT v5 OR NOT v6)
clauses << [1, -2]
clauses << [-5, -6]

# Original: ~((v1 & ~v2) & (~v5 & ~v6))
# Simplifies to: (NOT v1 OR v2) OR (v5 OR v6)
clauses << [-1, 2]
clauses << [5, 6]

# Original: ~((v1 & v2) & (~v5 & v6))
# Simplifies to: (NOT v1 OR NOT v2) OR (v5 OR NOT v6)
clauses << [-1, -2]
clauses << [5, -6]

# Original: ~((v1 & v2) & (v9 & ~v10))
# Simplifies to: (NOT v1 OR NOT v2) OR (NOT v9 OR v10)
clauses << [-1, -2]
clauses << [-9, 10]

# Original: ~((~v9 & ~v10) & (~v1 & v2))
# Simplifies to: (v9 OR v10) OR (v1 OR NOT v2)
clauses << [9, 10]
clauses << [1, -2]

# Original: ~((~v9 & v10) & (~v1 & v2))
# Simplifies to: (v9 OR NOT v10) OR (v1 OR NOT v2)
clauses << [9, -10]
clauses << [1, -2]

# Original: ~((v9 & ~v10) & (v1 & v2))
# Simplifies to: (NOT v9 OR v10) OR (NOT v1 OR NOT v2)
clauses << [-9, 10]
clauses << [-1, -2]

# Now the complex OR constraints at the end:
# (((~v1 & ~v2) | (v1 & ~v2) | (~v1 & v2)) &
# This is essentially: NOT(v1 AND v2) - i.e., at least one of v1, v2 is false
clauses << [-1, -2]

# ((~v3 & ~v4) | (v3 & ~v4) | (~v3 & v4) | (v3 & v4)) &
# This is always true (all possible combinations), no constraint needed

# ((~v5 & ~v6) | (v5 & ~v6) | (~v5 & v6) | (v5 & v6)) &
# This is always true (all possible combinations), no constraint needed

# ((~v7 & ~v8) | (v7 & ~v8) | (~v7 & v8) | (v7 & v8)) &
# This is always true (all possible combinations), no constraint needed

# ((~v9 & ~v10) | (~v9 & v10) | (v9 & ~v10) | (v9 & v10))
# This is always true (all possible combinations), no constraint needed

# Remove duplicates and finalize clauses
clauses = clauses.uniq

puts "\n📊 NESTED LOGIC SAT PROBLEM:"
puts "Variables: #{variables}"
puts "Clauses: #{clauses.size}"
puts "Complexity: High - Nested negations and complex logical structure"

# Show the clauses
clauses.each_with_index do |clause, idx|
  clause_str = clause.map { |l| l > 0 ? "v#{l}" : "¬v#{-l}" }.join(" ∨ ")
  puts "Clause #{idx + 1}: #{clause_str}"
end

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

puts "\n🔗 Building quantum constraint network with #{total_nodes} nodes..."

# Add constraint weights
clauses.each_with_index do |clause, clause_idx|
  clause.each do |literal1|
    clause.each do |literal2|
      next if literal1 == literal2

      node1 = literal_to_node[literal1]
      node2 = literal_to_node[literal2]

      # Strong negative weight for literals in same clause
      adjacency[node1][node2] = -20.0
      adjacency[node2][node1] = -20.0
    end
  end
end

# Add some positive correlations for related variables
(1..variables).each do |i|
  if i < variables
    pos_i = literal_to_node[i]?
    pos_ip1 = literal_to_node[i+1]?
    neg_i = literal_to_node[-i]?
    neg_ip1 = literal_to_node[-(i+1)]?

    if pos_i && pos_ip1
      adjacency[pos_i][pos_ip1] = 2.0
      adjacency[pos_ip1][pos_i] = 2.0
    end
    if neg_i && neg_ip1
      adjacency[neg_i][neg_ip1] = 2.0
      adjacency[neg_ip1][neg_i] = 2.0
    end
  end
end

puts "\n🚀 Launching NESTED LOGIC quantum solver..."
puts "Total nodes: #{total_nodes}"
puts "Constraint complexity: High - Nested logical structure"

# Run quantum solver
start_time = Time.utc

graph = MultiplicativeConstraint::Graph.new(weights, adjacency)
engine = MultiplicativeConstraint::Engine.new(graph, 3)
result = engine.solve(iterations: 3000, seed: 555)

solve_time = (Time.utc - start_time).total_seconds

puts "\n⚡ NESTED LOGIC PERFORMANCE RESULTS"
puts "===================================="
puts "Runtime: #{(solve_time * 1000).round(1)} ms"
puts "Segments: #{result.segments.size}"
puts "Final Energy: #{result.energy.round(3)}"
puts "Spectral Action: #{result.spectral.round(3)}"

# Interpret segments as SAT assignment
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

    var_name = is_positive ? "v#{var}" : "¬v#{var}"
    value = assignment[var]? ? assignment[var] : false
    puts "  #{var_name} = #{value ? "TRUE" : "FALSE"}"
  end
end

# Evaluate SAT satisfaction
puts "\n🔍 NESTED LOGIC SATISFIABILITY ANALYSIS"
puts "========================================="
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

  clause_str = clause.map { |l| l > 0 ? "v#{l}" : "¬v#{-l}" }.join(" ∨ ")
  puts "Clause #{clause_idx + 1}: #{clause_str} - #{clause_satisfied ? "✅ SATISFIED" : "❌ VIOLATED"}"
end

satisfaction_rate = (satisfied_clauses.to_f64 / clauses.size * 100).round(1)

puts "\n📊 SATISFACTION SUMMARY:"
puts "Clauses satisfied: #{satisfied_clauses}/#{clauses.size}"
puts "Satisfaction rate: #{satisfaction_rate}%"

# Show the final assignment
puts "\n✅ FINAL NESTED LOGIC ASSIGNMENT:"
(1..variables).each do |var|
  value = assignment[var]? ? assignment[var] : false
  puts "  v#{var.to_s.rjust(2)} = #{value ? "TRUE" : "FALSE"}"
end

# Verify the original nested logic structure
puts "\n🧠 VERIFYING ORIGINAL NESTED LOGIC:"

# Check key constraints from the original formula
puts "\nChecking original constraints:"

# ~((~v3 & ~v4) & (~v7 & ~v8)) should be satisfied
original1 = !((!assignment[3]? && !assignment[4]?) && (!assignment[7]? && !assignment[8]?))
puts "~((~v3 & ~v4) & (~v7 & ~v8)): #{original1 ? "✅" : "❌"}"

# ~((v1 & v2) & (v9 & ~v10)) should be satisfied
original2 = !((assignment[1]? && assignment[2]?) && (assignment[9]? && !assignment[10]?))
puts "~((v1 & v2) & (v9 & ~v10)): #{original2 ? "✅" : "❌"}"

# ((~v1 & ~v2) | (v1 & ~v2) | (~v1 & v2)) should be satisfied
original3 = (!assignment[1]? && !assignment[2]?) || (assignment[1]? && !assignment[2]?) || (!assignment[1]? && assignment[2]?)
puts "((~v1 & ~v2) | (v1 & ~v2) | (~v1 & v2)): #{original3 ? "✅" : "❌"}"

# Quality assessment
puts "\n🏆 NESTED LOGIC RESULTS"
puts "========================"
puts "Variables: #{variables}"
puts "Clauses: #{clauses.size}"
puts "Satisfaction: #{satisfaction_rate}%"
puts "Runtime: #{(solve_time * 1000).round(1)} ms"
puts "Constraint complexity: High - Nested logical structure"

if satisfaction_rate == 100.0
  puts "🎉 PERFECT! Quantum reasoning solved complex nested logic!"
  puts "🚀 Handles deeply nested logical constraints!"
  puts "🔬 Quantum methods master complex boolean logic!"
elsif satisfaction_rate >= 90.0
  puts "👍 EXCELLENT! High satisfaction on complex nested logic!"
  puts "🎯 Shows powerful reasoning capabilities!"
elsif satisfaction_rate >= 75.0
  puts "✅ VERY GOOD! Handles complex logical structure well!"
  puts "🔬 Strong performance on nested constraints"
else
  puts "⚠️  CHALLENGING: Complex nested logic is difficult!"
  puts "💡 May need more iterations or different approach"
end

puts "\n🎯 CONCLUSION: Testing quantum reasoning on complex logical formulas!"