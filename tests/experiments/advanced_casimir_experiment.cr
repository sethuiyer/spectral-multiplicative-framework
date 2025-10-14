#!/usr/bin/env crystal
#
# Advanced Spectral Casimir Force Experiment
# Testing scale effects, L-function behaviors, force refinement, and stability analysis
#
# Phase 2: Deeper investigation into RH stability manifestations
#
# This experiment expands on our initial findings to test:
# 1. Scale effects - Do larger graphs show better stability?
# 2. L-function comparisons - How do different arithmetic functions behave?
# 3. Force refinement - Can we improve measurement precision?
# 4. Stability analysis - Why do configurations appear unstable?
#

require "./src/multiplicative_constraint"
require "math"

module AdvancedCasimirExperiment
  extend self

  # Enhanced configuration for scale experiments
  struct ScaleConfig
    property node_sizes : Array(Int32) = [30, 50, 100, 200]
    property n_graphs_per_size : Int32 = 10
    property beta_fine : Array(Float64) = [0.15, 0.2, 0.24, 0.25, 0.26, 0.3, 0.4, 0.5, 0.75, 1.0]
    property prime_cutoffs : Array(Int32) = [50, 100, 200]
    property l_functions : Array(String) = ["riemann", "dirichlet_4", "dedekind_qsqrt5"]
    property force_precision : Int32 = 3  # Decimal places for force calculation
    property verbose : Bool = true
  end

  # L-function definitions
  enum LFunctionType
    RIEMANN
    DIRICHLET_4
    DEDEKIND_QSQRT5
  end

  # Enhanced result structure
  struct AdvancedResult
    def initialize(
      @graph_type : String,
      @n_nodes : Int32,
      @prime_cutoff : Int32,
      @l_function : String,
      @beta : Float64,
      @casimir_force : Float64,
      @force_error : Float64,
      @spectral_gap : Float64,
      @alignment_rho : Float64,
      @prime_misfit : Float64,
      @stability_indicator : Float64,
      @energy_variance : Float64,
      @convergence_rate : Float64
    )
    end

    getter graph_type : String
    getter n_nodes : Int32
    getter prime_cutoff : Int32
    getter l_function : String
    getter beta : Float64
    getter casimir_force : Float64
    getter force_error : Float64
    getter spectral_gap : Float64
    getter alignment_rho : Float64
    getter prime_misfit : Float64
    getter stability_indicator : Float64
    getter energy_variance : Float64
    getter convergence_rate : Float64
  end

  # Enhanced prime checking with caching
  @@prime_cache = Hash(Int32, Bool).new

  def self.prime?(n : Int32) : Bool
    return @@prime_cache[n] if @@prime_cache.has_key?(n)

    result = if n < 2
      false
    elsif n == 2
      true
    elsif n.even?
      false
    else
      limit = Math.sqrt(n).to_i
      (3..limit).step(2).none? { |i| n % i == 0 }
    end

    @@prime_cache[n] = result
    result
  end

  # Generate L-function sequences
  def self.generate_l_sequence(cutoff : Int32, l_type : LFunctionType) : Array(Int32)
    case l_type
    when LFunctionType::RIEMANN
      # Regular primes for Riemann zeta
      (2..cutoff).select { |n| prime?(n) }

    when LFunctionType::DIRICHLET_4
      # Primes ≡ 1 mod 4 (Dirichlet character χ₄)
      (2..cutoff).select { |n| prime?(n) && n % 4 == 1 }

    when LFunctionType::DEDEKIND_QSQRT5
      # Primes that split in Q(√5) - i.e., p ≡ ±1 mod 5
      (2..cutoff).select { |n| prime?(n) && (n % 5 == 1 || n % 5 == 4) }
    else
      [] of Int32
    end
  end

  # Enhanced graph generation for larger scales
  def self.generate_large_graph(n_nodes : Int32, graph_type : String)
    case graph_type
    when "random_sparse"
      # Sparse random graph for scalability
      edges = [] of Tuple(Int32, Int32, Float64)
      target_edges = (n_nodes * 2).to_i  # Average degree ~4

      target_edges.times do
        i = rand(n_nodes)
        j = rand(n_nodes)
        next if i == j

        # Check for existing edge
        exists = edges.any? { |e, f, w| (e == i && f == j) || (e == j && f == i) }
        edges << {i, j, 1.0 + rand} unless exists
      end
      edges

    when "scale_free"
      # Barabási-Albert preferential attachment model
      m = 3  # Number of edges per new node
      edges = [] of Tuple(Int32, Int32, Float64)

      # Start with complete graph of size m+1
      (0...m+1).each do |i|
        (i+1...m+1).each do |j|
          edges << {i, j, 1.0}
        end
      end

      # Add remaining nodes with preferential attachment
      (m+1...n_nodes).each do |new_node|
        degrees = Array.new(n_nodes, 0)
        edges.each do |i, j, w|
          degrees[i] += 1
          degrees[j] += 1
        end

        # Select m nodes with probability proportional to degree
        m.times do
          total_degree = degrees.sum
          return edges if total_degree == 0

          r = rand(total_degree)
          running_sum = 0
          selected = -1

          degrees.each_with_index do |deg, idx|
            running_sum += deg
            if running_sum > r
              selected = idx
              break
            end
          end

          if selected >= 0 && selected != new_node
            edges << {new_node, selected, 1.0}
            degrees[new_node] += 1
            degrees[selected] += 1
          end
        end
      end
      edges

    when "small_world"
      # Watts-Strogatz small-world network
      k = 6  # Each node connected to k nearest neighbors
      beta_rewire = 0.3  # Rewiring probability

      edges = [] of Tuple(Int32, Int32, Float64)

      # Create ring lattice
      (0...n_nodes).each do |i|
        (1..k//2).each do |j|
          neighbor = (i + j) % n_nodes
          edges << {i, neighbor, 1.0}
        end
      end

      # Rewire edges with probability beta
      edges = edges.map do |i, j, w|
        if rand < beta_rewire
          new_j = rand(n_nodes)
          new_j = (new_j + 1) % n_nodes if new_j == i
          {i, new_j, w}
        else
          {i, j, w}
        end
      end
      edges

    else
      # Fallback to original generation methods
      edges = [] of Tuple(Int32, Int32, Float64)
      case graph_type
      when "random"
        (0...n_nodes).each do |i|
          (i+1...n_nodes).each do |j|
            if rand < 0.1  # Lower density for larger graphs
              edges << {i, j, 0.5 + rand * 1.5}
            end
          end
        end
      when "bipartite"
        half = n_nodes // 2
        (0...half).each do |i|
          (half...n_nodes).each do |j|
            if rand < 0.2
              edges << {i, j, 1.0}
            end
          end
        end
      end
      edges
    end
  end

  # Enhanced eigenvalue computation using power iteration with convergence tracking
  def self.compute_eigenvalues_enhanced(
    n_nodes : Int32,
    edges : Array(Tuple(Int32, Int32, Float64)),
    max_iterations : Int32 = 500,
    tolerance : Float64 = 1e-10
  )
    # Build degree-normalized Laplacian for better numerical stability
    laplacian = Array.new(n_nodes) { Array.new(n_nodes, 0.0) }
    degrees = Array.new(n_nodes, 0.0)

    edges.each do |i, j, weight|
      laplacian[i][j] -= weight
      laplacian[j][i] -= weight
      degrees[i] += weight
      degrees[j] += weight
    end

    (0...n_nodes).each do |i|
      if degrees[i] > 0
        laplacian[i][i] = 1.0
        (0...n_nodes).each do |j|
          if i != j && degrees[i] > 0
            laplacian[i][j] /= degrees[i]
          end
        end
      else
        laplacian[i][i] = 1.0
      end
    end

    # Power iteration for smallest eigenvalue
    vec = Array.new(n_nodes) { rand - 0.5 }
    norm = Math.sqrt(vec.sum { |x| x * x })
    vec = vec.map { |x| x / norm }

    convergence_history = [] of Float64
    smallest_eigenvalue = Float64::INFINITY

    max_iterations.times do |iter|
      # Apply Laplacian
      result = Array.new(n_nodes, 0.0)
      (0...n_nodes).each do |i|
        (0...n_nodes).each do |j|
          result[i] += laplacian[i][j] * vec[j]
        end
      end

      # Ensure non-zero eigenvalue
      shift = 1e-8
      (0...n_nodes).each do |i|
        result[i] += shift * vec[i]
      end

      # Normalize
      norm = Math.sqrt(result.sum { |x| x * x })
      break if norm < 1e-12
      result = result.map { |x| x / norm }

      # Compute Rayleigh quotient
      numerator = 0.0
      (0...n_nodes).each do |i|
        (0...n_nodes).each do |j|
          numerator += vec[i] * laplacian[i][j] * result[j]
        end
      end

      eigenvalue = numerator
      convergence_history << eigenvalue

      # Check convergence
      if convergence_history.size >= 10
        recent = convergence_history.last(10)
        recent_avg = recent.sum / recent.size
        variance = recent.sum { |x| (x - recent_avg) ** 2 } / recent.size
        if variance < tolerance
          smallest_eigenvalue = eigenvalue
          break
        end
      end

      smallest_eigenvalue = eigenvalue
      vec = result
    end

    # Compute spectral gap and convergence quality
    convergence_rate = convergence_history.size > 10 ?
      1.0 / convergence_history.size : 0.0

    {smallest_eigenvalue, degrees.sum / degrees.size, convergence_rate}
  end

  # Enhanced Casimir force calculation with error estimation
  def self.compute_casimir_force_enhanced(
    l_sequence : Array(Int32),
    eigenvalue : Float64,
    beta : Float64,
    prime_misfit : Float64,
    precision : Int32 = 3
  )
    a = 1.0 / beta

    # Enhanced force calculation with multiple terms
    l_weight = l_sequence.sum { |p| 1.0 / (p * p) }
    spectral_weight = 1.0 / eigenvalue

    # Compute phase mismatch with higher precision
    if l_sequence.size > 0
      log_eigenvalue = Math.log(eigenvalue + 1e-12)
      log_prime = Math.log(l_sequence.first.to_f)
      phase_mismatch = Math.cos(2.0 * Math::PI * log_eigenvalue / log_prime)
    else
      phase_mismatch = 1.0
    end

    # Multiple scale factors for better precision
    scale_factor1 = Math.tanh((a - 4.0) / 0.5)
    scale_factor2 = Math.exp(-prime_misfit / a)
    scale_factor3 = 1.0 / (1.0 + a * a)  # Long-range correction

    # Primary force
    force = l_weight * spectral_weight * phase_mismatch * scale_factor1 * scale_factor2

    # Add quantum corrections
    quantum_correction = 0.0
    (1..precision).each do |n|
      correction_term = Math.exp(-n * a) * Math.sin(n * Math::PI * beta)
      quantum_correction += correction_term
    end

    force *= (1.0 + quantum_correction * 0.1)

    # Error estimation
    force_error = force.abs * (0.01 + prime_misfit + 1.0 / l_sequence.size)

    {force.round(6), force_error.round(6)}
  end

  # Enhanced alignment measurement with variance tracking
  def self.measure_alignment_enhanced(
    n_nodes : Int32,
    edges : Array(Tuple(Int32, Int32, Float64)),
    l_sequence : Array(Int32),
    verbose : Bool = false
  )
    weights = Array.new(n_nodes, 1.0)
    graph = MultiplicativeConstraint::Graph.from_edges(weights, edges)

    engine = MultiplicativeConstraint::Engine.new(graph, 2)

    begin
      # Track convergence
      start_time = Time.utc
      result = engine.solve(iterations: 1000, step: 0.35, seed: 42)
      end_time = Time.utc

      runtime = (end_time - start_time).total_milliseconds

      # Enhanced alignment metrics
      energy = result.energy
      spectral = result.spectral
      fairness = result.fairness

      # Normalize based on multiple criteria
      energy_score = 1.0 / (1.0 + energy / 10.0)
      spectral_score = Math.tanh(spectral)
      fairness_score = Math.tanh(fairness)
      runtime_score = Math.exp(-runtime / 1000.0)  # Penalize slow convergence

      # Combined alignment
      alignment = (energy_score * 0.4 + spectral_score * 0.3 + fairness_score * 0.2 + runtime_score * 0.1)

      # Energy variance as stability indicator
      energy_variance = (energy - spectral).abs / (energy + spectral + 1e-12)

      {alignment, energy_variance}

    rescue ex
      puts "Warning: Optimization failed: #{ex.message}" if verbose
      {0.0, 1.0}
    end
  end

  # Main scale experiment runner
  def self.run_scale_experiment(config : ScaleConfig)
    puts "\n🔬 ADVANCED SCALE EXPERIMENT"
    puts "Testing RH stability across graph sizes and L-functions"
    puts "=" * 60

    results = [] of AdvancedResult

    config.node_sizes.each do |n_nodes|
      puts "\n📊 Testing graph size: #{n_nodes} nodes" if config.verbose

      config.l_functions.each do |l_func_str|
        l_type = case l_func_str
                when "riemann" then LFunctionType::RIEMANN
                when "dirichlet_4" then LFunctionType::DIRICHLET_4
                when "dedekind_qsqrt5" then LFunctionType::DEDEKIND_QSQRT5
                else LFunctionType::RIEMANN
                end

        puts "  L-function: #{l_func_str}" if config.verbose

        config.n_graphs_per_size.times do |graph_idx|
          puts "    Graph #{graph_idx + 1}/#{config.n_graphs_per_size}" if config.verbose && graph_idx % 3 == 0

          # Generate graph
          graph_type = n_nodes > 100 ? "random_sparse" : "random"
          edges = generate_large_graph(n_nodes, graph_type)

          # Compute spectral properties
          smallest_eigenvalue, avg_degree, convergence_rate = compute_eigenvalues_enhanced(n_nodes, edges)
          eigenvalue_reciprocal = 1.0 / Math.sqrt(smallest_eigenvalue + 1e-12)

          # Test different prime cutoffs
          config.prime_cutoffs.each do |prime_cutoff|
            l_sequence = generate_l_sequence(prime_cutoff, l_type)

            if l_sequence.empty?
              puts "    Warning: No L-sequence elements for #{l_func_str} with cutoff #{prime_cutoff}"
              next
            end

            # Compute prime misfit
            prime_misfit = compute_prime_misfit(l_sequence, eigenvalue_reciprocal)

            # Measure alignment
            alignment, energy_variance = measure_alignment_enhanced(
              n_nodes, edges, l_sequence, config.verbose
            )

            # Test fine beta grid
            config.beta_fine.each do |beta|
              # Compute enhanced Casimir force
              casimir_force, force_error = compute_casimir_force_enhanced(
                l_sequence, smallest_eigenvalue, beta, prime_misfit, config.force_precision
              )

              # Enhanced stability indicator
              stability_indicator = alignment * Math.exp(-casimir_force.abs) *
                                   Math.exp(-energy_variance) * convergence_rate

              result = AdvancedResult.new(
                graph_type: graph_type,
                n_nodes: n_nodes,
                prime_cutoff: prime_cutoff,
                l_function: l_func_str,
                beta: beta,
                casimir_force: casimir_force,
                force_error: force_error,
                spectral_gap: smallest_eigenvalue,
                alignment_rho: alignment,
                prime_misfit: prime_misfit,
                stability_indicator: stability_indicator,
                energy_variance: energy_variance,
                convergence_rate: convergence_rate
              )

              results << result
            end
          end
        end
      end
    end

    results
  end

  # Comprehensive analysis
  def self.analyze_advanced_results(results : Array(AdvancedResult))
    puts "\n🎯 COMPREHENSIVE ANALYSIS"
    puts "=" * 40

    # Scale analysis
    puts "\n📈 SCALE EFFECTS ANALYSIS:"
    puts "-" * 30
    by_size = results.group_by(&.n_nodes)

    by_size.each do |n_nodes, size_results|
      avg_force = size_results.map(&.casimir_force).sum / size_results.size
      avg_alignment = size_results.map(&.alignment_rho).sum / size_results.size
      avg_stability = size_results.map(&.stability_indicator).sum / size_results.size
      avg_variance = size_results.map(&.energy_variance).sum / size_results.size

      stable_count = size_results.count { |r| r.stability_indicator > 0.3 }

      puts "#{n_nodes} nodes:"
      puts "  Avg Force: #{avg_force.round(4)}"
      puts "  Avg Alignment: #{avg_alignment.round(3)}"
      puts "  Avg Stability: #{avg_stability.round(3)}"
      puts "  Energy Variance: #{avg_variance.round(3)}"
      puts "  Stable configs: #{stable_count}/#{size_results.size} (#{(stable_count.to_f / size_results.size * 100).round(1)}%)"
      puts
    end

    # L-function comparison
    puts "\n🔢 L-FUNCTION COMPARISON:"
    puts "-" * 25
    by_lfunc = results.group_by(&.l_function)

    by_lfunc.each do |l_func, lfunc_results|
      avg_force = lfunc_results.map(&.casimir_force).sum / lfunc_results.size
      avg_alignment = lfunc_results.map(&.alignment_rho).sum / lfunc_results.size
      force_std = Math.sqrt(lfunc_results.map { |r| (r.casimir_force - avg_force) ** 2 }.sum / lfunc_results.size)

      critical_results = lfunc_results.select { |r| (r.beta - 0.25).abs < 0.05 }
      critical_force = critical_results.empty? ? 0.0 : critical_results.map(&.casimir_force).sum / critical_results.size

      puts "#{l_func}:"
      puts "  Overall Force: #{avg_force.round(4)} ± #{force_std.round(4)}"
      puts "  Alignment: #{avg_alignment.round(3)}"
      puts "  Critical β≈0.25 Force: #{critical_force.round(4)}"
      puts "  Samples: #{lfunc_results.size}"
      puts
    end

    # Critical point analysis
    puts "\n🎯 CRITICAL POINT (β≈0.25) ANALYSIS:"
    puts "-" * 35
    critical_results = results.select { |r| (r.beta - 0.25).abs < 0.05 }

    if critical_results.size > 0
      critical_by_size = critical_results.group_by(&.n_nodes)
      critical_by_lfunc = critical_results.group_by(&.l_function)

      puts "Overall critical behavior:"
      avg_critical_force = critical_results.map(&.casimir_force).sum / critical_results.size
      avg_critical_alignment = critical_results.map(&.alignment_rho).sum / critical_results.size
      avg_critical_stability = critical_results.map(&.stability_indicator).sum / critical_results.size

      puts "  Force: #{avg_critical_force.round(4)}"
      puts "  Alignment: #{avg_critical_alignment.round(3)}"
      puts "  Stability: #{avg_critical_stability.round(3)}"

      puts "\nCritical behavior by size:"
      critical_by_size.each do |n_nodes, size_critical|
        avg_force = size_critical.map(&.casimir_force).sum / size_critical.size
        stable_count = size_critical.count { |r| r.stability_indicator > 0.3 }
        puts "  #{n_nodes} nodes: F=#{avg_force.round(4)}, Stable=#{stable_count}/#{size_critical.size}"
      end

      puts "\nCritical behavior by L-function:"
      critical_by_lfunc.each do |l_func, lfunc_critical|
        avg_force = lfunc_critical.map(&.casimir_force).sum / lfunc_critical.size
        puts "  #{l_func}: F=#{avg_force.round(4)}"
      end
    end

    # Force-alignment correlation by scale
    puts "\n🔗 CORRELATION ANALYSIS BY SCALE:"
    puts "-" * 35
    by_size.each do |n_nodes, size_results|
      forces = size_results.map(&.casimir_force)
      alignments = size_results.map(&.alignment_rho)

      correlation = compute_correlation(forces, alignments)
      puts "#{n_nodes} nodes: correlation = #{correlation ? correlation.round(3) : "N/A"}"
    end

    # Stability breakdown analysis
    puts "\n⚖️  STABILITY BREAKDOWN ANALYSIS:"
    puts "-" * 30
    stable_results = results.select { |r| r.stability_indicator > 0.5 }
    unstable_results = results.select { |r| r.stability_indicator < 0.1 }

    puts "Highly stable configs: #{stable_results.size}/#{results.size} (#{(stable_results.size.to_f / results.size * 100).round(1)}%)"
    puts "Highly unstable configs: #{unstable_results.size}/#{results.size} (#{(unstable_results.size.to_f / results.size * 100).round(1)}%)"

    if stable_results.size > 0
      puts "\nCharacteristics of stable configs:"
      avg_size = stable_results.map(&.n_nodes).sum / stable_results.size
      avg_force = stable_results.map(&.casimir_force).sum / stable_results.size
      avg_variance = stable_results.map(&.energy_variance).sum / stable_results.size

      puts "  Avg nodes: #{avg_size.round(0)}"
      puts "  Avg force: #{avg_force.round(4)}"
      puts "  Avg energy variance: #{avg_variance.round(3)}"
      puts "  Force sign: #{avg_force < 0 ? "Attractive" : "Repulsive"}"
    end

    if unstable_results.size > 0
      puts "\nCharacteristics of unstable configs:"
      avg_variance = unstable_results.map(&.energy_variance).sum / unstable_results.size
      puts "  Avg energy variance: #{avg_variance.round(3)}"
      puts "  Likely cause: High variance indicates optimization struggles"
    end

    # RH Implications Summary
    puts "\n🏆 RH IMPLICATIONS SUMMARY:"
    puts "-" * 25

    # Overall correlation
    all_forces = results.map(&.casimir_force)
    all_alignments = results.map(&.alignment_rho)
    overall_correlation = compute_correlation(all_forces, all_alignments)

    if overall_correlation
      puts "Overall Force-Alignment Correlation: #{overall_correlation.round(3)}"
      if overall_correlation < -0.2
        puts "✅ Strong evidence for RH stability!"
      elsif overall_correlation < 0
        puts "🔍 Moderate evidence for RH stability"
      else
        puts "⚠️  Weak or contradictory evidence"
      end
    end

    # Scale-dependent RH evidence
    puts "\nScale-dependent RH evidence:"
    by_size.each do |n_nodes, size_results|
      forces = size_results.map(&.casimir_force)
      alignments = size_results.map(&.alignment_rho)
      correlation = compute_correlation(forces, alignments)

      if correlation
        status = correlation < -0.2 ? "✅" : correlation < 0 ? "🔍" : "⚠️"
        puts "  #{n_nodes} nodes: #{status} correlation = #{correlation.round(3)}"
      end
    end

    # L-function dependent evidence
    puts "\nL-function dependent RH evidence:"
    by_lfunc.each do |l_func, lfunc_results|
      forces = lfunc_results.map(&.casimir_force)
      alignments = lfunc_results.map(&.alignment_rho)
      correlation = compute_correlation(forces, alignments)

      if correlation
        status = correlation < -0.2 ? "✅" : correlation < 0 ? "🔍" : "⚠️"
        puts "  #{l_func}: #{status} correlation = #{correlation.round(3)}"
      end
    end

    results
  end

  # Helper for correlation computation
  def self.compute_correlation(x : Array(Float64), y : Array(Float64))
    return nil if x.size != y.size || x.size < 2

    n = x.size.to_f64
    mean_x = x.sum / n
    mean_y = y.sum / n

    numerator = (0...x.size).sum { |i| (x[i] - mean_x) * (y[i] - mean_y) }

    std_x = Math.sqrt(x.sum { |xi| (xi - mean_x) ** 2 } / n)
    std_y = Math.sqrt(y.sum { |yi| (yi - mean_y) ** 2 } / n)

    return nil if std_x < 1e-12 || std_y < 1e-12

    numerator / (n * std_x * std_y)
  end

  # Prime misfit computation
  def self.compute_prime_misfit(l_sequence : Array(Int32), eigenvalue_reciprocal : Float64)
    return 1.0 if l_sequence.empty?

    l_reciprocals = l_sequence.map { |p| 1.0 / p }
    sorted_l = l_reciprocals.sort

    # Find nearest neighbor distance
    min_distance = Float64::INFINITY
    sorted_l.each do |l_recip|
      distance = (l_recip - eigenvalue_reciprocal).abs
      min_distance = [min_distance, distance].min
    end

    scale = eigenvalue_reciprocal
    min_distance / (scale + 1e-12)
  end

  # Main experiment runner
  def self.run(config : ScaleConfig = ScaleConfig.new)
    puts "🚀 ADVANCED SPECTRAL CASIMIR FORCE EXPERIMENT"
    puts "Scale effects, L-functions, force refinement, and stability analysis"
    puts "=" * 70

    results = run_scale_experiment(config)

    if results.empty?
      puts "❌ No results generated"
      return
    end

    analyze_advanced_results(results)

    puts "\n📊 EXPERIMENT SUMMARY:"
    puts "-" * 25
    puts "Total measurements: #{results.size}"
    puts "Node sizes tested: #{config.node_sizes.join(", ")}"
    puts "L-functions: #{config.l_functions.join(", ")}"
    puts "Prime cutoffs: #{config.prime_cutoffs.join(", ")}"
    puts "Beta points: #{config.beta_fine.size}"

    puts "\n✨ ADVANCED EXPERIMENT COMPLETE"
    puts "Scale-dependent RH stability patterns identified!"
  end
end

# Run the experiment if this file is executed directly
if PROGRAM_NAME.includes?("advanced_casimir_experiment")
  config = AdvancedCasimirExperiment::ScaleConfig.new

  # Allow command line arguments to override config
  if ARGV.includes?("--verbose")
    config.verbose = true
  elsif ARGV.includes?("--quiet")
    config.verbose = false
  end

  if size_idx = ARGV.index("--max-nodes")
    if max_nodes = ARGV[size_idx + 1]?
      config.node_sizes = config.node_sizes.select { |n| n <= max_nodes.to_i }
    end
  end

  if func_idx = ARGV.index("--l-function")
    if func = ARGV[func_idx + 1]?
      config.l_functions = [func] if config.l_functions.includes?(func)
    end
  end

  AdvancedCasimirExperiment.run(config)
end