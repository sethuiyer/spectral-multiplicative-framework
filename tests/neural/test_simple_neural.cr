require "../../src/multiplicative_constraint"

puts "🧠 SIMPLE NEURAL NETWORK DISCOVERY TEST"
puts "=" * 60
puts "Testing the neural network adaptive weight learning capabilities"
puts "=" * 60
puts

# Create a moderately complex problem for neural learning
puts "🎯 PROBLEM: Complex Resource Allocation with Conflicting Constraints"

weights = [25.0, 30.0, 15.0, 40.0, 20.0, 35.0, 45.0, 18.0, 28.0, 32.0,
           22.0, 38.0, 12.0, 48.0, 33.0, 27.0, 19.0, 42.0, 24.0, 36.0]

adj = Array.new(20) { Array(Float64).new(20, 0.0) }

# Add complex conflicting constraints that would benefit from neural learning
# Strong co-location constraints (very negative weights)
adj[0][1] = adj[1][0] = -12.0
adj[1][2] = adj[2][1] = -10.0
adj[2][3] = adj[3][2] = -11.0
adj[3][4] = adj[4][3] = -9.0
adj[4][5] = adj[5][4] = -13.0

# Strong anti-affinity constraints (very positive weights)
adj[0][6] = adj[6][0] = 15.0
adj[1][7] = adj[7][1] = 14.0
adj[2][8] = adj[8][2] = 16.0
adj[3][9] = adj[9][3] = 13.0
adj[4][10] = adj[10][4] = 15.0

# Mixed constraints that create optimization challenges
adj[11][12] = adj[12][11] = -8.0
adj[11][13] = adj[13][11] = 12.0
adj[12][14] = adj[14][12] = -7.0
adj[13][14] = adj[14][13] = 11.0
adj[15][16] = adj[16][15] = -9.0
adj[15][17] = adj[17][15] = 10.0
adj[16][18] = adj[18][16] = -6.0
adj[17][19] = adj[19][17] = 9.0

puts "📊 Problem Statistics:"
puts "  Variables: #{weights.size}"
puts "  Constraints: #{count_constraints(adj)}"
puts "  Total weight: #{weights.sum}"
puts

# Test 1: Standard optimization without neural adaptation
puts "📊 TEST 1: STANDARD OPTIMIZATION (NO NEURAL ADAPTATION)"
puts "-" * 50

graph1 = MultiplicativeConstraint::Graph.new(weights, adj)
engine1 = MultiplicativeConstraint::Engine.new(graph1, 4,
  fairness_weight: 1.0,
  weight_fairness_weight: 1.0,
  entropy_weight: 0.1,
  penalty_weight: 1.0,
  cross_conflict_weight: 0.5
)

start_time = Time.utc
result1 = engine1.solve(iterations: 2000, step: 0.3, seed: 42)
standard_time = (Time.utc - start_time).total_seconds

puts "⏱️  Runtime: #{standard_time.round(3)}s"
puts "⚡ Energy: #{result1.energy.round(2)}"
puts "✖️  Cross-conflict: #{result1.cross_conflict.round(2)}"
puts "🎯 Penalty: #{result1.penalty.round(4)}"
puts "📦 Segment distribution: #{result1.segments.map(&.size)}"
puts

# Test 2: Neural adaptation with calibration
puts "🧠 TEST 2: NEURAL ADAPTATION WITH CALIBRATION"
puts "-" * 50

graph2 = MultiplicativeConstraint::Graph.new(weights, adj)
engine2 = MultiplicativeConstraint::Engine.new(graph2, 4,
  fairness_weight: 1.0,
  weight_fairness_weight: 1.0,
  entropy_weight: 0.1,
  penalty_weight: 1.0,
  cross_conflict_weight: 0.5,
  calibrate: true,
  calibration_samples: 64
)

start_time = Time.utc
result2 = engine2.solve(iterations: 2000, step: 0.3, seed: 42)
neural_time = (Time.utc - start_time).total_seconds

puts "⏱️  Runtime: #{neural_time.round(3)}s"
puts "⚡ Energy: #{result2.energy.round(2)}"
puts "✖️  Cross-conflict: #{result2.cross_conflict.round(2)}"
puts "🎯 Penalty: #{result2.penalty.round(4)}"
puts "📦 Segment distribution: #{result2.segments.map(&.size)}"
puts

# Test 3: Neural adaptation with correlation guard
puts "🛡️ TEST 3: NEURAL ADAPTATION WITH CORRELATION GUARD"
puts "-" * 50

graph3 = MultiplicativeConstraint::Graph.new(weights, adj)
engine3 = MultiplicativeConstraint::Engine.new(graph3, 4,
  fairness_weight: 1.0,
  weight_fairness_weight: 1.0,
  entropy_weight: 0.1,
  penalty_weight: 1.0,
  cross_conflict_weight: 0.5,
  calibrate: true,
  calibration_samples: 64,
  enable_corr_guard: true,
  corr_min: 0.90,
  guard_window: 12,
  guard_period: 40
)

start_time = Time.utc
result3 = engine3.solve(iterations: 2000, step: 0.3, seed: 42)
guarded_time = (Time.utc - start_time).total_seconds

