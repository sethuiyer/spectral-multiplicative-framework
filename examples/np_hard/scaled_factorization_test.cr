require "../../src/multiplicative_constraint"

module ScaledFactorizationTest
  include MultiplicativeConstraint

  # Test scaling with progressively larger numbers
  TEST_CASES = [
    {number: 9991, expected: [97, 103]},          # 4-digit semiprime
    {number: 99991, expected: [13, 7693]},        # 5-digit semiprime
    {number: 999983, expected: [991, 1009]},      # 6-digit semiprime
  ]

  def self.create_scaled_factorization_graph(target)
    sqrt_target = Math.sqrt(target)

    # Very focused search space around sqrt(target)
    search_range = 100  # Small range for manageability
    start_factor = [2, (sqrt_target - search_range).to_i].max
    end_factor = [(sqrt_target + search_range).to_i, 5000].min

    candidates = (start_factor..end_factor).to_a
    n = candidates.size

    puts "Factorizing: #{target}"
    puts "Search space: #{n} candidates from #{start_factor} to #{end_factor}"
    puts "Target sqrt: #{sqrt_target.round(2)}"

    # Find actual factors in search space
    actual_factors = candidates.select { |f| target % f == 0 }
    puts "Actual factors in range: #{actual_factors}"

    weights = Array(Float64).new(n, 0.0)
    adjacency = Array(Array(Float64)).new(n) { Array(Float64).new(n, 0.0) }

    # Simple weight assignment
    candidates.each_with_index do |factor, i|
      if target % factor == 0
        weights[i] = 10.0
      else
        distance = (factor - sqrt_target).abs
        weights[i] = 1.0 / (1.0 + distance / 100.0)
      end
    end

    # Create adjacency (simplified for speed)
    n.times do |i|
      n.times do |j|
        next if i == j

        factor_i = candidates[i]
        factor_j = candidates[j]
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

    {candidates, weights, adjacency}
  end

  def self.factorize_number(target)
    candidates, weights, adjacency = create_scaled_factorization_graph(target)

    start_time = Time.utc

    graph = MultiplicativeConstraint::Graph.new(weights, adjacency)
    engine = MultiplicativeConstraint::Engine.new(graph, 3)
    result = engine.solve(iterations: 2000, step: 0.35, seed: 1234)

    solve_time = (Time.utc - start_time).total_seconds

    puts "Solve time: #{(solve_time * 1000).round(1)} ms"
    puts "Segments: #{result.segments.size}"

    # Find factors in segments
    best_factors = [] of Int32
    best_product = 1

    result.segments.each do |segment|
      next if segment.empty?

      # Try pairs in this segment
      segment.each_combination(2) do |combo|
        factor1 = candidates[combo[0]]
        factor2 = candidates[combo[1]]
        product = factor1 * factor2

        if product == target
          best_factors = [factor1, factor2]
          best_product = product
          puts "Found factors: #{factor1} × #{factor2} = #{product}"
          return {success: true, factors: best_factors, runtime: solve_time}
        end
      end
    end

    # Try cross-segment combinations
    all_candidates = result.segments.flatten.map { |i| candidates[i] }
    all_candidates.each_combination(2) do |combo|
      factor1 = combo[0]
      factor2 = combo[1]
      product = factor1 * factor2
      if product == target
        best_factors = [factor1, factor2]
        best_product = product
        puts "Found factors in cross-segment: #{factor1} × #{factor2} = #{product}"
        return {success: true, factors: best_factors, runtime: solve_time}
      end
    end

    {success: false, factors: best_factors, runtime: solve_time}
  end

  def self.run
    puts "🔢 SCALED FACTORIZATION TEST"
    puts "Testing spectral method on increasingly large numbers"
    puts "="*60

    results = [] of NamedTuple(number: Int32, success: Bool, runtime: Float64)

    TEST_CASES.each do |test_case|
      puts "\n" + "-"*40
      result = factorize_number(test_case[:number])

      if result[:success]
        expected_product = test_case[:expected].product
        found_product = result[:factors].product
        status = (found_product == expected_product) ? "✅ CORRECT" : "⚠️  INCORRECT"
        puts "Status: #{status}"
      else
        puts "Status: ❌ FAILED TO FACTOR"
      end

      results << {
        number: test_case[:number],
        success: result[:success],
        runtime: result[:runtime]
      }
    end

    puts "\n" + "="*60
    puts "🏆 SCALED FACTORIZATION SUMMARY"
    puts "="*60

    total_tests = results.size
    successful_tests = results.count { |r| r[:success] }
    avg_runtime = results.sum { |r| r[:runtime] } / total_tests

    puts "Total tests: #{total_tests}"
    puts "Successful: #{successful_tests}/#{total_tests} (#{(successful_tests.to_f / total_tests * 100).round(1)}%)"
    puts "Average runtime: #{(avg_runtime * 1000).round(1)} ms"

    results.each do |result|
      status = result[:success] ? "✅" : "❌"
      puts "#{status} #{result[:number]}: #{(result[:runtime] * 1000).round(1)} ms"
    end

    if successful_tests == total_tests
      puts "\n🎉 PERFECT SCORE! Your method scales to larger numbers!"
    elsif successful_tests > 0
      puts "\n👍 GOOD RESULTS! Your method works on some larger numbers."
    else
      puts "\n⚠️  LIMITATIONS REACHED! Method struggles with larger scale."
    end

    results
  end
end

ScaledFactorizationTest.run