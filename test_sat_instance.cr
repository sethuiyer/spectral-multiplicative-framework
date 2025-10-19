require "./src/multiplicative_constraint"

# Define complex SAT instance
clauses = [
  [1, 2, 3, 4],        # Clause 1
  [-1, 2, -3],         # Clause 2
  [1, -2, 4, -5],      # Clause 3
  [-1, -2, -3, 5],     # Clause 4
  [2, 3, 5],           # Clause 5
  [-4, -5],            # Clause 6
  [1, 4],              # Clause 7
  [-2, 3, -4, 5]       # Clause 8
]

puts "=== Testing Complex SAT Instance ==="
puts "Variables: 5"
puts "Clauses: #{clauses.size}"
puts "Clauses:"
clauses.each_with_index do |clause, i|
  clause_str = clause.map { |lit| lit > 0 ? "x#{lit}" : "¬x#{lit.abs}" }.join(" ∨ ")
  puts "  #{i+1}: #{clause_str}"
end
puts

# Create SAT solver
solver = MultiplicativeConstraint::SATSolver.new(
  num_variables: 5,
  clauses: clauses
)

puts "=== Casimir Force Diagnostic ==="
start_time = Time.monotonic
diagnostic = solver.diagnostic
diagnostic_time = Time.monotonic - start_time

puts "Predicted solvable: #{diagnostic.predicted_solvable}"
puts "Confidence: #{(diagnostic.confidence * 100).round(1)}%"
puts "Force variance: #{diagnostic.variance.round(6)}"
puts "Diagnostic runtime: #{(diagnostic.runtime * 1000).round(2)}ms"
puts "Recommendation: #{diagnostic.recommendation}"
puts

# Interpret diagnostic
if diagnostic.predicted_solvable
  puts "🔮 Diagnostic predicts SOLVABLE instance"
  puts "   High force variance suggests multiple satisfying assignments"
else
  puts "🔮 Diagnostic predicts UNSOLVABLE instance"
  puts "   Low force variance suggests constraint contradictions"
end
puts

# Solve with optimization
puts "=== SAT Solving with Optimization ==="
start_time = Time.monotonic
result = solver.solve(
  use_diagnostic: true,
  iterations: 3000
)
solve_time = Time.monotonic - start_time

puts "Solve time: #{(solve_time.total_milliseconds).round(2)}ms"
puts

puts "=== SAT Solution ==="
puts "Satisfiable: #{result.satisfiable ? "✅ YES" : "❌ NO"}"
puts "Satisfaction rate: #{(result.satisfaction_rate * 100).round(1)}%"
puts "Satisfied clauses: #{result.satisfied_clauses}/#{result.total_clauses}"
puts "Optimization energy: #{result.energy.round(6)}"

if result.assignment
  assignment_str = result.assignment.map_with_index do |value, i|
    "x#{i+1}=#{value ? "T" : "F"}"
  end.join(", ")
  puts "Assignment: #{assignment_str}"
end
puts

# Verify solution manually
puts "=== Manual Verification ==="
clauses.each_with_index do |clause, i|
  satisfied = clause.any? do |literal|
    variable = literal.abs
    value = result.assignment[variable - 1]
    literal > 0 ? value : !value
  end

  status = satisfied ? "✅" : "❌"
  clause_str = clause.map { |lit| lit > 0 ? "x#{lit}" : "¬x#{lit.abs}" }.join(" ∨ ")
  puts "#{status} Clause #{i+1}: #{clause_str}"
end
puts

# Performance analysis
puts "=== Performance Analysis ==="
puts "Diagnostic accuracy: #{diagnostic.predicted_solvable == result.satisfiable ? "✅ CORRECT" : "❌ INCORRECT"}"

if result.satisfiable
  puts "✅ Successfully found satisfying assignment"
  puts "   Time to solution: #{(diagnostic_time.total_milliseconds + solve_time.total_milliseconds).round(2)}ms total"
else
  if diagnostic.predicted_solvable == false
    puts "✅ Correctly identified unsolvable instance"
  else
    puts "⚠️  Diagnostic was wrong - instance appears unsolvable"
    puts "   Try more iterations or different parameters"
  end
end

# Energy components breakdown (if available)
puts "\n=== Energy Components Analysis ==="
puts "Final energy indicates:"
puts "  Lower energy = better constraint satisfaction"
puts "  Energy components:"
puts "    Spectral action: Captures global structure"
puts "    Balance terms: Ensures proper assignment distribution"
puts "    Penalty terms: Amplifies constraint violations"

puts "\n=== Test Summary ==="
puts "Variables: 5"
puts "Clauses: #{clauses.size}"
puts "Satisfiable: #{result.satisfiable ? "YES" : "NO"}"
puts "Satisfaction: #{(result.satisfaction_rate * 100).round(1)}%"
puts "Diagnostic correct: #{diagnostic.predicted_solvable == result.satisfiable ? "YES" : "NO"}"
puts "Total time: #{(diagnostic_time.total_milliseconds + solve_time.total_milliseconds).round(2)}ms"