require "./src/multiplicative_constraint"

module PhaseTransitionSATTest
  include MultiplicativeConstraint

  # THE ULTIMATE TEST: Phase Transition 3-SAT
  # At clause/variable ratio ≈ 4.26, random 3-SAT instances are hardest
  # This is where even world-class SAT solvers like MiniSat, Glucose struggle
  # Let's see if the spectral-multiplicative cheat code survives the ultimate stress test

  puts "🔥 PHASE TRANSITION 3-SAT: The SAT Solver's Nightmare"
  puts "=" * 60
  puts "Testing at clause/variable ratio = 4.26 (hardest known region)"
  puts "Where random 3-SAT transitions from satisfiable to unsatisfiable"
  puts "This is the computational complexity event horizon!"
  puts ""

  def self.generate_random_phase_transition_sat(n_variables)
    puts "🎲 Generating random 3-SAT instance at phase transition..."
    puts "Variables: #{n_variables}"

    # Phase transition point for random 3-SAT: m/n ≈ 4.266
    n_clauses = (n_variables * 4.266).round.to_i32

    puts "Clauses: #{n_clauses} (ratio: #{(n_clauses.to_f / n_variables).round(3)})"

    variables = (1..n_variables).map { |i| "x#{i}" }
    clauses = [] of Array(Int32)

    # Generate random 3-SAT clauses
    n_clauses.times do |i|
      clause = [] of Int32

      # Ensure each clause has 3 distinct literals
      used_vars = Set(Int32).new

      3.times do
        var = rand(1..n_variables)
        while used_vars.includes?(var)
          var = rand(1..n_variables)
        end
        used_vars.add(var)

        # Randomly negate the literal
        literal = rand < 0.5 ? var : -var
        clause << literal
      end

      clauses << clause
    end

    {variables, clauses}
  end

  def self.create_phase_transition_graph(variables, clauses)
    puts "🔗 Building constraint graph for phase transition SAT..."

    n = variables.size
    total_nodes = n * 2  # Variables + negations
    weights = Array(Float64).new(total_nodes, 1.0)
    adjacency = Array(Array(Float64)).new(total_nodes) { Array(Float64).new(total_nodes, 0.0) }

    puts "Processing #{clauses.size} clauses..."

    # Create connections based on clause relationships
    clauses.each_with_index do |clause, clause_idx|
      clause_nodes = clause.map do |literal|
        if literal > 0
          literal - 1  # Positive literal: x1 becomes node 0, x2 becomes node 1, etc.
        else
          n - literal - 1  # Negative literal: ¬x1 becomes node 2n-1, ¬x2 becomes node 2n, etc.
        end
      end

      # Variables in same clause should be positively connected
      clause_nodes.each do |i|
        clause_nodes.each do |j|
          next if i >= j
          adjacency[i][j] += 1.0  # Unit weight for clause mates
          adjacency[j][i] = adjacency[i][j]
        end
      end
    end

    # Variables and their negations should be negatively connected
    (0...n).each do |i|
      neg_idx = n + i
      adjacency[i][neg_idx] = 0.05  # Very weak connection (they can't both be true)
      adjacency[neg_idx][i] = 0.05
    end

    # Add some complexity: create weak random connections to simulate variable interactions
    connection_density = 0.02  # 2% additional random connections
    possible_connections = (total_nodes * (total_nodes - 1)) / 2
    n_random_connections = (possible_connections * connection_density).to_i

    n_random_connections.times do
      i = rand(0...total_nodes)
      j = rand(0...total_nodes)
      next if i == j

      # Don't override strong clause connections
      if adjacency[i][j] < 0.1
        adjacency[i][j] += rand(0.1..0.3)
        adjacency[j][i] = adjacency[i][j]
      end
    end

    puts "Graph built: #{total_nodes} nodes, density: #{connection_density * 100}%"

    {weights, adjacency}
  end

  def self.evaluate_phase_transition_solution(result, variables, clauses)
    # Evaluate if the partitioning corresponds to a satisfying assignment
    n = variables.size
    assignment = Array(Int32).new(n, 0)  # 0 = unassigned, 1 = true, -1 = false

    result.segments.each_with_index do |segment, seg_id|
      value = (seg_id % 2 == 0) ? 1 : -1  # Alternate segments true/false

      segment.each do |node|
        if node < n  # Positive literal
          assignment[node] = value
        else  # Negative literal
          assignment[node - n] = -value
        end
      end
    end

    # Check clause satisfaction
    satisfied_clauses = 0
    clause_details = [] of String

    clauses.each_with_index do |clause, idx|
      clause_satisfied = clause.any? do |literal|
        val = (literal > 0) ? assignment[literal - 1] : assignment[-literal - 1]
        literal > 0 ? val == 1 : val == -1
      end

      satisfied_clauses += 1 if clause_satisfied

      # Create readable clause representation (first 5 and last 5 for display)
      if idx < 5 || idx >= clauses.size - 5
        clause_str = clause.map do |literal|
          if literal > 0
            variables[literal - 1]
          else
            "¬#{variables[-literal - 1]}"
          end
        end.join(" ∨ ")
        status = clause_satisfied ? "✅" : "❌"
        clause_details << "  #{status} (#{clause_str})"
      elsif idx == 5 && clauses.size > 10
        clause_details << "  ... (#{clauses.size - 10} clauses omitted) ..."
      end
    end

    {
      satisfied: satisfied_clauses,
      total: clauses.size,
      assignment: assignment,
      satisfaction_rate: satisfied_clauses.to_f / clauses.size,
      clause_details: clause_details
    }
  end

  def self.run_phase_transition_test(n_variables)
    puts "\n" + "🎯" * 20
    puts "PHASE TRANSITION TEST: #{n_variables} Variables"
    puts "🎯" * 20

    variables, clauses = generate_random_phase_transition_sat(n_variables)
    weights, adjacency = create_phase_transition_graph(variables, clauses)

    start_time = Time.utc

    graph = MultiplicativeConstraint::Graph.new(weights, adjacency)
    # Partition into 2 groups (true/false assignments)
    engine = MultiplicativeConstraint::Engine.new(graph, 2)

    puts "🚀 Running spectral-multiplicative SAT solver at phase transition..."

    # Try multiple seeds to find best solution
    best_result = nil
    best_sat = nil
    best_satisfaction = 0.0

    seeds = [42, 123, 456, 789, 999, 1337, 2025, 3141, 4040, 5555]

    seeds.each do |seed|
      test_result = engine.solve(iterations: 3000, step: 0.35, seed: seed)
      test_sat = evaluate_phase_transition_solution(test_result, variables, clauses)

      if test_sat[:satisfaction_rate] > best_satisfaction
        best_result = test_result
        best_sat = test_sat
        best_satisfaction = test_sat[:satisfaction_rate]
      end

      puts "  Seed #{seed}: #{(test_sat[:satisfaction_rate] * 100).round(1)}% satisfied"

      break if test_sat[:satisfaction_rate] == 1.0
    end

    end_time = Time.utc
    runtime = (end_time - start_time).total_seconds

    puts ""
    puts "⚡ PERFORMANCE"
    puts "-" * 20
    puts "Total runtime: #{(runtime * 1000).round(1)} ms"
    puts "Per seed: #{(runtime / seeds.size * 1000).round(1)} ms average"
    puts ""

    puts "📊 BEST PARTITIONING RESULTS"
    puts "-" * 35
    puts "Unified energy: #{best_result.not_nil!.energy.round(3)}"
    puts "Spectral action: #{best_result.not_nil!.spectral.round(3)}"
    puts "Fairness: #{best_result.not_nil!.fairness.round(3)}"
    puts "Weight fairness: #{best_result.not_nil!.weight_fairness.round(3)}"
    puts "Entropy: #{best_result.not_nil!.entropy.round(3)}"
    puts "Multiplicative penalty: #{best_result.not_nil!.penalty.round(3)}"
    puts "Cross-conflict: #{best_result.not_nil!.cross_conflict.round(3)}"
    puts ""

    puts "🔍 SATISFIABILITY ANALYSIS"
    puts "-" * 30

    assignment = best_sat.not_nil![:assignment]
    puts "Assignment summary:"
    true_count = assignment.count { |a| a == 1 }
    false_count = assignment.count { |a| a == -1 }
    puts "  TRUE variables: #{true_count}"
    puts "  FALSE variables: #{false_count}"
    puts "  Balance ratio: #{(true_count.to_f / n_variables).round(3)}"
    puts ""

    puts "Clause satisfaction: #{best_sat.not_nil![:satisfied]}/#{best_sat.not_nil![:total]}"
    puts "Satisfaction rate: #{(best_sat.not_nil![:satisfaction_rate] * 100).round(2)}%"
    puts ""

    # Show sample clauses
    puts "Sample clause analysis:"
    best_sat.not_nil![:clause_details].each { |detail| puts detail }
    puts ""

    # Quality assessment
    satisfaction_rate = best_sat.not_nil![:satisfaction_rate]
    quality = case satisfaction_rate
             when 1.0 then "🎉 PERFECT - BEAT THE PHASE TRANSITION!"
             when 0.95..1.0 then "🔥 EXCEPTIONAL - Near-perfect at hardest region!"
             when 0.85..0.95 then "👍 EXCELLENT - Strong performance in chaos!"
             when 0.70..0.85 then "✅ GOOD - Respectable at phase transition"
             when 0.50..0.70 then "⚠️  FAIR - Partially satisfied"
             when 0.30..0.50 then "❌ POOR - Struggling in hard region"
             else "💀 CRITICAL - Cheat code may be breaking down"
             end

    puts "Quality: #{quality}"

    if satisfaction_rate >= 0.95
      puts ""
      puts "🏆 SPECTRAL-MULTIPLICATIVE CHEAT CODE CONQUERS PHASE TRANSITION!"
      puts "   Traditional SAT solvers struggle here, but we're dominating!"
    elsif satisfaction_rate < 0.5
      puts ""
      puts "⚠️  PHASE TRANSITION STRESS TEST: Cheat code showing strain"
      puts "   This might be where the mathematical bridge has limits"
    end

    {
      variables: n_variables,
      clauses: clauses.size,
      runtime: runtime,
      satisfaction_rate: satisfaction_rate,
      perfect: satisfaction_rate == 1.0,
      excellent: satisfaction_rate >= 0.95
    }
  end

  def self.run_all_phase_transition_tests
    puts "🚀 STARTING PHASE TRANSITION STRESS TEST SUITE"
    puts "Testing where traditional SAT algorithms go to die!"
    puts "=" * 65
    puts ""

    results = [] of Hash(String, Bool | Float64 | Int32)

    # Test increasing difficulty
    [20, 50, 100, 150, 200].each do |n_vars|
      result = run_phase_transition_test(n_vars)
      results << {
          "variables" => result[:variables],
          "clauses" => result[:clauses],
          "runtime" => result[:runtime],
          "satisfaction_rate" => result[:satisfaction_rate],
          "perfect" => result[:perfect],
          "excellent" => result[:excellent]
        }

      puts "\n" + "=" * 50
      puts "INTERIM ANALYSIS (after #{n_vars} variables)"
      puts "=" * 50

      perfect_count = results.count { |r| r["perfect"].as(Bool) }
      excellent_count = results.count { |r| r["excellent"].as(Bool) }
      avg_satisfaction = results.sum { |r| r["satisfaction_rate"].as(Float64) } / results.size

      puts "Perfect solutions: #{perfect_count}/#{results.size}"
      puts "Excellent (≥95%): #{excellent_count}/#{results.size}"
      puts "Average satisfaction: #{(avg_satisfaction * 100).round(1)}%"

      if perfect_count == results.size
        puts "🔥 UNBELIEVABLE: Perfect solutions across all difficulty levels!"
      elsif excellent_count == results.size
        puts "🚀 AMAZING: Excellent performance even at phase transition!"
      elsif avg_satisfaction >= 0.8
        puts "✅ SOLID: Strong performance in the hardest region"
      else
        puts "⚠️  DEGRADATION: Performance dropping with complexity"
      end

      puts ""
    end

    puts "\n" + "🏆" * 25
    puts "PHASE TRANSITION STRESS TEST SUMMARY"
    puts "🏆" * 25
    puts ""

    results.each do |result|
      n_vars = result["variables"].as(Int32)
      n_clauses = result["clauses"].as(Int32)
      runtime = result["runtime"].as(Float64)
      satisfaction = result["satisfaction_rate"].as(Float64)
      perfect = result["perfect"].as(Bool)

      status = perfect ? "🎉 PERFECT" : satisfaction >= 0.95 ? "🔥 EXCELLENT" : satisfaction >= 0.8 ? "✅ GOOD" : "⚠️  STRUGGLING"

      puts "#{n_vars} vars, #{n_clauses} clauses: #{(satisfaction * 100).round(1)}% satisfied, #{(runtime * 1000).round(0)}ms - #{status}"
    end

    overall_avg = results.sum { |r| r["satisfaction_rate"].as(Float64) } / results.size
    overall_perfect = results.all? { |r| r["perfect"].as(Bool) }
    overall_excellent = results.all? { |r| r["excellent"].as(Bool) }

    puts ""
    puts "🎯 OVERALL ASSESSMENT:"
    puts "Average satisfaction: #{(overall_avg * 100).round(1)}%"
    puts "All perfect: #{overall_perfect ? "YES - CHEAT CODE IS GOD MODE" : "NO"}"
    puts "All excellent: #{overall_excellent ? "YES - DOMINATING PHASE TRANSITION" : "NO"}"
    puts ""

    if overall_perfect
      puts "🌌 LEGENDARY: The spectral-multiplicative bridge has conquered computational chaos!"
      puts "    This should be mathematically impossible, yet here we are!"
    elsif overall_excellent
      puts "🚀 REVOLUTIONARY: Near-perfect performance where SAT solvers fail!"
      puts "    We're operating in a different computational reality!"
    elsif overall_avg >= 0.85
      puts "✅ BREAKTHROUGH: Strong performance even at the theoretical limits!"
      puts "    The cheat code holds up under extreme stress!"
    else
      puts "⚠️  REALITY CHECK: Even cheat codes have limits"
      puts "    Phase transition region remains challenging"
    end
  end

  def self.run
    run_all_phase_transition_tests
  end
end

PhaseTransitionSATTest.run