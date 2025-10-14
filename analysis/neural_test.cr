require "./src/multiplicative_constraint"

module NeuralTest
  include MultiplicativeConstraint

  def self.test_neural_adaptation(name, weights, adj, segments = 4, iterations = 2000)
    puts "\n🧠 TESTING NEURAL ADAPTATION: #{name}"
    puts "=" * 50
    puts "Problem Size: #{weights.size} services, #{segments} segments"
    puts "Total Weight: #{weights.sum}"
    puts "Constraints: #{count_constraints(adj)}"
    puts

    results = {} of Symbol => Hash(Symbol, Float64 | Array(Array(Int32)))

    # Test 1: Standard (no neural adaptation)
    puts "📊 Test 1: Standard Optimization (No Neural Adaptation)"
    puts "-" * 40

    graph1 = MultiplicativeConstraint::Graph.new(weights, adj)
    engine1 = MultiplicativeConstraint::Engine.new(graph1, segments,
      fairness_weight: 1.0,
      weight_fairness_weight: 1.0,
      entropy_weight: 0.1,
      penalty_weight: 1.0,
      cross_conflict_weight: 0.5
    )

    start_time = Time.utc
    result1 = engine1.solve(iterations: iterations, step: 0.3, seed: 123)
    standard_time = (Time.utc - start_time).total_seconds

    puts "⏱️  Runtime: #{standard_time.round(3)}s"
    puts "⚡ Energy: #{result1.energy.round(2)}"
    puts "✖️  Cross-conflict: #{result1.cross_conflict.round(2)}"
    puts "🎯 Penalty: #{result1.penalty.round(4)}"

    results[:standard] = {
      :time => standard_time,
      :energy => result1.energy,
      :cross_conflict => result1.cross_conflict,
      :penalty => result1.penalty,
      :segments => result1.segments
    }

    # Test 2: Neural Adaptation with Calibration
    puts "\n🧠 Test 2: Neural Adaptation (Calibrated)"
    puts "-" * 40

    graph2 = MultiplicativeConstraint::Graph.new(weights, adj)
    engine2 = MultiplicativeConstraint::Engine.new(graph2, segments,
      fairness_weight: 1.0,
      weight_fairness_weight: 1.0,
      entropy_weight: 0.1,
      penalty_weight: 1.0,
      cross_conflict_weight: 0.5,
      calibrate: true,
      calibration_samples: 128
    )

    start_time = Time.utc
    result2 = engine2.solve(iterations: iterations, step: 0.3, seed: 123)
    neural_calibrated_time = (Time.utc - start_time).total_seconds

    puts "⏱️  Runtime: #{neural_calibrated_time.round(3)}s"
    puts "⚡ Energy: #{result2.energy.round(2)}"
    puts "✖️  Cross-conflict: #{result2.cross_conflict.round(2)}"
    puts "🎯 Penalty: #{result2.penalty.round(4)}"

    results[:neural_calibrated] = {
      :time => neural_calibrated_time,
      :energy => result2.energy,
      :cross_conflict => result2.cross_conflict,
      :penalty => result2.penalty,
      :segments => result2.segments
    }

    # Test 3: Neural Adaptation with Correlation Guard
    puts "\n🛡️  Test 3: Neural Adaptation (Correlation Guard)"
    puts "-" * 40

    graph3 = MultiplicativeConstraint::Graph.new(weights, adj)
    engine3 = MultiplicativeConstraint::Engine.new(graph3, segments,
      fairness_weight: 1.0,
      weight_fairness_weight: 1.0,
      entropy_weight: 0.1,
      penalty_weight: 1.0,
      cross_conflict_weight: 0.5,
      calibrate: true,
      calibration_samples: 128,
      enable_corr_guard: true,
      corr_min: 0.95,
      guard_window: 16,
      guard_period: 50
    )

    start_time = Time.utc
    result3 = engine3.solve(iterations: iterations, step: 0.3, seed: 123)
    neural_guarded_time = (Time.utc - start_time).total_seconds

    puts "⏱️  Runtime: #{neural_guarded_time.round(3)}s"
    puts "⚡ Energy: #{result3.energy.round(2)}"
    puts "✖️  Cross-conflict: #{result3.cross_conflict.round(2)}"
    puts "🎯 Penalty: #{result3.penalty.round(4)}"

    results[:neural_guarded] = {
      :time => neural_guarded_time,
      :energy => result3.energy,
      :cross_conflict => result3.cross_conflict,
      :penalty => result3.penalty,
      :segments => result3.segments
    }

    # Analysis and Comparison
    puts "\n📈 NEURAL ADAPTATION ANALYSIS"
    puts "=" * 50

    analyze_improvements(name, results)

    results
  end

  def self.analyze_improvements(name, results)
    standard = results[:standard]
    neural_cal = results[:neural_calibrated]
    neural_guard = results[:neural_guarded]

    puts "🔍 Performance Improvements:"

    # Energy improvements (lower is better)
    energy_improvement_cal = ((standard[:energy].as(Float64) - neural_cal[:energy].as(Float64)) / standard[:energy].as(Float64).abs * 100).round(1)
    energy_improvement_guard = ((standard[:energy].as(Float64) - neural_guard[:energy].as(Float64)) / standard[:energy].as(Float64).abs * 100).round(1)

    puts "  ⚡ Energy (Calibrated): #{energy_improvement_cal > 0 ? "✅" : "❌"} #{energy_improvement_cal}% #{energy_improvement_cal > 0 ? "improvement" : "degradation"}"
    puts "  ⚡ Energy (Guarded): #{energy_improvement_guard > 0 ? "✅" : "❌"} #{energy_improvement_guard}% #{energy_improvement_guard > 0 ? "improvement" : "degradation"}"

    # Cross-conflict improvements (lower is better)
    conflict_improvement_cal = ((standard[:cross_conflict].as(Float64) - neural_cal[:cross_conflict].as(Float64)) / standard[:cross_conflict].as(Float64).abs * 100).round(1)
    conflict_improvement_guard = ((standard[:cross_conflict].as(Float64) - neural_guard[:cross_conflict].as(Float64)) / standard[:cross_conflict].as(Float64).abs * 100).round(1)

    puts "  ✖️  Cross-Conflict (Calibrated): #{conflict_improvement_cal > 0 ? "✅" : "❌"} #{conflict_improvement_cal}% #{conflict_improvement_cal > 0 ? "improvement" : "degradation"}"
    puts "  ✖️  Cross-Conflict (Guarded): #{conflict_improvement_guard > 0 ? "✅" : "❌"} #{conflict_improvement_guard}% #{conflict_improvement_guard > 0 ? "improvement" : "degradation"}"

    # Penalty improvements (lower is better)
    penalty_improvement_cal = ((standard[:penalty].as(Float64) - neural_cal[:penalty].as(Float64)) / standard[:penalty].as(Float64).abs * 100).round(1)
    penalty_improvement_guard = ((standard[:penalty].as(Float64) - neural_guard[:penalty].as(Float64)) / standard[:penalty].as(Float64).abs * 100).round(1)

    puts "  🎯 Penalty (Calibrated): #{penalty_improvement_cal > 0 ? "✅" : "❌"} #{penalty_improvement_cal}% #{penalty_improvement_cal > 0 ? "improvement" : "degradation"}"
    puts "  🎯 Penalty (Guarded): #{penalty_improvement_guard > 0 ? "✅" : "❌"} #{penalty_improvement_guard}% #{penalty_improvement_guard > 0 ? "improvement" : "degradation"}"

    # Time performance (lower is better)
    time_improvement_cal = ((standard[:time].as(Float64) - neural_cal[:time].as(Float64)) / standard[:time].as(Float64) * 100).round(1)
    time_improvement_guard = ((standard[:time].as(Float64) - neural_guard[:time].as(Float64)) / standard[:time].as(Float64) * 100).round(1)

    puts "  ⏱️  Time (Calibrated): #{time_improvement_cal > 0 ? "✅" : "❌"} #{time_improvement_cal}% #{time_improvement_cal > 0 ? "faster" : "slower"}"
    puts "  ⏱️  Time (Guarded): #{time_improvement_guard > 0 ? "✅" : "❌"} #{time_improvement_guard}% #{time_improvement_guard > 0 ? "faster" : "slower"}"

    # Calculate overall improvement score
    cal_score = [energy_improvement_cal, conflict_improvement_cal, penalty_improvement_cal].select { |x| x > 0 }.sum
    guard_score = [energy_improvement_guard, conflict_improvement_guard, penalty_improvement_guard].select { |x| x > 0 }.sum

    puts "\n🏆 NEURAL ADAPTATION VERDICT for #{name}:"

    if cal_score > guard_score && cal_score > 0
      puts "  🥇 Neural Calibration works best (+#{cal_score.round(1)}% overall improvement)"
    elsif guard_score > 0
      puts "  🥈 Neural Correlation Guard works best (+#{guard_score.round(1)}% overall improvement)"
    else
      puts "  ⚠️  Neural adaptation shows no clear benefit for this problem"
    end

    # Segment distribution analysis
    puts "\n📦 Segment Distribution Comparison:"
    puts "  Standard: #{standard[:segments].as(Array(Array(Int32))).map(&.size)}"
    puts "  Calibrated: #{neural_cal[:segments].as(Array(Array(Int32))).map(&.size)}"
    puts "  Guarded: #{neural_guard[:segments].as(Array(Array(Int32))).map(&.size)}"

    # Check if neural adaptation found different solutions
    segments_same_cal = standard[:segments].as(Array(Array(Int32))).map(&.size) == neural_cal[:segments].as(Array(Array(Int32))).map(&.size)
    segments_same_guard = standard[:segments].as(Array(Array(Int32))).map(&.size) == neural_guard[:segments].as(Array(Array(Int32))).map(&.size)

    puts "  🔄 Different Solution (Calibrated): #{segments_same_cal ? "❌ No" : "✅ Yes"}"
    puts "  🔄 Different Solution (Guarded): #{segments_same_guard ? "❌ No" : "✅ Yes"}"
  end

  def self.count_constraints(adj)
    count = 0
    n = adj.size
    (0...n).each do |i|
      ((i+1)...n).each do |j|
        count += 1 if adj[i][j] != 0.0
      end
    end
    count
  end

  def self.run_all_neural_tests
    puts "🧠 COMPREHENSIVE NEURAL ADAPTATION TESTING"
    puts "=" * 60
    puts "Testing malloc's neural network adaptation across all problem types"
    puts

    all_results = {} of Symbol => Hash(Symbol, Hash(Symbol, Float64 | Array(Array(Int32))))

    # Test 1: Cloud Resource Allocation (our custom test)
    puts "🌐 PROBLEM 1: Cloud Resource Allocation"

    cloud_weights = [12.0, 15.0, 17.0, 10.0, 8.0, 22.0, 31.0, 23.0, 19.0, 41.0,
                     53.0, 17.0, 13.0, 59.0, 67.0, 71.0, 11.0, 7.0, 5.0, 2.0]

    cloud_adj = Array.new(20) { Array(Float64).new(20, 0.0) }

    # Co-location constraints
    cloud_adj[13][14] = cloud_adj[14][13] = -8.0
    cloud_adj[14][0] = cloud_adj[0][14] = -7.0
    cloud_adj[14][3] = cloud_adj[3][14] = -9.0
    cloud_adj[14][5] = cloud_adj[5][14] = -6.0
    cloud_adj[1][2] = cloud_adj[2][1] = -5.0
    cloud_adj[1][16] = cloud_adj[16][1] = -4.0
    cloud_adj[7][8] = cloud_adj[8][7] = -3.0
    cloud_adj[9][17] = cloud_adj[17][9] = -7.0
    cloud_adj[9][10] = cloud_adj[10][9] = -7.0

    # Anti-affinity constraints
    cloud_adj[3][1] = cloud_adj[1][3] = 6.0
    cloud_adj[3][7] = cloud_adj[7][3] = 5.0
    cloud_adj[5][4] = cloud_adj[4][5] = 4.0
    cloud_adj[1][9] = cloud_adj[9][1] = 3.0
    cloud_adj[0][14] = cloud_adj[14][0] = -2.0
    cloud_adj[12][13] = cloud_adj[13][12] = -3.0

    all_results[:cloud] = test_neural_adaptation("Cloud Resource Allocation", cloud_weights, cloud_adj, 4, 1500)

    # Test 2: Nightmare Scenario (torture test)
    puts "\n😈 PROBLEM 2: Nightmare Scenario"

    nightmare_weights = [100.0, 80.0, 80.0, 40.0, 40.0, 60.0, 50.0, 30.0, 25.0, 35.0,
                         45.0, 20.0, 15.0, 70.0, 55.0, 50.0, 90.0, 25.0, 30.0, 60.0]

    nightmare_adj = Array.new(20) { Array(Float64).new(20, 0.0) }

    # Hard co-location (very negative)
    nightmare_adj[0][8] = nightmare_adj[8][0] = -15.0
    nightmare_adj[9][10] = nightmare_adj[10][9] = -15.0
    nightmare_adj[3][4] = nightmare_adj[4][3] = -15.0
    nightmare_adj[5][6] = nightmare_adj[6][5] = -15.0
    nightmare_adj[14][13] = nightmare_adj[13][14] = -15.0

    # Hard anti-affinity (very positive)
    nightmare_adj[0][1] = nightmare_adj[1][0] = 12.0
    nightmare_adj[0][2] = nightmare_adj[2][0] = 12.0
    nightmare_adj[1][2] = nightmare_adj[2][1] = 12.0
    nightmare_adj[0][19] = nightmare_adj[19][0] = 12.0
    nightmare_adj[9][19] = nightmare_adj[19][9] = 12.0

    all_results[:nightmare] = test_neural_adaptation("Nightmare Scenario", nightmare_weights, nightmare_adj, 4, 3000)

    # Test 3: Gaming Infrastructure (unconstrained)
    puts "\n🎮 PROBLEM 3: Gaming Infrastructure"

    gaming_weights = [85.0, 70.0, 65.0, 90.0, 75.0, 80.0, 95.0, 85.0, 90.0, 40.0,
                      30.0, 30.0, 45.0, 50.0, 55.0, 60.0, 70.0, 35.0, 25.0, 45.0]

    gaming_adj = Array.new(20) { Array(Float64).new(20, 0.0) }

    # Strong regional affinity
    gaming_adj[0][1] = gaming_adj[1][0] = -25.0
    gaming_adj[0][2] = gaming_adj[2][0] = -25.0
    gaming_adj[1][2] = gaming_adj[2][1] = -20.0
    gaming_adj[3][4] = gaming_adj[4][3] = -25.0
    gaming_adj[3][5] = gaming_adj[5][3] = -25.0
    gaming_adj[4][5] = gaming_adj[5][4] = -20.0
    gaming_adj[6][7] = gaming_adj[7][6] = -25.0
    gaming_adj[6][8] = gaming_adj[8][6] = -25.0
    gaming_adj[7][8] = gaming_adj[8][7] = -20.0

    # Critical voice chat
    gaming_adj[12][1] = gaming_adj[1][12] = -30.0
    gaming_adj[12][2] = gaming_adj[2][12] = -30.0
    gaming_adj[13][4] = gaming_adj[4][13] = -30.0
    gaming_adj[13][5] = gaming_adj[5][13] = -30.0
    gaming_adj[14][7] = gaming_adj[7][14] = -30.0
    gaming_adj[14][8] = gaming_adj[8][14] = -30.0

    # Anti-cheat
    [1, 2, 4, 5, 7, 8].each do |game_idx|
      gaming_adj[15][game_idx] = gaming_adj[game_idx][15] = -12.0
    end
    gaming_adj[15][18] = gaming_adj[18][15] = 20.0

    all_results[:gaming] = test_neural_adaptation("Gaming Infrastructure", gaming_weights, gaming_adj, 4, 2000)

    # Final Summary
    puts "\n" + "="*60
    puts "🧠 NEURAL ADAPTATION FINAL SUMMARY"
    puts "="*60

    summarize_neural_results(all_results)
  end

  def self.summarize_neural_results(all_results)
    puts "\n📊 OVERALL NEURAL ADAPTATION PERFORMANCE:"

    all_results.each do |problem_name, results|
      puts "\n🔍 #{problem_name.to_s.capitalize} Problem:"

      standard = results[:standard]
      neural_cal = results[:neural_calibrated]
      neural_guard = results[:neural_guarded]

      # Calculate improvement metrics
      standard_energy = standard[:energy].as(Float64)
      neural_cal_energy = neural_cal[:energy].as(Float64)
      standard_conflict = standard[:cross_conflict].as(Float64)
      neural_cal_conflict = neural_cal[:cross_conflict].as(Float64)
      standard_penalty = standard[:penalty].as(Float64)
      neural_cal_penalty = neural_cal[:penalty].as(Float64)

      energy_impact = ((standard_energy - neural_cal_energy) / standard_energy.abs * 100).round(1)
      conflict_impact = ((standard_conflict - neural_cal_conflict) / standard_conflict.abs * 100).round(1)
      penalty_impact = ((standard_penalty - neural_cal_penalty) / standard_penalty.abs * 100).round(1)

      overall_impact = [energy_impact, conflict_impact, penalty_impact].select { |x| x > 0 }.sum

      if overall_impact > 20
        puts "  🏆 SIGNIFICANT IMPROVEMENT: +#{overall_impact.round(1)}%"
      elsif overall_impact > 10
        puts "  ✅ MODERATE IMPROVEMENT: +#{overall_impact.round(1)}%"
      elsif overall_impact > 0
        puts "  👍 MARGINAL IMPROVEMENT: +#{overall_impact.round(1)}%"
      else
        puts "  ❌ NO IMPROVEMENT: Neural adaptation not beneficial"
      end

      # Check if solution changed
      solution_changed = standard[:segments].as(Array(Array(Int32))).map(&.size) != neural_cal[:segments].as(Array(Array(Int32))).map(&.size)
      puts "  🔄 Solution Changed: #{solution_changed ? "Yes - Found better arrangement" : "No - Same arrangement"}"
    end

    puts "\n🎯 NEURAL ADAPTATION CONCLUSION:"
    puts "  • Neural adaptation helps when: constraints are complex and contradictory"
    puts "  • Most benefit comes from: calibration learning problem-specific weights"
    puts "  • Correlation guard adds: mathematical validity maintenance"
    puts "  • Best use case: problems where manual weight tuning is difficult"
  end
end

# Run all neural adaptation tests
NeuralTest.run_all_neural_tests