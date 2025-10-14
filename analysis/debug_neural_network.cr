#!/usr/bin/env crystal
#
# Debug Neural Network Training
# Investigating why neural network training gets stuck
#

require "./src/multiplicative_constraint"

puts "=" * 70
puts "DEBUG NEURAL NETWORK TRAINING"
puts "Investigating training loop issues"
puts "=" * 70
puts

# Create simple test graph
weights = [10.0, 20.0, 30.0, 40.0]

edge_types = {
  "critical" => [
    {0, 1, 8.0}, {1, 2, 8.0}, {2, 3, 8.0}, {3, 0, 8.0}
  ],
  "normal" => [
    {0, 2, 3.0}, {1, 3, 3.0}
  ],
  "backup" => [
    {0, 3, 1.0}, {1, 2, 1.0}
  ]
}

puts "📊 Creating simple 4-node test graph..."
graph = MultiplicativeConstraint::Graph.from_multi_type_edges(weights, edge_types)
engine = MultiplicativeConstraint::Engine.new(graph, 2)

puts "✅ Graph created: #{graph.memory_usage}"
puts "  Multi-type: #{graph.multi_type}"
puts "  Edge types: #{graph.num_types}"
puts

# Test 1: Check initial state
puts "🔍 TEST 1: INITIAL STATE CHECK"

puts "  Initial type weights:"
initial_weights = engine.get_type_weights
initial_weights.each { |k, v| puts "    #{k}: #{v}" }
puts

puts "  Testing basic solve (no training)..."
start_time = Time.monotonic
basic_result = engine.solve(iterations: 20, step: 0.35, seed: 42)
basic_time = Time.monotonic - start_time
puts "    Basic solve time: #{basic_time.total_seconds.round(3)}s"
puts "    Basic energy: #{basic_result.energy.round(2)}"
puts

# Test 2: Manual weight setting test
puts "🎛️ TEST 2: MANUAL WEIGHT SETTING"

test_weights = {"critical" => 2.0, "normal" => 1.0, "backup" => 0.5}
puts "  Setting weights: #{test_weights}"
engine.set_type_weights(test_weights)

start_time = Time.monotonic
manual_result = engine.solve(iterations: 20, step: 0.35, seed: 42)
manual_time = Time.monotonic - start_time
puts "    Manual solve time: #{manual_time.total_seconds.round(3)}s"
puts "    Manual energy: #{manual_result.energy.round(2)}"
puts

# Test 3: Neural network with minimal iterations and debug
puts "🧠 TEST 3: NEURAL NETWORK DEBUG (3 iterations)"

puts "  Starting neural network training..."
puts "  This will show detailed debug info..."

# Let's manually step through the training process
network = engine.get_type_weights
puts "  Initial network weights: #{network}"

# Try to access the neural network directly
puts "  Checking multi-type network status..."
if graph.multi_type && graph.num_types > 1
  puts "    ✅ Multi-type network should be available"
else
  puts "    ❌ Multi-type network not available"
end

# Test with very minimal training
puts "  Attempting minimal training (1 iteration)..."
begin
  start_time = Time.monotonic

  # Try just 1 iteration
  engine.train_type_weights(iterations: 1, learning_rate: 0.1)

  training_time = Time.monotonic - start_time
  puts "    ✅ Training completed in #{training_time.total_seconds.round(3)}s"

  final_weights = engine.get_type_weights
  puts "    Final weights: #{final_weights}"

  # Test solve with trained weights
  start_time = Time.monotonic
  trained_result = engine.solve(iterations: 20, step: 0.35, seed: 42)
  trained_time = Time.monotonic - start_time
  puts "    Trained solve time: #{trained_time.total_seconds.round(3)}s"
  puts "    Trained energy: #{trained_result.energy.round(2)}"

rescue ex
  puts "    ❌ Training failed with error: #{ex.message}"
  if backtrace = ex.backtrace?
    puts "    Backtrace: #{backtrace.first(3).join(", ")}"
  end
end

puts

# Test 4: Check network components
puts "🔧 TEST 4: NETWORK COMPONENTS DEBUG"

puts "  Checking graph structure:"
puts "    Graph size: #{graph.size}"
puts "    Edge types: #{graph.type_names}"
puts "    Multi-type: #{graph.multi_type}"

puts "  Checking edge matrices:"
graph.edge_types.each do |type_name, matrix|
  puts "    #{type_name}: #{matrix.nnz} non-zero elements"
end

puts

# Test 5: Try progressive training
puts "📈 TEST 5: PROGRESSIVE TRAINING TEST"

puts "  Testing progressive training with detailed monitoring..."

begin
  (1..3).each do |iter_count|
    puts "    Testing #{iter_count} iteration(s)..."

    start_time = Time.monotonic
    engine.train_type_weights(iterations: iter_count, learning_rate: 0.1)
    training_time = Time.monotonic - start_time

    puts "      ✅ #{iter_count} iteration(s) completed in #{training_time.total_seconds.round(3)}s"

    current_weights = engine.get_type_weights
    puts "      Current weights: #{current_weights.map { |k, v| "#{k[0]}=#{v.round(2)}" }.join(", ")}"

    # Quick solve test
    start_time = Time.monotonic
    test_result = engine.solve(iterations: 10, step: 0.35, seed: 42)
    test_time = Time.monotonic - start_time
    puts "      Test solve: #{test_time.total_seconds.round(3)}s, energy: #{test_result.energy.round(2)}"
    puts
  end
rescue ex
  puts "    ❌ Progressive training failed: #{ex.message}"
end

puts "🚀 DEBUG COMPLETE!"
puts "   Review the output above to identify the bottleneck"
puts "=" * 70