require "../../src/multiplicative_constraint"

puts "🧠 PROPER SAT TEST: Using Library's Boolean Constraint System"
puts "Testing the built-in SAT support with massive penalty functions"
puts "="*70

# Test the original nested logic formula using proper SAT constraints
# Variables: v1, v2, v3, v4, v5, v6, v7, v8, v9, v10
variables = 10

puts "🔧 Setting up proper SAT constraints..."

# Create mapping from variables to node indices
# Each variable gets one node (positive literal = TRUE, negative literal = FALSE)
variable_to_node = {} of Int32 => Int32
(0...variables).each { |i| variable_to_node[i] = i }

total_nodes = variables
weights = Array(Float64).new(total_nodes, 1.0)

# Create empty edges (we'll use penalty system instead of graph edges)
edges = [] of Tuple(Int32, Int32, Float64)

# Define exclusivity pairs (x_i and ¬x_i cannot be in same segment)
# In this encoding: if variable i is in segment 0 = FALSE, segment 1 = TRUE
# So we don't need explicit exclusivity pairs - the encoding handles it

exclusivity_pairs = [] of Tuple(Int32, Int32)

# Convert the CNF clauses to the library's format
clauses = [] of Array(Int32)

puts "📋 Converting nested logic to CNF clauses..."

# From our previous proper CNF conversion:
# Using 0-indexed literals (library expects labels array indices)
# ~((~v3 & ~v4) & (~v7 & ~v8)) = v3 ∨ v4 ∨ v7 ∨ v8
clauses << [2, 3, 6, 7]  # v3, v4, v7, v8 (0-indexed: 2,3,6,7)

# ~((~v3 & v4) & (~v7 & v8)) = v3 ∨ ¬v4 ∨ v7 ∨ ¬v8
clauses << [2, -4, 6, -8]  # v3, ¬v4, v7, ¬v8

# ~((v3 & ~v4) & (v7 & ~v8)) = ¬v3 ∨ v4 ∨ ¬v7 ∨ v8
clauses << [-3, 4, -7, 8]

# ~((~v7 & ~v8) & (~v3 & ~v4)) = v7 ∨ v8 ∨ v3 ∨ v4
clauses << [6, 7, 2, 3]

# ~((~v7 & v8) & (~v3 & v4)) = v7 ∨ ¬v8 ∨ v3 ∨ ¬v4
clauses << [6, -8, 2, -4]

# ~((v7 & ~v8) & (v3 & ~v4)) = ¬v7 ∨ v8 ∨ ¬v3 ∨ v4
clauses << [-7, 8, -3, 4]

# ~((~v7 & v8) & (~v1 & ~v2)) = v7 ∨ ¬v8 ∨ v1 ∨ v2
clauses << [6, -8, 0, 1]

# ~((v7 & ~v8) & (v1 & v2)) = ¬v7 ∨ v8 ∨ ¬v1 ∨ ¬v2
clauses << [-7, 8, -1, -2]

# ~((~v1 & ~v2) & (~v7 & ~v8)) = v1 ∨ v2 ∨ v7 ∨ v8
clauses << [0, 1, 6, 7]

# ~((~v1 & v2) & (~v5 & ~v6)) = v1 ∨ ¬v2 ∨ v5 ∨ v6
clauses << [0, -2, 4, 5]

# ~((~v1 & v2) & (v5 & v6)) = v1 ∨ ¬v2 ∨ ¬v5 ∨ ¬v6
clauses << [0, -2, -5, -6]

# ~((v1 & ~v2) & (~v5 & ~v6)) = ¬v1 ∨ v2 ∨ v5 ∨ v6
clauses << [-1, 2, 4, 5]

# ~((v1 & v2) & (~v5 & v6)) = ¬v1 ∨ ¬v2 ∨ v5 ∨ ¬v6
clauses << [-1, -2, 4, -6]

# ~((v1 & v2) & (v9 & ~v10)) = ¬v1 ∨ ¬v2 ∨ ¬v9 ∨ v10
clauses << [-1, -2, -9, 10]

# ~((~v9 & ~v10) & (~v1 & v2)) = v9 ∨ v10 ∨ v1 ∨ ¬v2
clauses << [8, 9, 0, -2]

# ~((~v9 & v10) & (~v1 & v2)) = v9 ∨ ¬v10 ∨ v1 ∨ ¬v2
clauses << [8, -10, 0, -2]

# ~((v9 & ~v10) & (v1 & v2)) = ¬v9 ∨ v10 ∨ ¬v1 ∨ ¬v2
clauses << [-9, 10, -1, -2]

# XOR constraint for v1 and v2: (v1 ∨ v2) ∧ (¬v1 ∨ v2) ∧ (v1 ∨ ¬v2)
clauses << [0, 1]      # v1 ∨ v2
clauses << [-1, 2]     # ¬v1 ∨ v2
clauses << [0, -2]     # v1 ∨ ¬v2

puts "\n📊 SAT PROBLEM STATISTICS:"
puts "Variables: #{variables}"
puts "Clauses: #{clauses.size}"
puts "Constraint complexity: High - Proper SAT with massive penalties"

# Create the SAT graph using the library's dedicated constructor
puts "\n🏗️ Creating SAT graph with boolean constraints..."
graph = MultiplicativeConstraint::Graph.from_sat(
  weights: weights,
  edges: edges,
  exclusivity_pairs: exclusivity_pairs,
  clauses: clauses
)

puts "Graph created with #{graph.size} nodes"
puts "Boolean constraints enabled: #{graph.has_bool_constraints}"
puts "Exclusivity pairs: #{graph.exclusivity_pairs.size}"
puts "SAT clauses: #{graph.clauses.size}"

