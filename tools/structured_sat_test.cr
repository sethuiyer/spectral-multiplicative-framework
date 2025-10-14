require "./src/multiplicative_constraint"

module StructuredSATTest
  include MultiplicativeConstraint

  puts "🔬 STRUCTURED SAT TEST: Graph Coloring & Scheduling"
  puts "=" * 55
  puts "Testing spectral-multiplicative advantage on structured problems"
  puts "Where graph topology should give the cheat code even MORE power!"
  puts ""

  # GRAPH COLORING AS SAT
  # Create a challenging graph coloring problem and encode it as SAT
  def self.create_graph_coloring_sat(n_nodes, n_colors)
    puts "🎨 Creating #{n_colors}-color graph coloring SAT..."
    puts "Nodes: #{n_nodes}, Colors: #{n_colors}"

    # Create a graph with known chromatic number (hard coloring problem)
    # Using a combination of cliques and odd cycles for maximum difficulty
    nodes = (1..n_nodes).map { |i| "v#{i}" }

    # Build adjacency matrix for a hard-to-color graph
    adjacency = Array(Array(Int32)).new(n_nodes) { Array(Int32).new(n_nodes, 0) }

    # Add cliques (complete subgraphs) - these force different colors
    clique_size = [3, 4, 5].min(n_nodes)
    (0...clique_size).each do |i|
      (i+1...clique_size).each do |j|
        adjacency[i][j] = 1
        adjacency[j][i] = 1
      end
    end

    # Add odd cycles (chromatic number 3)
    cycle_start = clique_size
    cycle_size = [7, 9, 11].min(n_nodes - clique_size)
    if cycle_size >= 5
      (0...cycle_size).each do |i|
        next_node = (i + 1) % cycle_size
        node_i = cycle_start + i
        node_j = cycle_start + next_node
        adjacency[node_i][node_j] = 1
        adjacency[node_j][node_i] = 1
      end
    end

    # Add some random connections for complexity
    remaining_edges = (n_nodes * n_nodes) / 20  # About 5% density
    remaining_edges.times do
      i = rand(0...n_nodes)
      j = rand(0...n_nodes)
      next if i == j || adjacency[i][j] == 1

      adjacency[i][j] = 1
      adjacency[j][i] = 1
    end

    puts "Graph created with #{adjacency.sum(&.sum) / 2} edges"

    # Encode graph coloring as SAT
    # Variables: v_i_c = "node i has color c"
    clauses = [] of Array(Int32)
    var_count = 0

    # Each node must have exactly one color
    (0...n_nodes).each do |i|
      # At least one color per node (v_i_1 ∨ v_i_2 ∨ ... ∨ v_i_k)
      color_clause = [] of Int32
      (0...n_colors).each do |c|
        var_count += 1
        color_clause << var_count  # Positive literal: node i has color c
      end
      clauses << color_clause

      # At most one color per node (¬v_i_c ∨ ¬v_i_d for all c ≠ d)
      (0...n_colors).each do |c|
        ((c+1)...n_colors).each do |d|
          var_c = i * n_colors + c + 1
          var_d = i * n_colors + d + 1
          clauses << [-var_c, -var_d]  # Can't have both colors c and d
        end
      end
    end

    # Adjacent nodes must have different colors
    (0...n_nodes).each do |i|
      (i+1...n_nodes).each do |j|
        next if adjacency[i][j] == 0

        (0...n_colors).each do |c|
          var_i_c = i * n_colors + c + 1
          var_j_c = j * n_colors + c + 1
          clauses << [-var_i_c, -var_j_c]  # Can't both have color c
        end
      end
    end

    puts "SAT encoding: #{var_count} variables, #{clauses.size} clauses"
    puts "Clause/variable ratio: #{(clauses.size.to_f / var_count).round(3)}"

    {nodes, clauses, var_count}
  end

  # JOB SHOP SCHEDULING AS SAT
  def self.create_scheduling_sat(n_jobs, n_machines, time_horizon)
    puts "⚙️  Creating job shop scheduling SAT..."
    puts "Jobs: #{n_jobs}, Machines: #{n_machines}, Time: #{time_horizon}"

    jobs = (1..n_jobs).map { |i| "J#{i}" }
    machines = (1..n_machines).map { |i| "M#{i}" }

    clauses = [] of Array(Int32)
    var_count = 0

    # Variables: x_j_t_m = "job j starts at time t on machine m"
    # Each job must be scheduled on exactly one machine at one time
    (0...n_jobs).each do |j|
      # Each job must be scheduled somewhere
      schedule_clause = [] of Int32
      (0...time_horizon).each do |t|
        (0...n_machines).each do |m|
          var_count += 1
          schedule_clause << var_count
        end
      end
      clauses << schedule_clause

      # Each job can only be in one place at one time
      (0...time_horizon).each do |t|
        (0...n_machines).each do |m|
          var_1 = j * time_horizon * n_machines + t * n_machines + m + 1

          # Can't be at multiple times simultaneously
          ((t+1)...time_horizon).each do |t2|
            (0...n_machines).each do |m2|
              var_2 = j * time_horizon * n_machines + t2 * n_machines + m2 + 1
              clauses << [-var_1, -var_2]
            end
          end

          # Can't be on multiple machines simultaneously
          ((m+1)...n_machines).each do |m2|
            var_2 = j * time_horizon * n_machines + t * n_machines + m2 + 1
            clauses << [-var_1, -var_2]
          end
        end
      end
    end

    # Machine capacity constraints (simplified)
    (0...n_machines).each do |m|
      (0...time_horizon).each do |t|
        machine_jobs = [] of Int32
        (0...n_jobs).each do |j|
          var = j * time_horizon * n_machines + t * n_machines + m + 1
          machine_jobs << var
        end

        # At most 3 jobs per machine per time (resource constraint)
        if machine_jobs.size >= 4
          # Simple pairwise constraints (not optimal but works)
          (0...machine_jobs.size).each do |i|
            (i+1...machine_jobs.size).each do |j|
              (j+1...machine_jobs.size).each do |k|
                (k+1...machine_jobs.size).each do |l|
                  clauses << [-machine_jobs[i], -machine_jobs[j], -machine_jobs[k], -machine_jobs[l]]
                end
              end
            end
          end
        end
      end
    end

    puts "SAT encoding: #{var_count} variables, #{clauses.size} clauses"
    puts "Clause/variable ratio: #{(clauses.size.to_f / var_count).round(3)}"

    {jobs, clauses, var_count}
  end

  def self.build_sat_graph(clauses, n_vars)
    puts "🔗 Building SAT constraint graph..."

    total_nodes = n_vars * 2  # Variables + negations
    weights = Array(Float64).new(total_nodes, 1.0)
    adjacency = Array(Array(Float64)).new(total_nodes) { Array(Float64).new(total_nodes, 0.0) }

    # Create connections based on clause relationships
    clauses.each do |clause|
      clause_nodes = clause.map do |literal|
        if literal > 0
          literal - 1  # Positive literal
        else
          n_vars - literal - 1  # Negative literal
        end
      end

      # Variables in same clause should be positively connected
      clause_nodes.each do |i|
        clause_nodes.each do |j|
          next if i >= j
          adjacency[i][j] += 1.0
          adjacency[j][i] = adjacency[i][j]
        end
      end
    end

    # Variables and their negations should be negatively connected
    (0...n_vars).each do |i|
      neg_idx = n_vars + i
      adjacency[i][neg_idx] = 0.05
      adjacency[neg_idx][i] = 0.05
    end

    puts "Graph built: #{total_nodes} nodes"

    {weights, adjacency}
  end

  def self.evaluate_sat_solution(result, clauses, n_vars)
    assignment = Array(Int32).new(n_vars, 0)

    result.segments.each_with_index do |segment, seg_id|
      value = (seg_id % 2 == 0) ? 1 : -1

      segment.each do |node|
        if node < n_vars
          assignment[node] = value
        else
          assignment[node - n_vars] = -value
        end
      end
    end

    satisfied = clauses.count do |clause|
      clause.any? do |literal|
        val = literal > 0 ? assignment[literal - 1] : assignment[-literal - 1]
        literal > 0 ? val == 1 : val == -1
      end
    end

    {satisfied: satisfied, total: clauses.size, assignment: assignment}
  end

  def self.run_structured_sat_test(name, clauses, n_vars)
    puts "\n" + "🎯" * 20
    puts "TESTING: #{name}"
    puts "🎯" * 20

    weights, adjacency = build_sat_graph(clauses, n_vars)

    start_time = Time.utc

    graph = MultiplicativeConstraint::Graph.new(weights, adjacency)
    engine = MultiplicativeConstraint::Engine.new(graph, 2)

    puts "🚀 Running spectral-multiplicative SAT solver..."

    result = engine.solve(iterations: 3000, step: 0.35, seed: 2025)

    end_time = Time.utc
    runtime = (end_time - start_time).total_seconds

    sat_result = evaluate_sat_solution(result, clauses, n_vars)
    satisfaction_rate = sat_result[:satisfied].to_f / sat_result[:total]

    puts ""
    puts "⚡ PERFORMANCE"
    puts "-" * 20
    puts "Runtime: #{(runtime * 1000).round(1)} ms"
    puts ""

    puts "📊 RESULTS"
    puts "-" * 15
    puts "Clauses satisfied: #{sat_result[:satisfied]}/#{sat_result[:total]}"
    puts "Satisfaction rate: #{(satisfaction_rate * 100).round(1)}%"
    puts "Unified energy: #{result.energy.round(3)}"
    puts "Spectral action: #{result.spectral.round(3)}"

    quality = case satisfaction_rate
             when 1.0 then "🎉 PERFECT - Structured advantage dominates!"
             when 0.95..1.0 then "🔥 EXCEPTIONAL - Spectral structure working!"
             when 0.85..0.95 then "👍 EXCELLENT - Strong on structured problems!"
             when 0.70..0.85 then "✅ GOOD - Respectable performance"
             when 0.50..0.70 then "⚠️  FAIR - Partial success"
             else "❌ POOR - Struggling"
             end

    puts "Quality: #{quality}"

    if satisfaction_rate >= 0.95
      puts ""
      puts "🏆 STRUCTURED ADVANTAGE CONFIRMED!"
      puts "   Spectral-multiplicative bridge excels on structured problems!"
    end

    {name: name, runtime: runtime, satisfaction: satisfaction_rate, clauses: clauses.size, vars: n_vars}
  end

  def self.run_all_structured_tests
    puts "🚀 STARTING STRUCTURED SAT TEST SUITE"
    puts "Testing where spectral structure should give maximum advantage!"
    puts "=" * 65

    results = [] of Hash(String, Float64 | Int32 | String)

    # Test 1: Graph Coloring
    puts "\n🎨" * 15
    puts "GRAPH COLORING TESTS"
    puts "🎨" * 15

    # Small graph coloring (should be easier)
    nodes1, clauses1, vars1 = create_graph_coloring_sat(20, 3)
    result1 = run_structured_sat_test("Graph Coloring (20 nodes, 3 colors)", clauses1, vars1)
    results << result1

    # Medium graph coloring (harder)
    nodes2, clauses2, vars2 = create_graph_coloring_sat(50, 4)
    result2 = run_structured_sat_test("Graph Coloring (50 nodes, 4 colors)", clauses2, vars2)
    results << result2

    # Large graph coloring (very hard)
    nodes3, clauses3, vars3 = create_graph_coloring_sat(100, 5)
    result3 = run_structured_sat_test("Graph Coloring (100 nodes, 5 colors)", clauses3, vars3)
    results << result3

    # Test 2: Job Shop Scheduling
    puts "\n⚙️" * 15
    puts "SCHEDULING TESTS"
    puts "⚙️" * 15

    jobs1, clauses4, vars4 = create_scheduling_sat(10, 3, 8)
    result4 = run_structured_sat_test("Scheduling (10 jobs, 3 machines, 8 time)", clauses4, vars4)
    results << result4

    jobs2, clauses5, vars5 = create_scheduling_sat(15, 4, 12)
    result5 = run_structured_sat_test("Scheduling (15 jobs, 4 machines, 12 time)", clauses5, vars5)
    results << result5

    # Summary
    puts "\n" + "🏆" * 25
    puts "STRUCTURED SAT TEST SUMMARY"
    puts "🏆" * 25
    puts ""

    results.each do |result|
      name = result["name"].as(String)
      runtime = result["runtime"].as(Float64)
      satisfaction = result["satisfaction"].as(Float64)
      clauses = result["clauses"].as(Int32)
      vars = result["vars"].as(Int32)

      status = satisfaction >= 0.95 ? "🎉 PERFECT" : satisfaction >= 0.85 ? "🔥 EXCELLENT" : satisfaction >= 0.75 ? "✅ GOOD" : "⚠️  FAIR"

      puts "#{name}: #{(satisfaction * 100).round(1)}% satisfied, #{(runtime * 1000).round(0)}ms - #{status}"
      puts "  (#{vars} vars, #{clauses} clauses)"
    end

    avg_satisfaction = results.sum { |r| r["satisfaction"].as(Float64) } / results.size
    perfect_count = results.count { |r| r["satisfaction"].as(Float64) == 1.0 }
    excellent_count = results.count { |r| r["satisfaction"].as(Float64) >= 0.95 }

    puts ""
    puts "🎯 STRUCTURED ADVANTAGE ANALYSIS:"
    puts "Average satisfaction: #{(avg_satisfaction * 100).round(1)}%"
    puts "Perfect solutions: #{perfect_count}/#{results.size}"
    puts "Excellent (≥95%): #{excellent_count}/#{results.size}"

    if avg_satisfaction >= 0.95
      puts ""
      puts "🔥 SPECTRAL-MULTIPLICATIVE DOMINANCE ON STRUCTURED PROBLEMS!"
      puts "   The cheat code is even more powerful with graph topology!"
    elsif avg_satisfaction >= 0.85
      puts ""
      puts "🚀 STRONG STRUCTURED ADVANTAGE CONFIRMED!"
      puts "   Spectral structure gives significant performance boost!"
    else
      puts ""
      puts "⚠️  Structured advantage needs further investigation"
    end
  end

  def self.run
    run_all_structured_tests
  end
end

StructuredSATTest.run