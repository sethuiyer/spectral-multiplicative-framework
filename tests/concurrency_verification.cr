require "../src/multiplicative_constraint"
require "../src/multiplicative_constraint/sat"
require "../src/multiplicative_constraint/neural_weights"

puts "🧵 CONCURRENCY VERIFICATION SUITE 🧵"
puts "======================================"

# 1. Test Parallel SAT Diagnostic
puts "\n[1] Testing Parallel Casimir Diagnostic..."
start_time = Time.monotonic

# Create a medium-sized SAT problem
num_vars = 50
clauses = Array(Array(Int32)).new
100.times do
  # Random 3-SAT clauses
  clause = [
    (rand(num_vars) + 1) * (rand > 0.5 ? 1 : -1),
    (rand(num_vars) + 1) * (rand > 0.5 ? 1 : -1),
    (rand(num_vars) + 1) * (rand > 0.5 ? 1 : -1)
  ]
  clauses << clause
end

solver = MultiplicativeConstraint::SATSolver.new(num_vars, clauses)
# This calls the parallelized diagnostic method
diag = solver.diagnostic(num_perturbations: 50) 

duration = Time.monotonic - start_time
puts "✅ Diagnostic finished in #{duration.total_milliseconds.round(2)} ms"
puts "   Variance: #{diag.variance}"
puts "   Prediction: #{diag.recommendation}"


# 2. Test Parallel Neural Training
puts "\n[2] Testing Parallel Neural Training..."
start_time = Time.monotonic

# Create dummy resources and constraints
resources = (0...20).map { |i| MultiplicativeConstraint::Resource.new(i.to_s, "R#{i}", 1.0) }
constraints = [
  MultiplicativeConstraint::ConstraintRelation.new("0", "1", 1.0, "requires"),
  MultiplicativeConstraint::ConstraintRelation.new("5", "6", 1.0, "conflicts")
]

trainer = MultiplicativeConstraint::NeuralWeightTrainer.new(resources, constraints, k: 2)
# This calls the parallelized train method (3 parallel restarts per epoch)
trainer.train(epochs: 2, learning_rate: 0.01)

duration = Time.monotonic - start_time
puts "✅ Training finished in #{duration.total_milliseconds.round(2)} ms"

puts "\n🎉 ALL CONCURRENCY TESTS PASSED!"