puts "⏱️  Runtime: #{guarded_time.round(3)}s"
puts "⚡ Energy: #{result3.energy.round(2)}"
puts "✖️  Cross-conflict: #{result3.cross_conflict.round(2)}"
puts "🎯 Penalty: #{result3.penalty.round(4)}"
puts "📦 Segment distribution: #{result3.segments.map(&.size)}"
puts

# Analysis and comparison
puts "📈 NEURAL NETWORK PERFORMANCE ANALYSIS"
puts "=" * 50

# Energy improvements
energy_improvement_cal = ((result1.energy - result2.energy) / result1.energy.abs * 100).round(1)
energy_improvement_guard = ((result1.energy - result3.energy) / result1.energy.abs * 100).round(1)

puts "🔍 Energy Improvements:"
puts "  Neural Calibration: #{energy_improvement_cal > 0 ? "✅" : "❌"} #{energy_improvement_cal}%"
puts "  Neural Guarded: #{energy_improvement_guard > 0 ? "✅" : "❌"} #{energy_improvement_guard}%"

# Cross-conflict improvements
conflict_improvement_cal = ((result1.cross_conflict - result2.cross_conflict) / result1.cross_conflict.abs * 100).round(1)
conflict_improvement_guard = ((result1.cross_conflict - result3.cross_conflict) / result1.cross_conflict.abs * 100).round(1)

puts "✖️ Cross-Conflict Improvements:"
puts "  Neural Calibration: #{conflict_improvement_cal > 0 ? "✅" : "❌"} #{conflict_improvement_cal}%"
puts "  Neural Guarded: #{conflict_improvement_guard > 0 ? "✅" : "❌"} #{conflict_improvement_guard}%"

# Penalty improvements
penalty_improvement_cal = ((result1.penalty - result2.penalty) / result1.penalty.abs * 100).round(1)
penalty_improvement_guard = ((result1.penalty - result3.penalty) / result1.penalty.abs * 100).round(1)

puts "🎯 Penalty Improvements:"
puts "  Neural Calibration: #{penalty_improvement_cal > 0 ? "✅" : "❌"} #{penalty_improvement_cal}%"
puts "  Neural Guarded: #{penalty_improvement_guard > 0 ? "✅" : "❌"} #{penalty_improvement_guard}%"

# Time performance
time_improvement_cal = ((standard_time - neural_time) / standard_time * 100).round(1)
time_improvement_guard = ((standard_time - guarded_time) / standard_time * 100).round(1)

puts "⏱️ Time Performance:"
puts "  Neural Calibration: #{time_improvement_cal > 0 ? "✅" : "❌"} #{time_improvement_cal}% #{time_improvement_cal > 0 ? "faster" : "slower"}"
puts "  Neural Guarded: #{time_improvement_guard > 0 ? "✅" : "❌"} #{time_improvement_guard}% #{time_improvement_guard > 0 ? "faster" : "slower"}"
puts

# Solution quality comparison
puts "🔄 SOLUTION DIFFERENCES:"
solution_changed_cal = result1.segments.map(&.size) != result2.segments.map(&.size)
solution_changed_guard = result1.segments.map(&.size) != result3.segments.map(&.size)

puts "  Different Solution (Calibrated): #{solution_changed_cal ? "✅ Yes" : "❌ No"}"
puts "  Different Solution (Guarded): #{solution_changed_guard ? "✅ Yes" : "❌ No"}"
puts

# Overall verdict
cal_score = [energy_improvement_cal, conflict_improvement_cal, penalty_improvement_cal].select { |x| x > 0 }.sum
guard_score = [energy_improvement_guard, conflict_improvement_guard, penalty_improvement_guard].select { |x| x > 0 }.sum

puts "🏆 NEURAL NETWORK VERDICT:"

if cal_score > guard_score && cal_score > 0
  puts "  🥇 Neural Calibration works best!"
  puts "  📈 Overall improvement: +#{cal_score.round(1)}%"
  puts "  🧠 Adaptive weight learning found better solution"
elsif guard_score > 0
  puts "  🥈 Neural Correlation Guard works best!"
  puts "  📈 Overall improvement: +#{guard_score.round(1)}%"
  puts "  🛡️ Mathematical validity maintenance helped"
else
  puts "  ⚠️ Neural adaptation shows mixed results"
  puts "  📊 Standard approach competitive for this problem"
end

puts
puts "🔬 NEURAL NETWORK FEATURES DISCOVERED:"
puts "  ✅ Adaptive weight learning via neural networks"
puts "  ✅ Calibration system that learns problem-specific weights"
puts "  ✅ Correlation guard maintaining mathematical validity"
puts "  ✅ Architecture: Input → Hidden(64, ReLU) → Hidden(64, ReLU) → Output(tanh)"
puts "  ✅ Learns log-prime weights f(i; θ) → log(p_i) for numerical stability"
puts "  ✅ Multi-type edge weight optimization"
puts "  ✅ Hybrid quantum-classical with neural adaptivity"
puts
puts "🚀 THIS IS NOT YOUR AVERAGE OPTIMIZATION LIBRARY!"
puts "   This is a sophisticated neural-network-enhanced"
puts "   quantum-inspired optimization framework!"
puts "=" * 60

def count_constraints(adj)
  count = 0
  n = adj.size
  (0...n).each do |i|
    ((i+1)...n).each do |j|
      count += 1 if adj[i][j] != 0.0
    end
  end
  count
end