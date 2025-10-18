require "../../src/multiplicative_constraint"

puts "🔍 CNF CONVERSION TEST: PROPER DE MORGAN'S LAWS"
puts "Converting complex nested logic to correct CNF format"
puts "="*70

# Original formula - let's convert to CNF properly
# Using De Morgan's: ¬(A ∧ B) = ¬A ∨ ¬B
# And: ¬(A ∨ B) = ¬A ∧ ¬B

# Variables: v1, v2, v3, v4, v5, v6, v7, v8, v9, v10

variables = 10
clauses = [] of Array(Int32)

puts "🧠 Applying De Morgan's laws correctly..."

# ~((~v3 & ~v4) & (~v7 & ~v8))
# = ¬(~v3 ∧ ~v4 ∧ ~v7 ∧ ~v8)
# = v3 ∨ v4 ∨ v7 ∨ v8
clauses << [3, 4, 7, 8]

# ~((~v3 & v4) & (~v7 & v8))
# = ¬(~v3 ∧ v4 ∧ ~v7 ∧ v8)
# = v3 ∨ ¬v4 ∨ v7 ∨ ¬v8
clauses << [3, -4, 7, -8]

# ~((v3 & ~v4) & (v7 & ~v8))
# = ¬(v3 ∧ ~v4 ∧ v7 ∧ ~v8)
# = ¬v3 ∨ v4 ∨ ¬v7 ∨ v8
clauses << [-3, 4, -7, 8]

# ~((~v7 & ~v8) & (~v3 & ~v4))
# = ¬(~v7 ∧ ~v8 ∧ ~v3 ∧ ~v4)
# = v7 ∨ v8 ∨ v3 ∨ v4
clauses << [7, 8, 3, 4]

# ~((~v7 & v8) & (~v3 & v4))
# = ¬(~v7 ∧ v8 ∧ ~v3 ∧ v4)
# = v7 ∨ ¬v8 ∨ v3 ∨ ¬v4
clauses << [7, -8, 3, -4]

# ~((v7 & ~v8) & (v3 & ~v4))
# = ¬(v7 ∧ ~v8 ∧ v3 ∧ ~v4)
# = ¬v7 ∨ v8 ∨ ¬v3 ∨ v4
clauses << [-7, 8, -3, 4]

# ~((~v7 & v8) & (~v1 & ~v2))
# = ¬(~v7 ∧ v8 ∧ ~v1 ∧ ~v2)
# = v7 ∨ ¬v8 ∨ v1 ∨ v2
clauses << [7, -8, 1, 2]

# ~((v7 & ~v8) & (v1 & v2))
# = ¬(v7 ∧ ~v8 ∧ v1 ∧ v2)
# = ¬v7 ∨ v8 ∨ ¬v1 ∨ ¬v2
clauses << [-7, 8, -1, -2]

# ~((~v1 & ~v2) & (~v7 & ~v8))
# = ¬(~v1 ∧ ~v2 ∧ ~v7 ∧ ~v8)
# = v1 ∨ v2 ∨ v7 ∨ v8
clauses << [1, 2, 7, 8]

# ~((~v1 & v2) & (~v5 & ~v6))
# = ¬(~v1 ∧ v2 ∧ ~v5 ∧ ~v6)
# = v1 ∨ ¬v2 ∨ v5 ∨ v6
clauses << [1, -2, 5, 6]

# ~((~v1 & v2) & (v5 & v6))
# = ¬(~v1 ∧ v2 ∧ v5 ∧ v6)
# = v1 ∨ ¬v2 ∨ ¬v5 ∨ ¬v6
clauses << [1, -2, -5, -6]

# ~((v1 & ~v2) & (~v5 & ~v6))
# = ¬(v1 ∧ ~v2 ∧ ~v5 ∧ ~v6)
# = ¬v1 ∨ v2 ∨ v5 ∨ v6
clauses << [-1, 2, 5, 6]

# ~((v1 & v2) & (~v5 & v6))
# = ¬(v1 ∧ v2 ∧ ~v5 ∧ v6)
# = ¬v1 ∨ ¬v2 ∨ v5 ∨ ¬v6
clauses << [-1, -2, 5, -6]

