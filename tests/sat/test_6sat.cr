require "../../src/multiplicative_constraint"

puts "🧮 6-SAT TEST: QUANTUM PHYSICS VS 6-LITERAL SAT"
puts "Testing quantum methods on 6-SAT (much harder than 3-SAT!)"
puts "="*60

# 6-SAT problem: Each clause has exactly 6 literals
# Variables: x1, x2, x3, x4, x5, x6, x7, x8, x9, x10

# Create a challenging 6-SAT instance
clauses = [
  # Clause 1: (x1 ∨ ¬x2 ∨ x3 ∨ ¬x4 ∨ x5 ∨ ¬x6)
  [1, -2, 3, -4, 5, -6],

  # Clause 2: (¬x1 ∨ x2 ∨ ¬x3 ∨ x4 ∨ ¬x5 ∨ x6)
  [-1, 2, -3, 4, -5, 6],

  # Clause 3: (x1 ∨ x2 ∨ ¬x3 ∨ ¬x4 ∨ x5 ∨ ¬x6)
  [1, 2, -3, -4, 5, -6],

  # Clause 4: (¬x1 ∨ ¬x2 ∨ x3 ∨ x4 ∨ ¬x5 ∨ ¬x6)
  [-1, -2, 3, 4, -5, 6],

  # Clause 5: (x1 ∨ ¬x2 ∨ x3 ∨ x4 ∨ ¬x5 ∨ x6)
  [1, -2, 3, 4, -5, 6],

  # Clause 6: (¬x1 ∨ x2 ∨ ¬x3 ∨ ¬x4 ∨ x5 ∨ x6)
  [-1, 2, -3, -4, 5, 6],

  # Clause 7: (x1 ∨ x2 ∨ x3 ∨ ¬x4 ∨ ¬x5 ∨ ¬x6)
  [1, 2, 3, -4, -5, -6],

  # Clause 8: (¬x1 ∨ ¬x2 ∨ ¬x3 ∨ x4 ∨ x5 ∨ ¬x6)
  [-1, -2, -3, 4, 5, -6],

  # Clause 9: (x1 ∨ ¬x2 ∨ x3 ∨ x4 ∨ x5 ∨ ¬x6)
  [1, -2, 3, -4, 5, 6],

  # Clause 10: (¬x1 ∨ x2 ∨ ¬x3 ∨ x4 ∨ ¬x5 ∨ x6)
  [-1, 2, -3, 4, -5, 6]
]

variables = 10
clauses_count = clauses.size
literals_per_clause = 6

puts "Variables: #{variables}"
puts "Clauses: #{clauses_count}"
puts "Literals per clause: #{literals_per_clause}"
puts "Total literals: #{variables * 2 * clauses_count}"
puts "Challenge: Find assignment satisfying all 10 clauses!"

# Map literals to graph nodes (positive and negative versions)
literal_to_node = {} of Int32 => Int32
node_to_literal = {} of Int32 => Int32

node_index = 0
(1..variables).each do |var|
  # Positive literal
  literal_to_node[var] = node_index
  node_to_literal[node_index] = var
  node_index += 1

  # Negative literal
  literal_to_node[-var] = node_index
  node_to_literal[node_index] = -var
  node_index += 1
end

total_nodes = variables * 2  # Positive and negative versions
weights = Array(Float64).new(total_nodes, 1.0)
adjacency = Array(Array(Float64)).new(total_nodes) { Array(Float64).new(total_nodes, 0.0) }

# Create constraints: literals that cannot be in same segment
clauses.each_with_index do |clause, clause_idx|
  puts "\nClause #{clause_idx + 1}: #{clause.map { |l| l > 0 ? "x#{l}" : "¬x#{-l}" }.join(" ∨ ")}"

  clause.each do |literal1|
    clause.each do |literal2|
      next if literal1 == literal2

      node1 = literal_to_node[literal1]
      node2 = literal_to_node[literal2]

      # Strong negative weight for literals in same clause (they cannot be both true)
      adjacency[node1][node2] = -10.0
      adjacency[node2][node1] = -10.0
    end
  end
end

# Add some positive weights for related variables (heuristic)
(1..variables).each do |i|
  if i < variables
    # Slight positive correlation between consecutive variables
    pos_i = literal_to_node[i]
    pos_ip1 = literal_to_node[i+1]
    neg_i = literal_to_node[-i]
    neg_ip1 = literal_to_node[-(i+1)]

    adjacency[pos_i][pos_ip1] = 1.0
    adjacency[pos_ip1][pos_i] = 1.0
    adjacency[neg_i][neg_ip1] = 1.0
    adjacency[neg_ip1][neg_i] = 1.0
  end
end

puts "\n🚀 Creating quantum SAT solver..."
puts "Total nodes: #{total_nodes}"
puts "Constraint density: #{clauses_count * literals_per_clause * (literals_per_clause - 1) / 2} negative edges"

# Run quantum solver
start_time = Time.utc

graph = MultiplicativeConstraint::Graph.new(weights, adjacency)
engine = MultiplicativeConstraint::Engine.new(graph, 3)
result = engine.solve(iterations: 2000, seed: 456)

solve_time = (Time.utc - start_time).total_seconds

puts "⚡ PERFORMANCE"
puts "---------------------"
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

    var_name = is_positive ? "x#{var}" : "¬x#{var}"
    puts "  #{var_name} (#{is_positive ? "TRUE" : "FALSE"})"
  end
end

# Evaluate SAT satisfaction
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

satisfaction_rate = (satisfied_clauses.to_f64 / clauses_count * 100).round(1)

puts "\n🔍 SATISFIABILITY ANALYSIS"
puts "----------------------------"
puts "Clauses satisfied: #{satisfied_clauses}/#{clauses_count}"
puts "Satisfaction rate: #{satisfaction_rate}%"

# Show the assignment
puts "\n✅ FINAL ASSIGNMENT:"
(1..variables).each do |var|
  value = assignment[var]? ? assignment[var] : false
  puts "  x#{var} = #{value ? "TRUE" : "FALSE"}"
end

# Quality assessment
puts "\n🏆 6-SAT RESULTS"
puts "=================="
puts "Variables: #{variables}"
puts "Clauses: #{clauses_count}"
puts "Satisfaction: #{satisfaction_rate}%"
puts "Runtime: #{(solve_time * 1000).round(1)} ms"

if satisfaction_rate == 100.0
  puts "🎉 PERFECT SATISFACTION! Quantum physics solved 6-SAT!"
  puts "🚀 This is harder than 3-SAT - quantum methods scale!"
elsif satisfaction_rate >= 80.0
  puts "👍 EXCELLENT! High satisfaction on complex 6-SAT problem"
  puts "🔬 Quantum methods handle complexity well"
elsif satisfaction_rate >= 60.0
  puts "✅ GOOD! Quantum methods found partial solution"
  puts "🎯 Shows promise for harder SAT problems"
else
  puts "⚠️  CHALLENGING: 6-SAT is very difficult"
  puts "💡 May need more iterations or different parameters"
end

puts "\n🎯 CONCLUSION: Testing quantum physics on advanced Boolean satisfiability!"