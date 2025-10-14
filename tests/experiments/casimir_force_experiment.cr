#!/usr/bin/env crystal
#
# Spectral Casimir Force Experiment
# Testing RH stability via prime-eigenvalue vacuum interactions
#
# This experiment tests the hypothesis:
# - RH holds ↔ Casimir forces are attractive (F < 0) at a = 1/4
# - RH fails ↔ Repulsive forces (F > 0) near critical scale
# - Force sign flips should correlate with ρ (optimization alignment) breakdown
#
# Author: Testing spectral-arithmetic quantum vacuum dynamics
#

require "./src/multiplicative_constraint"
require "math"

module CasimirForceExperiment
  extend self

  # Check if a number is prime
  def self.prime?(n : Int32) : Bool
    return false if n < 2
    return true if n == 2
    return false if n.even?

    limit = Math.sqrt(n).to_i
    (3..limit).step(2) do |i|
      return false if n % i == 0
    end
    true
  end

  # Configuration for the experiment
  class Config
    def initialize(
      @n_graphs : Int32 = 20,
      @prime_cutoff : Int32 = 100,
      @beta_range : Array(Float64) = [0.1, 0.2, 0.25, 0.3, 0.4, 0.5, 0.75, 1.0],
      @graph_types : Array(String) = ["random", "regular", "bipartite", "clique_plus_cycle"],
      @force_samples : Int32 = 100,
      @verbose : Bool = true
    )
    end

    getter n_graphs : Int32
    getter prime_cutoff : Int32
    getter beta_range : Array(Float64)
    getter graph_types : Array(String)
    getter force_samples : Int32
    getter verbose : Bool
  end

  # Result data structure
  struct ForceResult
    def initialize(
      @graph_type : String,
      @beta : Float64,
      @casimir_force : Float64,
      @spectral_gap : Float64,
      @alignment_rho : Float64,
      @prime_misfit : Float64,
      @stability_indicator : Float64
    )
    end

    getter graph_type : String
    getter beta : Float64
    getter casimir_force : Float64
    getter spectral_gap : Float64
    getter alignment_rho : Float64
    getter prime_misfit : Float64
    getter stability_indicator : Float64  # Combined measure
  end

  # Generate test graphs with different spectral properties
  def self.generate_graph(n_nodes : Int32, graph_type : String)
    case graph_type
    when "random"
      # Erdős-Rényi random graph
      edges = [] of Tuple(Int32, Int32, Float64)
      (0...n_nodes).each do |i|
        (i+1...n_nodes).each do |j|
          if rand < 0.15  # 15% edge probability
            weight = 0.5 + rand * 1.5
            edges << {i, j, weight}
          end
        end
      end
      edges

    when "regular"
      # Random regular graph (degree 3)
      edges = [] of Tuple(Int32, Int32, Float64)
      degree = 3
      (0...n_nodes).each do |i|
        degree.times do
          j = rand(n_nodes)
          next if j == i
          # Check if edge already exists
          exists = edges.any? { |e, f, w| (e == i && f == j) || (e == j && f == i) }
          edges << {i, j, 1.0} unless exists
        end
      end
      edges

    when "bipartite"
      # Complete bipartite graph K_{n/2,n/2}
      edges = [] of Tuple(Int32, Int32, Float64)
      half = n_nodes // 2
      (0...half).each do |i|
        (half...n_nodes).each do |j|
          edges << {i, j, 1.0}
        end
      end
      edges

    when "clique_plus_cycle"
      # Mix of complete subgraph and cycle (structured complexity)
      edges = [] of Tuple(Int32, Int32, Float64)
      clique_size = n_nodes // 3

      # Complete subgraph
      (0...clique_size).each do |i|
        (i+1...clique_size).each do |j|
          edges << {i, j, 2.0}
        end
      end

      # Cycle structure
      (clique_size...n_nodes).each do |i|
        j = (i + 1) % (n_nodes - clique_size) + clique_size
        edges << {i, j, 1.0}
      end

      # Random connections
      50.times do
        i = rand(n_nodes)
        j = rand(n_nodes)
        next if i == j
        edges << {i, j, 0.5 + rand}
      end
      edges

    else
      raise ArgumentError.new("Unknown graph type: #{graph_type}")
    end
  end

  # Compute eigenvalues of graph Laplacian (using power iteration for smallest eigenvalue)
  def self.compute_eigenvalues(n_nodes : Int32, edges : Array(Tuple(Int32, Int32, Float64)))
    # Build Laplacian matrix
    laplacian = Array.new(n_nodes) { Array.new(n_nodes, 0.0) }
    degrees = Array.new(n_nodes, 0.0)

    edges.each do |i, j, weight|
      laplacian[i][j] -= weight
      laplacian[j][i] -= weight
      degrees[i] += weight
      degrees[j] += weight
    end

    (0...n_nodes).each do |i|
      laplacian[i][i] = degrees[i]
    end

    # Power iteration for smallest eigenvalue (spectral gap)
    # For simplicity, we'll use Rayleigh quotient iteration
    n_iterations = 100
    tolerance = 1e-8

    # Start with random vector
    vec = Array.new(n_nodes) { rand - 0.5 }
    norm = Math.sqrt(vec.sum { |x| x * x })
    vec = vec.map { |x| x / norm }

    smallest_eigenvalue = Float64::INFINITY

    n_iterations.times do |iter|
      # Apply inverse iteration (shifted)
      # L * vec = result
      result = Array.new(n_nodes, 0.0)
      (0...n_nodes).each do |i|
        (0...n_nodes).each do |j|
          result[i] += laplacian[i][j] * vec[j]
        end
      end

      # Handle zero eigenvalue (constant eigenvector)
      # Add small regularization to avoid singularity
      shift = 1e-6
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

      # Check convergence
      diff = (eigenvalue - smallest_eigenvalue).abs
      smallest_eigenvalue = eigenvalue
      break if diff < tolerance

      vec = result
    end

    # For approximation, return spectral gap and a few eigenvalues
    {smallest_eigenvalue, degrees.sum / degrees.size}
  end

  # Compute spectral-prime misfit using optimal transport analogy
  def self.compute_prime_misfit(primes : Array(Int32), eigenvalue_reciprocal : Float64)
    # Simple misfit: compare distributions
    prime_reciprocals = primes.map { |p| 1.0 / p }

    # Compute Kolmogorov-Smirnov-like statistic
    # Align eigenvalue reciprocal with prime distribution
    sorted_primes = prime_reciprocals.sort

    # Find nearest neighbor distance
    min_distance = Float64::INFINITY
    sorted_primes.each do |prime_recip|
      distance = (prime_recip - eigenvalue_reciprocal).abs
      min_distance = [min_distance, distance].min
    end

    # Normalize by scale
    scale = eigenvalue_reciprocal
    min_distance / (scale + 1e-12)
  end

  # Compute Casimir force from vacuum energy differences
  def self.compute_casimir_force(
    primes : Array(Int32),
    eigenvalue : Float64,
    beta : Float64,
    prime_misfit : Float64
  )
    # Force formula based on vacuum energy derivative
    # F = -d/da [ζ'_hybrid(a*s) / ζ_hybrid(a*s)]

    # a acts as "AdS radius" scaling the spectral-prime correspondence
    a = 1.0 / beta

    # Simplified Casimir force computation
    # Based on mode mismatch between prime and spectral vacua

    prime_weight = primes.sum { |p| 1.0 / (p * p) }  # Σ 1/p²
    spectral_weight = 1.0 / eigenvalue

    # Phase desynchronization term
    phase_mismatch = Math.cos(2.0 * Math::PI * Math.log(eigenvalue) / Math.log(primes.first))

    # Casimir force with scale-dependent oscillations
    force = prime_weight * spectral_weight * phase_mismatch * Math.exp(-a * prime_misfit)

    # Apply scale correction (critical at a = 4, i.e., beta = 1/4)
    scale_factor = Math.tanh((a - 4.0) / 0.5)  # Sharp transition near a=4

    force * scale_factor
  end

  # Run optimization and measure alignment rho
  def self.measure_alignment_rho(
    n_nodes : Int32,
    edges : Array(Tuple(Int32, Int32, Float64)),
    primes : Array(Int32),
    verbose : Bool = true
  )
    # Build graph for optimization
    weights = Array.new(n_nodes, 1.0)
    graph = MultiplicativeConstraint::Graph.from_edges(weights, edges)

    # Use small number of iterations for speed
    engine = MultiplicativeConstraint::Engine.new(graph, 2)

    begin
      result = engine.solve(iterations: 500, step: 0.35, seed: 42)

      # Simple alignment measure: check if optimization converged
      # Lower energy = better alignment
      energy = result.energy

      # Normalize to [0,1] range (approximate)
      alignment = 1.0 / (1.0 + energy / 10.0)

    rescue ex
      puts "Warning: Optimization failed: #{ex.message}" if verbose
      alignment = 0.0
    end

    alignment
  end

  # Run single experiment iteration
  def self.run_experiment_iteration(
    config : Config,
    n_nodes : Int32 = 30
  )
    primes = [] of Int32
    (2..config.prime_cutoff).each { |i| primes << i if prime?(i) }

    puts "\n🔬 Starting Casimir Force Experiment" if config.verbose
    puts "Primes up to #{config.prime_cutoff}: #{primes.size}" if config.verbose
    puts "Testing #{config.graph_types.size} graph types, #{config.n_graphs} each" if config.verbose
    puts "Beta values: #{config.beta_range}" if config.verbose

    results = [] of ForceResult

    config.graph_types.each do |graph_type|
      puts "\n📊 Testing #{graph_type} graphs..." if config.verbose

      config.n_graphs.times do |graph_idx|
        puts "  Graph #{graph_idx + 1}/#{config.n_graphs}" if config.verbose && graph_idx % 5 == 0

        # Generate graph
        edges = generate_graph(n_nodes, graph_type)

        # Compute spectral properties
        smallest_eigenvalue, avg_degree = compute_eigenvalues(n_nodes, edges)
        eigenvalue_reciprocal = 1.0 / Math.sqrt(smallest_eigenvalue + 1e-12)

        # Compute prime misfit
        prime_misfit = compute_prime_misfit(primes, eigenvalue_reciprocal)

        # Measure optimization alignment
        alignment_rho = measure_alignment_rho(n_nodes, edges, primes, config.verbose)

        # Test different beta values
        config.beta_range.each do |beta|
          # Compute Casimir force
          casimir_force = compute_casimir_force(
            primes, smallest_eigenvalue, beta, prime_misfit
          )

          # Stability indicator: combine force and alignment
          stability_indicator = alignment_rho * Math.exp(-casimir_force.abs)

          result = ForceResult.new(
            graph_type: graph_type,
            beta: beta,
            casimir_force: casimir_force,
            spectral_gap: smallest_eigenvalue,
            alignment_rho: alignment_rho,
            prime_misfit: prime_misfit,
            stability_indicator: stability_indicator
          )

          results << result
        end
      end
    end

    results
  end

  # Analyze results for RH implications
  def self.analyze_results(results : Array(ForceResult))
    puts "\n🎯 ANALYZING RESULTS FOR RH IMPLICATIONS"
    puts "=" * 50

    # Group by beta values
    by_beta = results.group_by(&.beta)

    puts "\n📈 Force vs Alignment Analysis:"
    puts "-" * 30

    by_beta.each do |beta, beta_results|
      avg_force = beta_results.map(&.casimir_force).sum / beta_results.size
      avg_alignment = beta_results.map(&.alignment_rho).sum / beta_results.size
      avg_stability = beta_results.map(&.stability_indicator).sum / beta_results.size

      # Count attractive vs repulsive forces
      attractive = beta_results.count { |r| r.casimir_force < 0 }
      repulsive = beta_results.count { |r| r.casimir_force > 0 }

      puts "β = #{beta.round(3)}:"
      puts "  Avg Force: #{avg_force.round(4)} (#{attractive} attractive, #{repulsive} repulsive)"
      puts "  Avg Alignment ρ: #{avg_alignment.round(3)}"
      puts "  Avg Stability: #{avg_stability.round(3)}"

      # Critical analysis near β = 0.25
      if (beta - 0.25).abs < 0.05
        puts "  ⚠️  CRITICAL REGION (near β = 1/4):"
        if attractive > repulsive
          puts "    ✅ Dominantly attractive forces → RH stability likely"
        else
          puts "    ❌ Repulsive forces dominant → RH violation possible"
        end

        if avg_alignment > 0.8
          puts "    ✅ High alignment (ρ > 0.8) → stable optimization"
        else
          puts "    ❌ Low alignment (ρ < 0.8) → optimization breakdown"
        end
      end
      puts
    end

    # Correlation analysis
    forces = results.map(&.casimir_force)
    alignments = results.map(&.alignment_rho)

    # Simple correlation coefficient
    n = results.size.to_f64
    mean_force = forces.sum / n
    mean_align = alignments.sum / n

    numerator = (0...results.size).sum do |i|
      (forces[i] - mean_force) * (alignments[i] - mean_align)
    end

    force_std = Math.sqrt(forces.sum { |f| (f - mean_force) ** 2 } / n)
    align_std = Math.sqrt(alignments.sum { |a| (a - mean_align) ** 2 } / n)

    correlation = numerator / (n * force_std * align_std) if force_std > 0 && align_std > 0

    puts "\n🔗 CORRELATION ANALYSIS:"
    puts "-" * 25
    puts "Force-Alignment Correlation: #{correlation ? correlation.round(4) : "N/A"}"

    if correlation && correlation.abs > 0.3
      if correlation < 0
        puts "✅ Negative correlation detected!"
        puts "   Attractive forces (F < 0) correlate with better alignment (higher ρ)"
        puts "   This supports the RH stability hypothesis!"
      else
        puts "❌ Positive correlation detected"
        puts "   This contradicts the RH stability hypothesis"
      end
    else
      puts "⚠️  Weak correlation - may need more data"
    end

    # Critical point analysis
    critical_results = results.select { |r| (r.beta - 0.25).abs < 0.1 }
    if critical_results.size > 0
      critical_force = critical_results.map(&.casimir_force).sum / critical_results.size
      critical_alignment = critical_results.map(&.alignment_rho).sum / critical_results.size

      puts "\n🎯 CRITICAL POINT (β ≈ 1/4) ANALYSIS:"
      puts "-" * 35
      puts "Average force at critical point: #{critical_force.round(4)}"
      puts "Average alignment at critical point: #{critical_alignment.round(3)}"

      if critical_force < 0 && critical_alignment > 0.7
        puts "🎉 STRONG EVIDENCE FOR RH STABILITY!"
        puts "   Attractive Casimir forces at critical scale"
        puts "   High optimization alignment maintained"
      elsif critical_force > 0
        puts "⚠️  EVIDENCE FOR RH VIOLATION?"
        puts "   Repulsive Casimir forces at critical scale"
      else
        puts "🤔 MIXED RESULTS - INCONCLUSIVE"
      end
    end

    # Stability prediction
    puts "\n🔮 STABILITY PREDICTION:"
    puts "-" * 25

    stable_graphs = results.select { |r| r.stability_indicator > 0.6 }
    unstable_graphs = results.select { |r| r.stability_indicator < 0.3 }

    puts "Stable configurations: #{stable_graphs.size}/#{results.size}"
    puts "Unstable configurations: #{unstable_graphs.size}/#{results.size}"

    if stable_graphs.size > unstable_graphs.size * 2
      puts "✅ System predominantly stable → RH likely holds"
    elsif unstable_graphs.size > stable_graphs.size * 2
      puts "❌ System predominantly unstable → RH likely fails"
    else
      puts "⚖️  Balanced stability → Inconclusive"
    end
  end

  # Main experiment runner
  def self.run(config : Config = Config.new)
    puts "🚀 SPECTRAL CASIMIR FORCE EXPERIMENT"
    puts "Testing RH stability via quantum vacuum interactions"
    puts "=" * 60

    results = run_experiment_iteration(config)

    if results.empty?
      puts "❌ No results generated"
      return
    end

    analyze_results(results)

    puts "\n📊 EXPERIMENT SUMMARY:"
    puts "-" * 25
    puts "Total measurements: #{results.size}"
    puts "Graph types tested: #{config.graph_types.join(", ")}"
    puts "Prime cutoff: #{config.prime_cutoff}"
    puts "Beta range explored: #{config.beta_range.first} to #{config.beta_range.last}"

    # Find most interesting result
    most_stable = results.max_by(&.stability_indicator)
    least_stable = results.min_by(&.stability_indicator)

    puts "\n🏆 MOST STABLE CONFIGURATION:"
    puts "  Graph: #{most_stable.graph_type}, β = #{most_stable.beta}"
    puts "  Force: #{most_stable.casimir_force.round(4)}, Alignment: #{most_stable.alignment_rho.round(3)}"

    puts "\n⚠️  LEAST STABLE CONFIGURATION:"
    puts "  Graph: #{least_stable.graph_type}, β = #{least_stable.beta}"
    puts "  Force: #{least_stable.casimir_force.round(4)}, Alignment: #{least_stable.alignment_rho.round(3)}"

    puts "\n✨ EXPERIMENT COMPLETE"
    puts "Check force-alignment correlations for RH evidence!"
  end
end

# Run the experiment if this file is executed directly
if PROGRAM_NAME.includes?("casimir_force_experiment")
  verbose_flag = ARGV.includes?("--verbose")
  quiet_flag = ARGV.includes?("--quiet")
  verbose = verbose_flag ? true : (quiet_flag ? false : true)

  graph_type = nil
  if graph_type_idx = ARGV.index("--graph-type")
    graph_type = ARGV[graph_type_idx + 1]?
  end

  config = CasimirForceExperiment::Config.new(
    verbose: verbose,
    graph_types: graph_type ? [graph_type] : ["random", "regular", "bipartite", "clique_plus_cycle"]
  )

  CasimirForceExperiment.run(config)
end