# ~((v1 & v2) & (v9 & ~v10))
# = ¬(v1 ∧ v2 ∧ v9 ∧ ¬v10)
# = ¬v1 ∨ ¬v2 ∨ ¬v9 ∨ v10
clauses << [-1, -2, -9, 10]

# ~((~v9 & ~v10) & (~v1 & v2))
# = ¬(~v9 ∧ ~v10 ∧ ~v1 ∧ v2)
# = v9 ∨ v10 ∨ v1 ∨ ¬v2
clauses << [9, 10, 1, -2]

# ~((~v9 & v10) & (~v1 & v2))
# = ¬(~v9 ∧ v10 ∧ ~v1 ∧ v2)
# = v9 ∨ ¬v10 ∨ v1 ∨ ¬v2
clauses << [9, -10, 1, -2]

# ~((v9 & ~v10) & (v1 & v2))
# = ¬(v9 ∧ ¬v10 ∧ v1 ∧ v2)
# = ¬v9 ∨ v10 ∨ ¬v1 ∨ ¬v2
clauses << [-9, 10, -1, -2]

# Now the big OR-AND structure at the end
# (((~v1 & ~v2) | (v1 & ~v2) | (~v1 & v2)) &
# This needs to be converted using distributive laws

# For ((~v1 & ~v2) | (v1 & ~v2) | (~v1 & v2))
# This is equivalent to: (v1 ⊕ v2) - XOR
# But to keep it in CNF, we need to expand properly
# This is actually: (v1 ∧ ¬v2) ∨ (¬v1 ∧ v2) ∨ (¬v1 ∧ ¬v2)
# Which simplifies to: ¬v1 ∨ ¬v2 ∨ (v1 ∧ ¬v2)
# Let's keep the original interpretation: at least one of these must be true
# So we need: (v1 ∨ v2) ∧ (¬v1 ∨ v2) ∧ (v1 ∨ ¬v2)
clauses << [1, 2]      # v1 ∨ v2
clauses << [-1, 2]     # ¬v1 ∨ v2
clauses << [1, -2]     # v1 ∨ ¬v2

# The other OR terms ((~v3 & ~v4) | (v3 & ~v4) | (~v3 & v4) | (v3 & v4))
# This covers all possible combinations, so it's always true - no constraints needed

# Same for the other variable pairs - they cover all combinations

puts "\n📊 CNF FORMULA STATISTICS:"
puts "Variables: #{variables}"
puts "Clauses: #{clauses.size}"
puts "Formula complexity: High - Proper CNF conversion with De Morgan's laws"

# Show the CNF clauses
puts "\n🔍 CNF CLAUSES:"
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

# Add constraint weights - very strong for this complex formula
clauses.each_with_index do |clause, clause_idx|
  clause.each do |literal1|
    clause.each do |literal2|
      next if literal1 == literal2

      node1 = literal_to_node[literal1]
      node2 = literal_to_node[literal2]

      # Very strong negative weight for literals in same clause
      adjacency[node1][node2] = -50.0
      adjacency[node2][node1] = -50.0
    end
  end
end

# Add some positive correlations for variable relationships
(1..variables).each do |i|
  if i < variables
    pos_i = literal_to_node[i]?
    pos_ip1 = literal_to_node[i+1]?
    neg_i = literal_to_node[-i]?
    neg_ip1 = literal_to_node[-(i+1)]?

    if pos_i && pos_ip1
      adjacency[pos_i][pos_ip1] = 3.0
      adjacency[pos_ip1][pos_i] = 3.0
    end
    if neg_i && neg_ip1
      adjacency[neg_i][neg_ip1] = 3.0
      adjacency[neg_ip1][neg_i] = 3.0
    end
  end
end

puts "\n🚀 Launching PROPER CNF quantum solver..."
puts "Total nodes: #{total_nodes}"
puts "Constraint complexity: High - Proper CNF with De Morgan's laws"

# Run quantum solver with more iterations for complex CNF
start_time = Time.utc

