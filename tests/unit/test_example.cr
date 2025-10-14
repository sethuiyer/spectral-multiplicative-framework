require "./src/multiplicative_constraint"

weights = [12.0, 15.0, 17.0, 10.0, 8.0, 22.0]
adjacency = [
  [0.0, 2.0, 1.0, 0.0, 0.0, 4.0],
  [2.0, 0.0, 3.5, 1.0, 0.0, 2.0],
  [1.0, 3.5, 0.0, 0.0, 1.0, 0.5],
  [0.0, 1.0, 0.0, 0.0, 2.3, 0.0],
  [0.0, 0.0, 1.0, 2.3, 0.0, 1.2],
  [4.0, 2.0, 0.5, 0.0, 1.2, 0.0],
]
labels = ["TaskA", "TaskB", "TaskC", "TaskD", "TaskE", "TaskF"]

puts "=== Testing Improved Cross-Conflict Metrics ==="
puts "Original 6-node, 4-partition problem"
puts

graph = MultiplicativeConstraint::Graph.new(weights, adjacency)

# Create BetheHessian for improved metrics
bethe_hessian = MultiplicativeConstraint::BetheHessian.new(graph)

# Test the weighted cut ratio calculation
puts "Testing weighted cut ratio metric..."
test_labels = [0, 0, 1, 2, 2, 3]  # Expected segmentation from analysis
weighted_cut = bethe_hessian.weighted_cut_ratio(graph, test_labels)
puts "Weighted cut ratio: #{weighted_cut.round(3)} (expected ~7.8/total_volume)"

# Debug: Check total volume and individual edge contributions
puts "Debugging weighted cut calculation:"
total_vol = graph.edges.sum { |(i, j, w)| w * (graph.weighted_degree(i) + graph.weighted_degree(j)) }
puts "Total volume: #{total_vol.round(3)}"

# Calculate edge contributions manually
cut_sum = 0.0
graph.edges.each do |(i, j, weight)|
  seg_i, seg_j = test_labels[i], test_labels[j]
  next if seg_i == seg_j

  size_i = test_labels.count(seg_i)
  size_j = test_labels.count(seg_j)
  balance_factor = 1.0 + (size_i - size_j).abs.to_f64

  edge_contrib = (graph.weights[i] * graph.weights[j] * weight) / balance_factor
  cut_sum += edge_contrib

  puts "Edge (#{labels[i]}-#{labels[j]}): w_i=#{graph.weights[i]}, w_j=#{graph.weights[j]}, edge_w=#{weight}, balance=#{balance_factor.round(2)}, contrib=#{edge_contrib.round(3)}"
end

puts "Cut sum: #{cut_sum.round(3)}, Ratio: #{(cut_sum/total_vol).round(3)}"

# Run optimization with correlation tracking
puts
puts "Running optimization with spectral-multiplicative correlation tracking..."
engine = MultiplicativeConstraint::Engine.new(graph, 4)
result = engine.solve(iterations: 1500, step: 0.35, seed: 2025, bethe_hessian: bethe_hessian)

puts
puts MultiplicativeConstraint::Report.generate(result, labels)

# Final weighted cut ratio
final_labels = result.discrete_solution
final_weighted_cut = bethe_hessian.weighted_cut_ratio(graph, final_labels)
puts "Final weighted cut ratio: #{final_weighted_cut.round(3)}"

puts
puts "=== Testing Weight Fairness Hyperparameter Adjustment ==="
puts "Original weight fairness: #{result.weight_fairness.round(2)} (dominates energy functional)"

# Test with reduced weight fairness coefficient
engine_reduced = MultiplicativeConstraint::Engine.new(
  graph, 4,
  weight_fairness_weight: 0.01  # Reduced from default 0.5
)

result_reduced = engine_reduced.solve(iterations: 1500, step: 0.35, seed: 2025, bethe_hessian: bethe_hessian)

puts "Reduced weight fairness result:"
puts "Weight fairness: #{result_reduced.weight_fairness.round(2)}"
puts "Unified energy: #{result_reduced.energy.round(3)} (vs #{result.energy.round(3)} original)"
puts "Spectral action: #{result_reduced.spectral.round(3)}"
puts "Fairness: #{result_reduced.fairness.round(3)}"
puts "Entropy: #{result_reduced.entropy.round(3)}"
puts "Multiplicative penalty: #{result_reduced.penalty.round(3)}"

final_weighted_cut_reduced = bethe_hessian.weighted_cut_ratio(graph, result_reduced.discrete_solution)
puts "Final weighted cut ratio: #{final_weighted_cut_reduced.round(3)} (vs #{final_weighted_cut.round(3)} original)"
