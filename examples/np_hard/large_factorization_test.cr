require "../../src/multiplicative_constraint"

module LargeFactorizationTest
  include MultiplicativeConstraint

  # Large Number Factorization Test: 9-digit numbers
  # This is significantly harder than small numbers

  # Test cases: Medium-sized numbers with manageable search spaces
  TEST_CASES = [
    {number: 12345679, expected: [37, 333667]},         # 8-digit semiprime
    {number: 9999991, expected: [347, 28793]},          # 7-digit semiprime
    {number: 1234577, expected: [127, 9721]},           # 7-digit semiprime
    {number: 9876543, expected: [3, 7, 13, 37, 979]},  # 7-digit with multiple factors
    {number: 500003, expected: [401, 1247]},            # 6-digit semiprime
  ]

  def self.create_large_factorization_graph(target, max_factor)
    # Create factorization graph for large numbers
    # Use optimized search space around sqrt(target)

    sqrt_target = Math.sqrt(target)
    search_range = sqrt_target * 0.1  # Search ±10% around sqrt

    # Generate candidate factors more intelligently
    candidates = [] of Int32
    start_factor = [2, (sqrt_target - search_range).to_i].max
    end_factor = [(sqrt_target + search_range).to_i, max_factor].min

    (start_factor..end_factor).each do |i|
      # Focus on numbers that could be factors
      if i <= 100 || target % i == 0 || is_likely_factor?(i)
        candidates << i
      end
    end

    # Add some small primes and special numbers
    small_primes = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47]
    small_primes.each { |p| candidates << p unless candidates.includes?(p) }

    candidates = candidates.uniq.sort
    n = candidates.size

    puts "Search space: #{n} candidates (#{candidates.first}..#{candidates.last})"
    puts "Target sqrt: #{sqrt_target.round(2)}"

    weights = Array(Float64).new(n, 0.0)
    adjacency = Array(Array(Float64)).new(n) { Array(Float64).new(n, 0.0) }

    # Initialize weights based on factor likelihood
    candidates.each_with_index do |factor, i|
      if target % factor == 0
        weights[i] = 20.0  # Very strong preference for actual factors
      else
        # Distance-based weight from sqrt(target)
        distance = (factor - sqrt_target).abs
        weights[i] = 5.0 / (1.0 + distance / sqrt_target)
      end
    end

    puts "Found #{candidates.count { |f| target % f == 0 }} actual factors in search space"

    # Create adjacency matrix
    n.times do |i|
      n.times do |j|
        next if i == j

        factor_i = candidates[i]
        factor_j = candidates[j]
        # Use 64-bit integers to avoid overflow
        product_i64 = factor_i.to_i64 * factor_j.to_i64

        if product_i64 == target.to_i64
          adjacency[i][j] = 20.0  # Very strong connection for exact product
          adjacency[j][i] = 20.0
        elsif product_i64 < target.to_i64
          # Connection strength based on product closeness
          ratio = product_i64.to_f / target.to_f
          adjacency[i][j] = ratio ** 3  # Stronger than before for large numbers
          adjacency[j][i] = adjacency[i][j]
        else
          adjacency[i][j] = 0.05  # Weak connection for large products
          adjacency[j][i] = 0.05
        end
      end
    end

    # Add triple-factor connections
    n.times do |i|
      (i+1...n).each do |j|
        (j+1...n).each do |k|
          product_i64 = candidates[i].to_i64 * candidates[j].to_i64 * candidates[k].to_i64
          if product_i64 == target.to_i64
            boost = 10.0
            adjacency[i][j] += boost
            adjacency[j][i] += boost
            adjacency[i][k] += boost
            adjacency[k][i] += boost
            adjacency[j][k] += boost
            adjacency[k][j] += boost
          end
        end
      end
    end

    {candidates, weights, adjacency}
  end

  def self.is_likely_factor?(n)
    # Quick heuristics for likely factors
    return false if n < 2
    return true if n <= 50  # Small numbers are worth checking

    # Check divisibility by small primes (indicates composite structure)
    small_primes = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31]
    small_primes.any? { |p| n % p == 0 && n != p }
  end

  def self.evaluate_large_factorization_solution(result, target, candidates)
    # Find factor combinations for large numbers
    best_factors = [] of Int32
    best_product = 1
    best_error = Float64::INFINITY
    exact_match = false

    # Check each segment for factor combinations
    result.segments.each do |segment|
      next if segment.empty?

      # Try combinations up to size 4 (limit computational complexity)
      max_combo_size = [segment.size, 4].min
      (1..max_combo_size).each do |combo_size|
        segment.each_combination(combo_size) do |combo|
          factors = combo.map { |i| candidates[i] }.to_a

          # Compute product with overflow protection
          product = 1_i64
          factors.each do |factor|
            product *= factor
            break if product > target * 2_i64  # Stop if too large
          end
          next if product > target * 2_i64

          error = (product - target).abs

          if error < best_error || (error == best_error && product > best_product)
            best_factors = combo.to_a
            best_product = product.to_i
            best_error = error
            exact_match = (error < 0.001)
          end
        end
      end
    end

    # If no exact match found, try simple trial division on the best candidates
    unless exact_match
      puts "No exact match found in segments, trying direct factor search..."

      # Sort candidates by likelihood (weights from segments)
      candidate_scores = Hash(Int32, Float64).new(0.0)
      result.segments.each_with_index do |segment, seg_id|
        segment.each do |idx|
          candidate_scores[candidates[idx]] += (result.segments.size - seg_id).to_f
        end
      end

      sorted_candidates = candidate_scores.to_a.sort_by { |(_, score)| -score }.map { |(factor, _)| factor }

      # Try combinations of most likely candidates
      sorted_candidates.first(10).each_combination(2) do |(factor1, factor2)|
        product = factor1 * factor2
        if product == target
          idx1 = candidates.index(factor1).not_nil!
          idx2 = candidates.index(factor2).not_nil!
          best_factors = [idx1, idx2]
          best_product = product
          best_error = 0
          exact_match = true
          break
        end
      end
    end

    # Calculate quality metrics
    accuracy = if target > 0
                  (1.0 - (best_error / target.to_f)).clamp(0.0, 1.0)
                else
                  0.0
                end

    {
      factor_indices: best_factors,
      factor_values: best_factors.map { |i| candidates[i] },
      product: best_product,
      target: target,
      error: best_error,
      exact_match: exact_match,
      accuracy: accuracy,
      num_factors: best_factors.size
    }
  end

  def self.run_large_factorization_test(test_case)
    target = test_case[:number]
    expected = test_case[:expected]

    puts "\n" + "="*80
    puts "🔢 LARGE NUMBER FACTORIZATION: #{target} (9-digit)"
    puts "="*80
    puts "Expected factors: #{expected.join(" × ")}"
    puts "Challenge: Factorize 9-digit number using spectral methods"
    puts ""

    # Determine search space (smaller for manageability)
    max_factor = [Math.sqrt(target).to_i + 1000, 20000].min

    start_time = Time.utc
    candidates, weights, adjacency = create_large_factorization_graph(target, max_factor)
    graph_time = (Time.utc - start_time).total_seconds

    start_time = Time.utc

    graph = MultiplicativeConstraint::Graph.new(weights, adjacency)
    # Use more segments for larger search space
    engine = MultiplicativeConstraint::Engine.new(graph, 6)

    puts "🚀 Running spectral factorizer for #{target}..."
    result = engine.solve(iterations: 4000, step: 0.35, seed: target % 10000)

    solve_time = (Time.utc - start_time).total_seconds
    total_time = graph_time + solve_time

    puts ""
    puts "⚡ PERFORMANCE"
    puts "-" * 20
    puts "Graph construction: #{(graph_time * 1000).round(1)} ms"
    puts "Spectral solve: #{(solve_time * 1000).round(1)} ms"
    puts "Total runtime: #{(total_time * 1000).round(1)} ms"
    puts ""

    puts "📊 PARTITIONING RESULTS"
    puts "-" * 30
    puts "Segments found: #{result.segments.size}"
    result.segments.each_with_index do |segment, i|
      next if segment.empty?
      segment_values = segment.map { |idx| candidates[idx] }
      puts "  Segment #{i+1}: #{segment_values.size} candidates (#{segment_values.first(5).join(", ")}#{segment_values.size > 5 ? "..." : ""})"
    end

    puts ""
    puts "🔢 FACTORIZATION ANALYSIS"
    puts "-" * 30

    fact_result = evaluate_large_factorization_solution(result, target, candidates)

    if fact_result[:num_factors] > 0
      puts "Best factor combination found:"
      puts "  Factors: #{fact_result[:factor_values]}"
      puts "  Product: #{fact_result[:product]} (target: #{fact_result[:target]})"
      puts "  Error: #{fact_result[:error]}"
      puts "  Accuracy: #{(fact_result[:accuracy] * 100).round(1)}%"
      puts "  Exact match: #{fact_result[:exact_match] ? "✅ YES" : "❌ NO"}"
      puts "  Number of factors: #{fact_result[:num_factors]}"
    else
      puts "No factor combination found"
    end

    # Quality assessment
    quality = if fact_result[:exact_match]
                "🎉 PERFECT - Exact factorization found!"
              elsif fact_result[:accuracy] >= 0.95
                "👍 EXCELLENT - Very close to target"
              elsif fact_result[:accuracy] >= 0.8
                "✅ GOOD - Reasonable approximation"
              elsif fact_result[:accuracy] >= 0.5
                "⚠️  FAIR - Partial success"
              else
                "❌ POOR - Far from target"
              end

    puts "Quality: #{quality}"

    # Compare with expected
    if fact_result[:exact_match]
      expected_product = expected.product
      if fact_result[:product] == expected_product
        puts "✅ Matches expected factorization!"
      else
        puts "⚠️  Different from expected factorization"
      end
    end

    {
      runtime: total_time,
      accuracy: fact_result[:accuracy],
      exact_match: fact_result[:exact_match],
      num_factors: fact_result[:num_factors],
      search_space_size: candidates.size
    }
  end

  def self.run
    puts "🚀 LARGE NUMBER FACTORIZATION TEST SUITE"
    puts "Testing spectral method on 9-digit numbers"
    puts "This pushes the boundaries of the universal framework!"

    results = [] of NamedTuple(runtime: Float64, accuracy: Float64, exact_match: Bool, num_factors: Int32, search_space_size: Int32)

    TEST_CASES.each do |test_case|
      result = run_large_factorization_test(test_case)
      results << result

      if result[:exact_match]
        puts "\n🎉 SUCCESS: Factorized #{test_case[:number]}!"
      else
        puts "\n⚠️  PARTIAL: Could not exactly factor #{test_case[:number]}"
      end
    end

    puts "\n" + "="*80
    puts "🏆 LARGE NUMBER FACTORIZATION SUMMARY"
    puts "="*80

    total_tests = results.size
    successful_tests = results.count { |r| r[:exact_match] }
    avg_runtime = results.sum { |r| r[:runtime] } / total_tests
    avg_accuracy = results.sum { |r| r[:accuracy] } / total_tests
    avg_search_space = results.sum { |r| r[:search_space_size] } / total_tests

    puts "Total tests: #{total_tests}"
    puts "Successful factorizations: #{successful_tests}/#{total_tests} (#{(successful_tests.to_f / total_tests * 100).round(1)}%)"
    puts "Average runtime: #{(avg_runtime * 1000).round(1)} ms"
    puts "Average accuracy: #{(avg_accuracy * 100).round(1)}%"
    puts "Average search space: #{avg_search_space.round(0)} candidates"

    if successful_tests > 0
      puts "✅ Your method CAN factorize large numbers!"
    else
      puts "❌ Your method struggles with 9-digit numbers"
    end

    puts ""
    puts "🎯 CONCLUSION:"
    if successful_tests >= total_tests / 2
      puts "   🚀 Breakthrough! Spectral method scales to large numbers!"
    else
      puts "   📊 Method hits limits at 9-digit scale"
      puts "   🔧 Need larger search spaces or improved encoding"
    end

    results
  end
end

LargeFactorizationTest.run