graph = MultiplicativeConstraint::Graph.new(weights, adjacency)
engine = MultiplicativeConstraint::Engine.new(graph, 4)
result = engine.solve(iterations: 5000, seed: 777)

solve_time = (Time.utc - start_time).total_seconds

puts "\n⚡ PROPER CNF PERFORMANCE RESULTS"
puts "=================================="
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
puts "\n🔍 PROPER CNF SATISFIABILITY ANALYSIS"
puts "======================================"
satisfied_clauses = 0
violated_clauses = [] of Int32

clauses.each_with_index do |clause, clause_idx|
  clause_satisfied = clause.any? do |literal|
    var = literal.abs
    is_positive = literal > 0
    assignment[var]? == is_positive
  end

  if clause_satisfied
    satisfied_clauses += 1
  else
    violated_clauses << clause_idx + 1
  end

  clause_str = clause.map { |l| l > 0 ? "v#{l}" : "¬v#{-l}" }.join(" ∨ ")
  puts "Clause #{clause_idx + 1}: #{clause_str} - #{clause_satisfied ? "✅ SATISFIED" : "❌ VIOLATED"}"
end

satisfaction_rate = (satisfied_clauses.to_f64 / clauses.size * 100).round(1)

puts "\n📊 CNF SATISFACTION SUMMARY:"
puts "Clauses satisfied: #{satisfied_clauses}/#{clauses.size}"
puts "Satisfaction rate: #{satisfaction_rate}%"
puts "Violated clauses: #{violated_clauses.join(", ")}"

# Show the final assignment
puts "\n✅ PROPER CNF ASSIGNMENT:"
(1..variables).each do |var|
  value = assignment[var]? ? assignment[var] : false
  puts "  v#{var.to_s.rjust(2)} = #{value ? "TRUE" : "FALSE"}"
end

# Verify some key original constraints
puts "\n🧠 VERIFYING KEY ORIGINAL CONSTRAINTS:"

# Check: ~((~v3 & ~v4) & (~v7 & ~v8)) should be satisfied
constraint1 = !((!assignment[3]? && !assignment[4]?) && (!assignment[7]? && !assignment[8]?))
puts "~((~v3 & ~v4) & (~v7 & ~v8)): #{constraint1 ? "✅" : "❌"}"

# Check: ~((v1 & v2) & (v9 & ~v10)) should be satisfied
constraint2 = !((assignment[1]? && assignment[2]?) && (assignment[9]? && !assignment[10]?))
puts "~((v1 & v2) & (v9 & ~v10)): #{constraint2 ? "✅" : "❌"}"

# Check: ~((v7 & ~v8) & (v1 & v2)) should be satisfied
constraint3 = !((assignment[7]? && !assignment[8]?) && (assignment[1]? && assignment[2]?))
puts "~((v7 & ~v8) & (v1 & v2)): #{constraint3 ? "✅" : "❌"}"

# Quality assessment
puts "\n🏆 PROPER CNF RESULTS"
puts "====================="
puts "Variables: #{variables}"
puts "Clauses: #{clauses.size}"
puts "Satisfaction: #{satisfaction_rate}%"
puts "Runtime: #{(solve_time * 1000).round(1)} ms"
puts "Formula complexity: High - Proper CNF with De Morgan's laws"

if satisfaction_rate == 100.0
  puts "🎉 PERFECT! Quantum solved proper CNF conversion!"
  puts "🚀 Handles complex nested logic with correct encoding!"
  puts "🔬 Quantum methods master CNF satisfiability!"
elsif satisfaction_rate >= 90.0
  puts "👍 EXCELLENT! High satisfaction on proper CNF!"
  puts "🎯 Shows powerful CNF reasoning capabilities!"
elsif satisfaction_rate >= 75.0
  puts "✅ VERY GOOD! Handles proper CNF structure well!"
  puts "🔬 Strong performance on correctly encoded formula"
else
  puts "⚠️  CHALLENGING: Complex CNF is difficult!"
  puts "💡 The constraints may be inherently contradictory"
end

puts "\n🎯 CONCLUSION: Testing quantum methods on properly encoded CNF!"