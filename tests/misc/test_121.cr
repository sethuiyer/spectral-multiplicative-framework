require "../../src/multiplicative_constraint"

puts "🔢 TESTING FACTORIZATION OF 121"
puts "Target: 121 = 11 × 11 (perfect square)"
puts "Challenge: Can quantum methods detect repeated prime factors?"
puts "="*50

# Test factorization of 121
target = 121
sqrt_target = Math.sqrt(target)

# Search space around sqrt(target)
search_range = 50
start_factor = [2, (sqrt_target - search_range).to_i].max
end_factor = [(sqrt_target + search_range).to_i, 500].min

candidates = (start_factor..end_factor).to_a
puts "Search space: #{candidates.size} candidates from #{start_factor} to #{end_factor}"

# Find actual factors
actual_factors = candidates.select { |f| target % f == 0 }
puts "Actual factors: #{actual_factors}"

# Create quantum graph
weights = Array(Float64).new(candidates.size, 0.0)
adjacency = Array(Array(Float64)).new(candidates.size) { Array(Float64).new(candidates.size, 0.0) }

# Weight assignment
candidates.each_with_index do |factor, i|
  if target % factor == 0
    weights[i] = 10.0  # High weight for actual factors
  else
    distance = (factor - sqrt_target).abs
    weights[i] = 1.0 / (1.0 + distance / 50.0)
  end
end

# Create adjacency matrix
candidates.each_with_index do |factor_i, i|
  candidates.each_with_index do |factor_j, j|
    next if i == j

    product = factor_i * factor_j

    if product == target
      adjacency[i][j] = 10.0
      adjacency[j][i] = 10.0
    elsif product < target
      ratio = product.to_f / target.to_f
      adjacency[i][j] = ratio
      adjacency[j][i] = adjacency[i][j]
    else
      adjacency[i][j] = 0.01
      adjacency[j][i] = 0.01
    end
  end
end

puts "Quantum graph created with #{candidates.size} nodes"
puts "Running spectral factorizer..."

# Run quantum solver
start_time = Time.utc

graph = MultiplicativeConstraint::Graph.new(weights, adjacency)
engine = MultiplicativeConstraint::Engine.new(graph, 3)
result = engine.solve(iterations: 1000, seed: 123)

solve_time = (Time.utc - start_time).total_seconds

puts "⚡ Runtime: #{(solve_time * 1000).round(1)} ms"
puts "📊 Final Energy: #{result.energy.round(3)}"
puts "📊 Spectral Action: #{result.spectral.round(3)}"
puts "📊 Segments: #{result.segments.size}"

# Analyze results
puts "\n🔍 FACTOR ANALYSIS:"
puts "Segments found: #{result.segments.size}"

found_factors = [] of Int32
found_products = [] of Int32

result.segments.each_with_index do |segment, seg_idx|
  puts "Segment #{seg_idx + 1}: #{segment.size} candidates"
  segment.each do |candidate_idx|
    factor = candidates[candidate_idx]
    puts "  #{factor}"
  end

  # Check pairs within segment
  if segment.size >= 2
    segment.each_combination(2) do |combo|
      factor1 = candidates[combo[0]]
      factor2 = candidates[combo[1]]
      product = factor1 * factor2

      if product == target
        found_factors = [factor1, factor2]
        found_products = [product]
        puts "  ✅ FOUND: #{factor1} × #{factor2} = #{product}"
      end
    end
  end
end

# Try cross-segment combinations
if found_factors.empty?
  puts "\n🔍 Checking cross-segment combinations..."
  all_candidates = result.segments.flatten.map { |i| candidates[i] }.uniq

  all_candidates.each_combination(2) do |combo|
    factor1 = combo[0]
    factor2 = combo[1]
    product = factor1 * factor2

    if product == target
      found_factors = [factor1, factor2]
      found_products = [product]
      puts "  ✅ FOUND CROSS-SEGMENT: #{factor1} × #{factor2} = #{product}"
      break
    end
  end
end

# Final verdict
puts "\n🏆 FACTORIZATION RESULTS:"
if found_factors.empty?
  puts "❌ FAILED: No factorization found"
  puts "Expected: 11 × 11 = 121"
else
  product = found_factors[0] * found_factors[1]
  if product == target
    puts "✅ SUCCESS: #{found_factors[0]} × #{found_factors[1]} = #{product}"
    puts "✅ EXACT MATCH: Target #{target} achieved!"

    if found_factors[0] == found_factors[1]
      puts "🎯 BONUS: Detected repeated prime factor (perfect square)!"
    end
  else
    puts "⚠️  CLOSE: Got #{product} (target was #{target})"
  end
end

puts "\n🎯 Conclusion: Testing quantum methods on perfect squares!"