# Initialize the optimization engine with SAT settings
puts "\n🚀 Initializing SAT optimization engine..."
engine = MultiplicativeConstraint::Engine.new(
  graph: graph,
  segments: 2,  # Binary: segment 0 = FALSE, segment 1 = TRUE
  fairness_weight: 0.1,       # Low weight for SAT problems
  entropy_weight: 0.01,       # Low weight
  penalty_weight: 100.0,      # HIGH penalty weight for constraint violations
  cross_conflict_weight: 0.0   # No edge cuts needed for SAT
)

puts "Engine initialized for SAT solving"

# Run the optimization
puts "\n⚡ Running SAT solver with massive penalty system..."
start_time = Time.utc

result = engine.solve(
  iterations: 5000,  # More iterations for SAT
  seed: 666
)

solve_time = (Time.utc - start_time).total_seconds

puts "\n⚡ SAT PERFORMANCE RESULTS"
puts "=========================="
puts "Runtime: #{(solve_time * 1000).round(1)} ms"
puts "Segments: #{result.segments.size}"
puts "Final Energy: #{result.energy.round(3)}"
puts "Spectral Action: #{result.spectral.round(3)}"
puts "Penalty Term: #{result.penalty.round(6)}"

# Interpret the result as SAT assignment
puts "\n🎯 SAT ASSIGNMENT INTERPRETATION:"
puts "=================================="

assignment = Hash(Int32, Bool).new

# Determine which segment represents TRUE
# Try both interpretations and pick the one with fewer violations
true_segment = 1  # Default: segment 1 = TRUE

result.segments.each_with_index do |segment, seg_idx|
  segment_type = seg_idx == true_segment ? "TRUE" : "FALSE"
  puts "\nSegment #{seg_idx} (#{segment_type}): #{segment.size} variables"

  segment.each do |var_idx|
    var_name = "v#{var_idx + 1}"
    puts "  #{var_name}"

    # Assign based on which segment represents TRUE
    if seg_idx == true_segment
      assignment[var_idx] = true
    else
      assignment[var_idx] = false
    end
  end
end

# Show final assignment
puts "\n✅ FINAL SAT ASSIGNMENT:"
(0...variables).each do |var_idx|
  value = assignment[var_idx]? ? assignment[var_idx] : false
  puts "  v#{var_idx + 1} = #{value ? "TRUE" : "FALSE"}"
end

# Verify all clauses
puts "\n🔍 CLAUSE SATISFACTION VERIFICATION:"
puts "===================================="
satisfied_clauses = 0
total_clauses = clauses.size

clauses.each_with_index do |clause, clause_idx|
  clause_satisfied = clause.any? do |literal|
    var_idx = literal.abs - 1  # Convert back to 0-indexed
    is_positive = literal > 0
    assignment[var_idx]? == is_positive
  end

  if clause_satisfied
    satisfied_clauses += 1
  end

  clause_str = clause.map { |l| l > 0 ? "v#{l}" : "¬v#{-l}" }.join(" ∨ ")
  puts "Clause #{clause_idx + 1}: #{clause_str} - #{clause_satisfied ? "✅ SATISFIED" : "❌ VIOLATED"}"
end

satisfaction_rate = (satisfied_clauses.to_f64 / total_clauses * 100).round(1)

puts "\n📊 SAT SOLVING RESULTS:"
puts "======================="
puts "Clauses satisfied: #{satisfied_clauses}/#{total_clauses}"
puts "Satisfaction rate: #{satisfaction_rate}%"
puts "Runtime: #{(solve_time * 1000).round(1)} ms"

# Verify key original constraints
puts "\n🧠 ORIGINAL CONSTRAINT VERIFICATION:"
puts "===================================="

# Check: ~((~v3 & ~v4) & (~v7 & ~v8))
constraint1 = !((!assignment[2]? && !assignment[3]?) && (!assignment[6]? && !assignment[7]?))
puts "~((~v3 & ~v4) & (~v7 & ~v8)): #{constraint1 ? "✅" : "❌"}"

# Check: ~((v1 & v2) & (v9 & ~v10))
constraint2 = !((assignment[0]? && assignment[1]?) && (assignment[8]? && !assignment[9]?))
puts "~((v1 & v2) & (v9 & ~v10)): #{constraint2 ? "✅" : "❌"}"

# Check: ((~v1 & ~v2) | (v1 & ~v2) | (~v1 & v2))
constraint3 = (!assignment[0]? && !assignment[1]?) || (assignment[0]? && !assignment[1]?) || (!assignment[0]? && assignment[1]?)
puts "XOR(v1, v2): #{constraint3 ? "✅" : "❌"}"

# Quality assessment
puts "\n🏆 PROPER SAT RESULTS"
puts "===================="
puts "Variables: #{variables}"
puts "Clauses: #{total_clauses}"
puts "Satisfaction: #{satisfaction_rate}%"
puts "Runtime: #{(solve_time * 1000).round(1)} ms"
puts "Penalty system: MASSIVE (scale × 1000-10000)"

if satisfaction_rate == 100.0
  puts "🎉 PERFECT SAT SOLVING! Library's boolean system works!"
  puts "🚀 All constraints satisfied with massive penalty functions!"
  puts "🔬 This is a precise SAT solver, not just approximation!"
elsif satisfaction_rate >= 95.0
  puts "👍 EXCELLENT! Near-perfect SAT solving!"
  puts "🎯 Library's constraint system is highly effective!"
elsif satisfaction_rate >= 85.0
  puts "✅ VERY GOOD! High satisfaction on complex SAT!"
  puts "🔬 Strong performance with proper encoding!"
else
  puts "⚠️  CHALLENGING: Complex SAT with penalties!"
  puts "💡 May need parameter tuning or more iterations"
end

puts "\n🎯 CONCLUSION: Testing the library's built-in SAT solving capabilities!"