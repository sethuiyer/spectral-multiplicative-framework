#
# MultiplicativeConstraint - Heat-Kernel Constraint Partitioning Engine
# Developed by aninokuma at Shunya Bar
# Advanced spectral optimization with neural-adaptive prime weight learning
# Combines heat-kernel methods, sparse linear algebra, and simulated annealing
#

require "./multiplicative_constraint/sparse_matrix"
require "./multiplicative_constraint/lanczos"
require "./multiplicative_constraint/linalg/lapack"
require "./multiplicative_constraint/linalg/eigensolver"
require "./multiplicative_constraint/ergodic"
require "./multiplicative_constraint/graph"
require "./multiplicative_constraint/weights"
require "./multiplicative_constraint/energy"
require "./multiplicative_constraint/annealer"
require "./multiplicative_constraint/report"
require "./multiplicative_constraint/universal_encoder"
require "./multiplicative_constraint/constraint_weights"
require "./multiplicative_constraint/neural_weights"
require "./multiplicative_constraint/bethe_hessian"
require "./multiplicative_constraint/sat"
require "./list_coloring"

module MultiplicativeConstraint
  # General-purpose constraint partitioning engine
  #
  # This module implements a sophisticated optimization framework that combines:
  # - Heat-kernel spectral methods for global structure analysis
  # - Sparse matrix operations for enterprise-scale efficiency
  # - Neural network adaptation for problem-specific learning
  # - Simulated annealing for robust optimization
  #
  # The core innovation is the spectral-multiplicative framework that achieves
  # ρ ≥ 0.99 correlation between spectral and multiplicative functionals,
  # enabling unified optimization of complex constraint systems.
  #
  # Author: aninokuma at Shunya Bar
  # License: Apache 2.0

  alias FloatArray = Array(Float64)
  alias IntArray = Array(Int32)

  # Immutable result structure for partition optimization
  #
  # Contains all relevant metrics from the optimization process including
  # spectral action, fairness measures, and final segment assignments.
  # The dual representation (alpha angles and discrete segments) enables
  # both continuous optimization and discrete constraint satisfaction.
  #
  # @author aninokuma at Shunya Bar
  struct PartitionResult
    # Continuous parameterization in angular space (2π periodic)
    # Enables smooth gradient-based optimization in the spectral domain
    getter alpha : FloatArray

    # Unified energy combining spectral, multiplicative, and constraint terms
    # This is the primary optimization objective
    getter energy : Float64

    # Heat-kernel spectral action term
    # Captures global graph structure via trace(exp(-tL))
    getter spectral : Float64

    # Size fairness penalty (quadratic variance from target segment size)
    # Ensures balanced partition sizes
    getter fairness : Float64

    # Weight fairness penalty (variance in weight distribution)
    # Maintains equitable resource allocation
    getter weight_fairness : Float64

    # Shannon entropy of segment size distribution
    # Encourages diverse and well-distributed segments
    getter entropy : Float64

    # Multiplicative penalty from prime weight constraints
    # Key innovation: amplifies constraint violations via prime factorization
    getter penalty : Float64

    # Cross-segment conflict weight (edges crossing segment boundaries)
    # Minimizes edge cuts for cohesive clustering
    getter cross_conflict : Float64

    # Final discrete segment assignments
    # Integer mapping of nodes to segment indices
    getter segments : Array(IntArray)

    # Node-to-segment label mapping (for convenience)
    getter discrete_solution : Array(Int32)

    def initialize(@alpha, @energy, @spectral, @fairness, @weight_fairness, @entropy, @penalty, @cross_conflict, @segments, @discrete_solution)
    end
  end

  # Main optimization engine for constraint partitioning
  #
  # The Engine orchestrates the entire optimization pipeline:
  # 1. Energy function setup with configurable objective weights
  # 2. Optional calibration to maximize spectral-multiplicative correlation
  # 3. Correlation guard to maintain ρ ≥ 0.99 during optimization
  # 4. Simulated annealing with adaptive temperature scheduling
  #
  # This unified interface enables both simple usage and advanced fine-tuning
  # for enterprise-scale optimization problems.
  #
  # @author aninokuma at Shunya Bar
  class Engine
    # Graph structure containing adjacency, weights, and edge information
    # Supports both dense and sparse representations for scalability
    getter graph : Graph

    # Number of segments to partition the graph into
    # Must be positive; optimal range is typically 2-10 for most problems
    getter segments : Int32

    # Initialize the optimization engine with configurable parameters
    #
    # @param graph Graph structure to optimize
    # @param segments Number of desired segments (k)
    # @param fairness_weight Weight for size balance penalty
    # @param weight_fairness_weight Weight for weight distribution fairness
    # @param entropy_weight Weight for Shannon entropy term
    # @param penalty_weight Weight for multiplicative prime penalty
    # @param cross_conflict_weight Weight for edge cut minimization
    # @param calibrate Enable automatic weight calibration via ergodic sampling
    # @param calibration_samples Number of samples for calibration
    # @param enable_corr_guard Enable correlation monitoring during optimization
    # @param corr_min Minimum acceptable correlation (default 0.99)
    # @param guard_window Window size for correlation computation
    # @param guard_period Frequency of correlation checks
    # @param guard_lambda Penalty strength for correlation violations
    # @param sampler_seed Random seed for reproducible sampling
    #
    # @raise ArgumentError if segments is not positive
    def initialize(@graph : Graph, @segments : Int32,
                   fairness_weight : Float64 = 1.0,
                   weight_fairness_weight : Float64 = 0.5,
                   entropy_weight : Float64 = 0.1,
                   penalty_weight : Float64 = 1.0,
                   cross_conflict_weight : Float64 = 0.0,
                   calibrate : Bool = false,
                   calibration_samples : Int32 = 128,
                   enable_corr_guard : Bool = false,
                   corr_min : Float64 = 0.99,
                   guard_window : Int32 = 16,
                   guard_period : Int32 = 50,
                   guard_lambda : Float64 = 1.0,
                   sampler_seed : Int32 = 777)
      raise ArgumentError.new("segments must be positive") if @segments <= 0

      # Initialize energy function with all configurable weights
      @energy = Energy.new(@graph, @segments,
                           fairness_weight: fairness_weight,
                           weight_fairness_weight: weight_fairness_weight,
                           entropy_weight: entropy_weight,
                           penalty_weight: penalty_weight,
                           cross_conflict_weight: cross_conflict_weight)

      # Optional calibration to maximize spectral-multiplicative correlation
      # Uses least-squares fitting on ergodically sampled configurations
      if calibrate
        @energy.calibrate!(calibration_samples)
      end

      # Optional correlation guard to maintain mathematical validity
      # Ensures ρ ≥ 0.99 throughout optimization process
      if enable_corr_guard
        @energy.enable_correlation_guard!(rho_min: corr_min, window: guard_window,
                                        period: guard_period, sampler_seed: sampler_seed,
                                        lambda: guard_lambda)
      end

      # Initialize simulated annealing optimizer
      @annealer = Annealer.new(@energy)
    end

    # Execute the optimization using simulated annealing
    #
    # The optimization process operates in continuous angular space (alpha)
    # and maps to discrete segment assignments for constraint satisfaction.
    # Uses adaptive temperature scheduling and Gaussian perturbations.
    #
    # @param iterations Number of annealing iterations (default 2000)
    # @param step Initial step size for angular perturbations (default 0.35)
    # @param seed Random seed for reproducible results (default 42)
    # @param bethe_hessian Optional BetheHessian for correlation tracking
    # @return PartitionResult containing optimal solution and all metrics
    def solve(iterations = 2000, step = 0.35, seed = 42, bethe_hessian : BetheHessian? = nil)
      alpha, energy = @annealer.minimize(@segments, iterations: iterations, step: step, seed: seed, bethe_hessian: bethe_hessian)
      build_result(alpha, energy)
    end

    # Evaluate the unified energy for a given alpha configuration
    #
    # This method allows external evaluation of configurations without
    # running the full optimization, useful for analysis and debugging.
    #
    # @param alpha Angular configuration in [0, 2π) space
    # @return Unified energy value combining all objective terms
    def evaluate(alpha : FloatArray)
      @energy.unified(alpha)
    end

    # Generate a formatted report for the optimization result
    #
    # Creates a human-readable report showing segment assignments,
    # energy breakdown, and performance metrics.
    #
    # @param result Result from solve() method
    # @param payload_names Human-readable names for graph nodes
    # @return Formatted string report
    def report(result : PartitionResult, payload_names : Array(String))
      Report.generate(result, payload_names)
    end

    # Multi-type optimization methods

    # Set edge type weights manually (for multi-type graphs)
    def set_type_weights(weights : Hash(String, Float64))
      @energy.set_type_weights(weights)
    end

    # Get current edge type weights
    def get_type_weights : Hash(String, Float64)
      @energy.get_type_weights
    end

    # Train neural network for multi-type weight learning
    def train_type_weights(iterations : Int32 = 100, learning_rate : Float64 = 0.01)
      @energy.train_type_weights(iterations, learning_rate)
    end

    # Calibrate multi-type weights using ergodic sampling
    def calibrate!(samples : Int32 = 128)
      @energy.calibrate!(samples)
    end

    # Build a complete PartitionResult from an alpha configuration
    #
    # Evaluates all energy components and constructs the immutable result
    # structure with both continuous and discrete representations.
    #
    # @param alpha Optimal angular configuration from annealing
    # @param unified Final unified energy value
    # @return Complete PartitionResult with all metrics computed
    private def build_result(alpha, unified)
      evaluation = @energy.evaluate(alpha)
      PartitionResult.new(
        alpha: alpha,
        energy: evaluation.unified,
        spectral: evaluation.spectral,
        fairness: evaluation.fairness,
        weight_fairness: evaluation.weight_fairness,
        entropy: evaluation.entropy,
        penalty: evaluation.penalty,
        cross_conflict: evaluation.cross_conflict,
        segments: evaluation.segments,
        discrete_solution: evaluation.labels
      )
    end
  end
end
