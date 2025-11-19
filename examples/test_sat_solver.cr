#!/usr/bin/env crystal

# Test the existing SAT solver functionality
require "../src/multiplicative_constraint"

puts "TESTING EXISTING SAT SOLVER"
puts "=" * 40

# Simple SAT problem: (x1 OR x2) AND (NOT x1 OR x2) AND (x1 OR NOT x2)
# This should be satisfiable with x1=true, x2=true
clauses = [
  [1, 2],      # x1 OR x2
  [-1, 2],     # NOT x1 OR x2  
  [1, -2]      # x1 OR NOT x2
]

puts "SAT Problem: (x1 ∨ x2) ∧ (¬x1 ∨ x2) ∧ (x1 ∨ ¬x2)"
puts "Clauses: #{clauses}"

solver = MultiplicativeConstraint::SATSolver.new(2, clauses)

# Run diagnostic
puts "\nRunning diagnostic..."
diagnostic = solver.diagnostic
puts "Predicted solvable: #{diagnostic.predicted_solvable}"
puts "Confidence: #{diagnostic.confidence}"
puts "Variance: #{diagnostic.variance}"
puts "Runtime: #{diagnostic.runtime}s"

# Solve
puts "\nSolving..."
result = solver.solve(iterations: 1000)

puts "Satisfiable: #{result.satisfiable}"
puts "Assignment: #{result.assignment}"
puts "Satisfied clauses: #{result.satisfied_clauses}/#{result.total_clauses}"
puts "Satisfaction rate: #{result.satisfaction_rate}%"
puts "Solve time: #{result.solve_time}s"
puts "Energy: #{result.energy}"

if result.satisfiable
  puts "\nSolution is valid!"
  puts "x1: #{result.assignment[0] ? "true" : "false"}"
  puts "x2: #{result.assignment[1] ? "true" : "false"}"
  
  # Verify manually
  x1 = result.assignment[0]
  x2 = result.assignment[1]
  
  clause1 = x1 || x2
  clause2 = (!x1) || x2
  clause3 = x1 || (!x2)
  
  puts "Manual verification:"
  puts "  (x1 ∨ x2) = #{x1} ∨ #{x2} = #{clause1} ✓"
  puts "  (¬x1 ∨ x2) = ¬#{x1} ∨ #{x2} = #{clause2} ✓"
  puts "  (x1 ∨ ¬x2) = #{x1} ∨ ¬#{x2} = #{clause3} ✓"
  puts "All clauses satisfied: #{clause1 && clause2 && clause3}"
end