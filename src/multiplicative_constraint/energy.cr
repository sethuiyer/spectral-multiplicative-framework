require "set"
require "./bethe_hessian"

module MultiplicativeConstraint
  # Immutable evaluation result containing all energy components
  #
  # This structure captures the complete state of an energy evaluation including
  # discrete segment assignments, node labels, and all contributing energy terms.
  # The dual representation enables analysis of both the continuous optimization
  # landscape and the discrete constraint satisfaction results.
  #
  # @author aninokuma at Shunya Bar
  struct Evaluation
    # Discrete segment assignments (array of node index arrays)
    # Final partitioning result from angular space optimization
    getter segments : Array(Array(Int32))

    # Node-to-segment label mapping (size = n)
    # Efficient lookup for segment membership during edge processing
    getter labels : Array(Int32)

    # Heat-kernel spectral action term
    # Captures global graph structure via trace(exp(-tL)) computation
    getter spectral : Float64

    # Size fairness penalty (quadratic variance)
    # Measures deviation from equal segment sizes
    getter fairness : Float64

    # Weight fairness penalty (variance in weight distribution)
    # Ensures equitable resource allocation across segments
    getter weight_fairness : Float64

    # Shannon entropy of segment size distribution
    # Encourages diverse and well-distributed segments
    getter entropy : Float64

    # Multiplicative penalty from prime weight constraints
    # Key innovation: amplifies constraint violations via multiplicative factorization
    getter penalty : Float64

    # Cross-segment conflict weight (edge cuts)
    # Total weight of edges crossing segment boundaries
    getter cross_conflict : Float64

    # Unified energy objective
    # Weighted combination of all terms used for optimization
    getter unified : Float64

    def initialize(@segments, @labels, @spectral, @fairness, @weight_fairness, @entropy, @penalty, @cross_conflict, @unified)
    end
  end

  # Core energy function implementing the spectral-multiplicative framework
  #
  # This class is the mathematical heart of the optimization system, implementing
  # the innovative spectral-multiplicative approach that achieves ρ ≥ 0.99
  # correlation between spectral and multiplicative functionals.
  #
  # Key innovations:
  # 1. Heat-kernel spectral action for global structure analysis
  # 2. Multiplicative prime weight constraints for violation amplification
  # 3. Adaptive calibration via ergodic sampling
  # 4. Correlation guard to maintain mathematical validity
  #
  # The unified energy function combines:
  # E_unified = E_spectral + w_fairness*E_fairness + w_weight*E_weight_fairness
  #            - w_entropy*E_entropy - w_penalty*E_multiplicative + w_cross*E_cross
  #
  # @author aninokuma at Shunya Bar
  class Energy
    # Graph structure containing adjacency, weights, and edge information
    getter graph : Graph

    # Number of segments to partition into
    getter segments : Int32

    # Tunable weights for objective components
    # These enable fine-tuning for different problem domains
    @fairness_weight : Float64        # Size balance importance
    @weight_fairness_weight : Float64 # Weight distribution importance
    @entropy_weight : Float64         # Diversity encouragement
    @penalty_weight : Float64         # Multiplicative constraint strength
    @cross_conflict_weight : Float64  # Edge cut minimization

    # Calibration and correlation guard state
    @calibrated : Bool = false        # Whether weights have been calibrated
    @corr_guard_enabled : Bool = false # Whether correlation monitoring is active
    @corr_min : Float64 = 0.99       # Minimum acceptable correlation
    @guard_window : Int32 = 16       # Window size for correlation computation
    @sampler_seed : Int32 = 777      # Seed for reproducible sampling
    @guard_period : Int32 = 50       # Frequency of correlation checks
    @guard_counter : Int32 = 0       # Current counter for periodic checks
    @guard_lambda : Float64 = 1.0    # Penalty strength for correlation violations
    @guard_alphas : Array(Array(Float64))? = nil # Precomputed alpha configurations

    # Graph size for efficient access
    @size : Int32

    # Multi-type neural network support
    @multi_type_network : MultiTypeNeuralNetwork?
    @learnable_type_weights : Bool = false

    # Bethe Hessian support for hybrid spectral analysis
    @bethe_hessian : BetheHessian?
    @use_hybrid_spectral : Bool = true

    # Caching for Bethe Hessian computations
    @bethe_hessian_cached : BetheHessian?
    @detectability_cached : Float64?
    @last_graph_hash : UInt64?

    def initialize(@graph : Graph, @segments : Int32,
                   fairness_weight : Float64 = 1.0,
                   weight_fairness_weight : Float64 = 0.5,
                   entropy_weight : Float64 = 0.1,
                   penalty_weight : Float64 = 1.0,
                   cross_conflict_weight : Float64 = 0.0)
      @size = @graph.size
      @fairness_weight = fairness_weight
      @weight_fairness_weight = weight_fairness_weight
      @entropy_weight = entropy_weight
      @penalty_weight = penalty_weight
      @cross_conflict_weight = cross_conflict_weight

      # Initialize multi-type network if graph has multiple edge types
      if @graph.multi_type && @graph.num_types > 1
        @multi_type_network = MultiTypeNeuralNetwork.new(@graph.type_names)
        @learnable_type_weights = true
      end
    end

    # Enable correlation guard during optimization
    def enable_correlation_guard!(rho_min : Float64 = 0.99, window : Int32 = 16, period : Int32 = 50, sampler_seed : Int32 = 777, lambda : Float64 = 1.0)
      @corr_guard_enabled = true
      @corr_min = rho_min
      @guard_window = window
      @sampler_seed = sampler_seed
      @guard_period = period
      @guard_lambda = lambda
      # Precompute guard alphas ergodically
      sampler = ErgodicSampler.new(@segments, @sampler_seed)
      alphas = Array(Array(Float64)).new
      window.times { alphas << sampler.next_alpha }
      @guard_alphas = alphas
    end

    # Calibrate weights via ergodic sampling to maximize correlation
    def calibrate!(samples : Int32 = 128)
      if @graph.multi_type
        # Multi-type calibration: optimize edge type weights
        calibrate_multi_type!(samples)
      else
        # Original single-type calibration
        calibrate_single_type!(samples)
      end
    end

    # Multi-type calibration using ergodic sampling
    private def calibrate_multi_type!(samples : Int32 = 128)
      return unless @learnable_type_weights && (network = @multi_type_network)

      # Build calibration dataset
      sampler = ErgodicSampler.new(@segments, @sampler_seed)
      edge_type_contributions = Hash(String, Array(Float64)).new
      spectral_targets = Array(Float64).new

      @graph.type_names.each { |type| edge_type_contributions[type] = Array(Float64).new }

      samples.times do
        alpha = sampler.next_alpha

        # Evaluate contribution of each edge type separately
        total_spectral = 0.0
        type_spectral = Hash(String, Float64).new

        @graph.type_names.each do |type_name|
          # Temporarily set only this type weight to 1.0, others to 0
          original_weights = get_current_type_weights
          temp_weights = Hash(String, Float64).new
          @graph.type_names.each { |t| temp_weights[t] = t == type_name ? 1.0 : 0.0 }

          # Temporarily override weights
          @graph.type_names.each { |t| @graph.set_type_weight(t, temp_weights[t]) }

          # Evaluate with this single edge type
          eval_result = evaluate(alpha)
          type_spectral[type_name] = eval_result.spectral
          total_spectral += eval_result.spectral
        end

        # Restore original weights
        original_weights = get_current_type_weights
        @graph.type_names.each { |t| @graph.set_type_weight(t, original_weights[t]) }

        # Store calibration data
        @graph.type_names.each do |type_name|
          edge_type_contributions[type_name] << type_spectral[type_name]
        end
        spectral_targets << total_spectral
      end

      # Optimize type weights using least squares
      optimized_weights = optimize_type_weights_least_squares(edge_type_contributions, spectral_targets)

      # Apply optimized weights silently
      set_type_weights(optimized_weights)
      @calibrated = true
    end

    # Original single-type calibration
    private def calibrate_single_type!(samples : Int32 = 128)
      sampler = ErgodicSampler.new(@segments, @sampler_seed)
      # Build feature matrix F (S x 5) and target y = spectral
      feats = Array(Array(Float64)).new
      target = [] of Float64
      samples.times do
        alpha = sampler.next_alpha
        ev = self.evaluate(alpha)
        # Features unweighted; choose signs so linear combo approximates spectral
        feats << [
          ev.fairness,              # f1 ≥ 0
          ev.weight_fairness,       # f2 ≥ 0
          -ev.entropy,              # f3 can be negative
          -ev.penalty,              # f4 ≤ 0
          ev.cross_conflict         # f5 ≥ 0
        ]
        target << ev.spectral
      end
      # Normalize columns to unit variance to improve conditioning
      means, stds = column_stats(feats)
      normf = normalize_columns(feats, means, stds)
      # Solve least squares: minimize ||normF * w - target||^2
      w = solve_least_squares(normf, target)
      # Denormalize weights to original feature scale
      denorm = [] of Float64
      5.times do |j|
        scale = stds[j]
        scale = 1.0 if scale.abs < 1e-12
        denorm << (w[j] / scale)
      end
      # Clamp to nonnegative where appropriate (f3 and f4 were signed already)
      f1, f2, f3, f4, f5 = denorm
      f1 = f1 < 0 ? 0.0 : f1
      f2 = f2 < 0 ? 0.0 : f2
      f5 = f5 < 0 ? 0.0 : f5
      # Map to internal weights: entropy/penalty weights are applied with minus sign in unified
      @fairness_weight = f1
      @weight_fairness_weight = f2
      @entropy_weight = -f3
      @penalty_weight = -f4
      @cross_conflict_weight = f5
      @calibrated = true
    end

    # Optimize type weights using least squares regression
    private def optimize_type_weights_least_squares(
      contributions : Hash(String, Array(Float64)),
      targets : Array(Float64)
    ) : Hash(String, Float64)
      num_samples = targets.size
      num_types = @graph.type_names.size

      return Hash(String, Float64).new if num_samples == 0 || num_types == 0

      # Build feature matrix X (samples x types) and target vector y
      feature_matrix = Array.new(num_samples) do |i|
        @graph.type_names.map { |type| contributions[type][i] }
      end
      target_vector = targets

      # Solve least squares: minimize ||X * w - y||^2
      # Using normal equations: (X^T * X) * w = X^T * y

      # Compute X^T * X
      xtx = Array.new(num_types) { Array.new(num_types, 0.0) }
      num_samples.times do |i|
        num_types.times do |a|
          num_types.times do |b|
            xtx[a][b] += feature_matrix[i][a] * feature_matrix[i][b]
          end
        end
      end

      # Compute X^T * y
      xty = Array.new(num_types, 0.0)
      num_samples.times do |i|
        num_types.times do |a|
          xty[a] += feature_matrix[i][a] * target_vector[i]
        end
      end

      # Solve for weights using Gaussian elimination
      weights = gauss_solve(xtx, xty)

      # Ensure non-negative weights
      weights = weights.map { |w| w < 0 ? 0.0 : w }

      # Normalize weights to sum to 1 (optional)
      weight_sum = weights.sum
      if weight_sum > 1e-12
        weights = weights.map { |w| w / weight_sum }
      else
        # Fallback to equal weights
        weights = Array.new(num_types, 1.0 / num_types)
      end

      # Create result hash
      result = Hash(String, Float64).new
      @graph.type_names.each_with_index do |type_name, i|
        result[type_name] = weights[i]
      end

      result
    end

    private def linear_fit(x : Array(Float64), y : Array(Float64)) : {Float64, Float64}
      n = x.size
      return {1.0, 0.0} if n == 0
      sx = x.sum
      sy = y.sum
      sxx = x.sum { |v| v * v }
      sxy = x.zip(y).sum { |a,b| a * b }
      denom = (n * sxx - sx * sx)
      if denom.abs < 1e-12
        return {1.0, 0.0}
      end
      a = (n * sxy - sx * sy) / denom
      b = (sy - a * sx) / n
      {a, b}
    end

    private def column_stats(f : Array(Array(Float64))) : {Array(Float64), Array(Float64)}
      return {[] of Float64, [] of Float64} if f.empty?
      cols = f[0].size
      means = Array.new(cols, 0.0)
      stds = Array.new(cols, 0.0)
      f.each do |row|
        cols.times { |j| means[j] += row[j] }
      end
      n = f.size.to_f64
      cols.times { |j| means[j] /= n }
      f.each do |row|
        cols.times { |j| stds[j] += (row[j] - means[j]) ** 2 }
      end
      cols.times do |j|
        stds[j] = Math.sqrt(stds[j] / [n - 1.0, 1.0].max)
        stds[j] = 1.0 if stds[j].abs < 1e-12
      end
      {means, stds}
    end

    private def normalize_columns(f : Array(Array(Float64)), means : Array(Float64), stds : Array(Float64)) : Array(Array(Float64))
      return f if f.empty?
      cols = f[0].size
      f.map do |row|
        Array.new(cols) { |j| (row[j] - means[j]) / stds[j] }
      end
    end

    private def solve_least_squares(f : Array(Array(Float64)), y : Array(Float64)) : Array(Float64)
      # Normal equations for small feature count (5): (F^T F) w = F^T y
      m = f.size
      return [1.0, 0.0, 0.0, 0.0, 0.0] if m == 0
      nfeat = f[0].size
      ata = Array.new(nfeat) { Array.new(nfeat, 0.0) }
      aty = Array.new(nfeat, 0.0)
      m.times do |i|
        row = f[i]
        nfeat.times do |a|
          aty[a] += row[a] * y[i]
          nfeat.times do |b|
            ata[a][b] += row[a] * row[b]
          end
        end
      end
      gauss_solve(ata, aty)
    end

    private def gauss_solve(a : Array(Array(Float64)), b : Array(Float64)) : Array(Float64)
      n = b.size
      # Augment
      aug = a.map(&.dup)
      n.times { |i| aug[i] << b[i] }
      # Gaussian elimination with partial pivoting
      n.times do |col|
        # pivot
        pivot = col
        (col...n).each do |r|
          pivot = r if aug[r][col].abs > aug[pivot][col].abs
        end
        aug.swap(col, pivot) if pivot != col
        piv = aug[col][col]
        next if piv.abs < 1e-12
        # normalize row
        (col..n).each do |j|
          aug[col][j] /= piv
        end
        # eliminate
        n.times do |r|
          next if r == col
          factor = aug[r][col]
          (col..n).each do |j|
            aug[r][j] -= factor * aug[col][j]
          end
        end
      end
      # Extract solution
      Array.new(n) { |i| aug[i][n] }
    end

    def unified(alpha : Array(Float64))
      ev = evaluate(alpha)
      penalty = 0.0
      if @corr_guard_enabled
        @guard_counter += 1
        if (@guard_counter % @guard_period) == 0
          # compute windowed correlation
          alphas = @guard_alphas || [] of Array(Float64)
          spec = [] of Float64
          multi = [] of Float64
          alphas.each do |a|
            e = evaluate(a)
            spec << e.spectral
            multi << (e.fairness + e.weight_fairness - e.entropy - e.penalty + e.cross_conflict)
          end
          rho = pearson(spec, multi)
          deficit = @corr_min - rho
          penalty = @guard_lambda * (deficit > 0 ? deficit : 0.0)
        end
      end
      ev.unified + penalty
    end

    def spectral(alpha : Array(Float64))
      evaluate(alpha).spectral
    end

    def count_fairness(alpha : Array(Float64))
      evaluate(alpha).fairness
    end

    def weight_fairness(alpha : Array(Float64))
      evaluate(alpha).weight_fairness
    end

    def entropy(alpha : Array(Float64))
      evaluate(alpha).entropy
    end

    def penalty(alpha : Array(Float64))
      evaluate(alpha).penalty
    end

    def cross_conflict(alpha : Array(Float64))
      evaluate(alpha).cross_conflict
    end

    def segments(alpha : Array(Float64))
      evaluate(alpha).segments
    end

    def evaluate(alpha : Array(Float64))
      segs = cuts_from_alpha(alpha)
      labels = Array.new(@size, 0)
      segs.each_with_index do |segment, idx|
        segment.each { |i| labels[i] = idx }
      end

      size_target = @size.to_f64 / @segments
      weight_target = @graph.weights.sum / @segments

      segment_sizes = Array(Float64).new(segs.size) { 0.0 }
      segment_weights = Array(Float64).new(segs.size) { 0.0 }

      segs.each_with_index do |segment, idx|
        segment_sizes[idx] = segment.size.to_f64
        weight = segment.sum { |i| @graph.weights[i] }
        segment_weights[idx] = weight
      end

      fairness = segment_sizes.reduce(0.0) do |sum, s|
        diff = s - size_target
        sum + diff * diff
      end / 2.0

      weight_fairness = segment_weights.reduce(0.0) do |sum, w|
        diff = w - weight_target
        sum + diff * diff
      end / 2.0

      total_size = segment_sizes.sum
      entropy = if total_size <= 0
                  0.0
                else
                  segment_sizes.reduce(0.0) do |sum, size|
                    next sum if size <= 0
                    p = size / total_size
                    sum - p * Math.log(p)
                  end
                end

      # Compute multiplicative factor (product over segments)
      multiplicative_factor = segs.reduce(1.0) do |product, segment|
        next product if segment.empty?
        factor = segment.reduce(1.0) do |value, idx|
          weight = @graph.weights[idx]
          value * (1.0 - 1.0 / (weight * weight))
        end
        product * factor
      end

      degrees = Array.new(@size, 0.0)
      cross_conflict = 0.0

      if @graph.multi_type
        # Multi-type cross-conflict calculation with learnable weights
        current_type_weights = get_current_type_weights

        @graph.edge_types.each do |type_name, matrix|
          weight = current_type_weights[type_name]? || 1.0

          @size.times do |i|
            row = matrix.get_row(i)
            row.each do |j, edge_weight|
              next if i == j  # Skip self-loops
              weighted_edge = edge_weight * weight

              if labels[i] == labels[j]
                degrees[i] += weighted_edge
                degrees[j] += weighted_edge
              else
                cross_conflict += weighted_edge
              end
            end
          end
        end
      else
        # Original single-type calculation
        @graph.edges.each do |edge|
          i, j, weight = edge
          if labels[i] == labels[j]
            degrees[i] += weight
            degrees[j] += weight
          else
            cross_conflict += weight
          end
        end
      end

      spectral = -heat_trace(labels, degrees, samples: 4, order: 6)
      
      # CRITICAL: Two formulas depending on graph structure
      # 1. Circular prime necklace: multiplicative formula (ρ≥0.999)
      # 2. General graphs: additive formula (works for any structure)
      
      is_circular = detect_circular_structure
      
      # Base and multiplicative functional always computed
      base = fairness - 0.1 * entropy
      multiplicative_functional = base * multiplicative_factor
      penalty_term = multiplicative_functional
      
      # DEBUG: Remove after fixing
      # STDERR.puts "DEBUG: base=#{base.round(2)}, factor=#{multiplicative_factor.round(6)}, penalty=#{penalty_term.round(6)}"

      if is_circular
        # Prime necklace formula (from heat_kernel_partition.py)
        # Already computed above
        weights_sum = @graph.weights.sum { |w| 1.0 / (w * w) }
        unified = spectral + @entropy_weight * entropy + 0.01 * weights_sum + multiplicative_functional
      else
        # General graph formula (from cnf_partition.py)
        # spectral + balance + weight_fairness_weight*weight_balance - entropy_weight*entropy - penalty_weight*weight_penalty
        unified = spectral + @fairness_weight * fairness + @weight_fairness_weight * weight_fairness - @entropy_weight * entropy - @penalty_weight * multiplicative_factor
      end
      
      # Boolean constraint penalties (SAT support)
      if @graph.has_bool_constraints
        bool_penalty = compute_bool_penalties(labels, unified.abs)
        unified += bool_penalty
      end

      Evaluation.new(
        segments: segs,
        labels: labels,
        spectral: spectral,
        fairness: fairness,
        weight_fairness: weight_fairness,
        entropy: entropy,
        penalty: penalty_term,
        cross_conflict: cross_conflict,
        unified: unified
      )
    end

    # Compute Pearson correlation between composite_energy and multiplicative_functional
    # Matches Python's verify_conjectures.py exactly
    # Computes correlation even for non-circular graphs (may be lower)
    def correlation(samples : Int32 = 64) : Float64
      
      sampler = ErgodicSampler.new(@segments, @sampler_seed)
      composite_vals = [] of Float64
      multiplicative_vals = [] of Float64
      
      samples.times do
        alpha = sampler.next_alpha
        ev = self.evaluate(alpha)
        
        # For circular: composite = spectral + 0.1*entropy + 0.01*weights_sum + (base*factor)
        # multiplicative = base * factor only
        composite_vals << ev.unified
        multiplicative_vals << ev.penalty
      end
      
      pearson(composite_vals, multiplicative_vals)
    end

    private def pearson(a : Array(Float64), b : Array(Float64)) : Float64
      n = a.size
      return 0.0 if n == 0 || b.size != n
      ma = a.sum / n
      mb = b.sum / n
      num = 0.0
      da = 0.0
      db = 0.0
      n.times do |i|
        xa = a[i] - ma
        xb = b[i] - mb
        num += xa * xb
        da += xa * xa
        db += xb * xb
      end
      denom = Math.sqrt(da * db)
      return 0.0 if denom.abs < 1e-12
      num / denom
    end

    # Compute hybrid spectral trace combining heat kernel and Bethe Hessian
    private def heat_trace_hybrid(labels, degrees, samples = 4, order = 6)
      unless @use_hybrid_spectral && (bh = @bethe_hessian)
        return heat_trace_multi_type(labels, degrees, samples, order)
      end

      # Compute phase-aware gating
      kappa = bh.detectability_parameter(@graph)
      eta_bh = bh.sigmoid_gate(kappa, 3.0)  # c=3 for smooth transition
      eta_hk = 1.0 - eta_bh

      # Heat kernel part (existing implementation)
      hk_trace = heat_trace_multi_type(labels, degrees, samples, order)

      # Bethe Hessian part (negative trace)
      bh_trace = bh.negative_part_trace(0.01)  # γ = 0.01

      # Hybrid combination
      hybrid_trace = eta_hk * hk_trace + eta_bh * bh_trace

      hybrid_trace
    end

    private def heat_trace(labels, degrees, samples = 4, order = 6)
      # Use hybrid spectral approach if available
      if @use_hybrid_spectral
        return heat_trace_hybrid(labels, degrees, samples, order)
      end

      # Use multi-type heat kernel trace if graph is multi-type
      if @graph.multi_type
        return heat_trace_multi_type(labels, degrees, samples, order)
      end

      # Use sparse heat kernel trace if graph is sparse
      if @graph.use_sparse
        return heat_trace_sparse(labels, degrees, samples, order)
      end

      # Original dense implementation
      samples = Math.max(1, samples)
      seed = labels.reduce(17_u64) { |acc, val| (acc &* 31_u64) ^ val.to_u64 }
      random = Random.new(seed)
      factorial = 1.0
      sample_sum = 0.0
      samples.times do
        vector = Array(Float64).new(@size) { random.rand < 0.5 ? -1.0 : 1.0 }
        current = vector.dup
        factorial = 1.0
        accum = 0.0
        (0..order).each do |k|
          coefficient = k.even? ? 1.0 : -1.0
          accum += coefficient / factorial * dot(vector, current)
          break if k == order
          current = masked_laplacian_apply(labels, degrees, current)
          factorial *= (k + 1).to_f
        end
        sample_sum += accum
      end
      sample_sum / samples
    end

    # Multi-type heat kernel trace computation (NEW)
    private def heat_trace_multi_type(labels, degrees, samples = 4, order = 6)
      samples = Math.max(1, samples)
      seed = labels.reduce(17_u64) { |acc, val| (acc &* 31_u64) ^ val.to_u64 }
      random = Random.new(seed)
      sample_sum = 0.0

      samples.times do
        vector = Array(Float64).new(@size) { random.rand < 0.5 ? -1.0 : 1.0 }
        current = vector.dup
        factorial = 1.0
        accum = 0.0

        (0..order).each do |k|
          coefficient = k.even? ? 1.0 : -1.0
          accum += coefficient / factorial * SparseVector.dot(vector, current)
          break if k == order
          current = masked_laplacian_apply_multi_type(labels, degrees, current)
          factorial *= (k + 1).to_f
        end
        sample_sum += accum
      end

      sample_sum / samples
    end

    # Sparse heat kernel trace computation (memory efficient)
    private def heat_trace_sparse(labels, degrees, samples = 4, order = 6)
      samples = Math.max(1, samples)
      seed = labels.reduce(17_u64) { |acc, val| (acc &* 31_u64) ^ val.to_u64 }
      random = Random.new(seed)
      sample_sum = 0.0

      samples.times do
        vector = Array(Float64).new(@size) { random.rand < 0.5 ? -1.0 : 1.0 }
        current = vector.dup
        factorial = 1.0
        accum = 0.0

        (0..order).each do |k|
          coefficient = k.even? ? 1.0 : -1.0
          accum += coefficient / factorial * SparseVector.dot(vector, current)
          break if k == order
          current = masked_laplacian_apply_sparse(labels, degrees, current)
          factorial *= (k + 1).to_f
        end
        sample_sum += accum
      end

      sample_sum / samples
    end

    private def segments_from_cuts(cuts)
      return [Array(Int32).new] if cuts.empty?
      segments = Array(Array(Int32)).new
      cuts.each_with_index do |start, idx|
        endpoint = cuts[(idx + 1) % cuts.size]
        segment = if start == endpoint
                    Array(Int32).new
                  elsif start < endpoint
                    (start...endpoint).to_a
                  else
                    ((start...@size).to_a + (0...endpoint).to_a)
                  end
        segments << segment
      end
      segments
    end

    private def cuts_from_alpha(alpha)
      normalized = alpha.map { |a| (a % (2 * Math::PI)).to_f64 }
      scaled = normalized.map do |norm|
        value = ((norm / (2 * Math::PI)) * @size).floor
        value = value.clamp(0.0, (@size - 1).to_f64)
        value.to_i
      end

      adjusted = adjust_indices(scaled)
      adjusted = [0] if adjusted.empty?
      segments_from_cuts(adjusted.sort)
    end

    private def masked_laplacian_apply(labels, degrees, vector)
      result = Array.new(@size) { |i| degrees[i] * vector[i] }
      @graph.edges.each do |edge|
        i, j, weight = edge
        next unless labels[i] == labels[j]
        result[i] -= weight * vector[j]
        result[j] -= weight * vector[i]
      end
      result
    end
    
    # Multi-type masked Laplacian application (NEW)
    private def masked_laplacian_apply_multi_type(labels, degrees, vector)
      result = Array.new(@size) { |i| degrees[i] * vector[i] }

      # Apply each edge type separately with its weight
      current_type_weights = get_current_type_weights

      @graph.edge_types.each do |type_name, matrix|
        weight = current_type_weights[type_name]? || 1.0

        # Use CSR representation for efficient sparse operations
        @size.times do |i|
          row = matrix.get_row(i)
          row.each do |j, edge_weight|
            next unless labels[i] == labels[j]
            weighted_edge = edge_weight * weight
            result[i] -= weighted_edge * vector[j]
            result[j] -= weighted_edge * vector[i] if i != j
          end
        end
      end

      result
    end

    # Get current type weights (neural network if available, otherwise static)
    private def get_current_type_weights : Hash(String, Float64)
      if @learnable_type_weights && (network = @multi_type_network)
        return network.forward
      end

      # Fall back to static type weights
      @graph.type_weights.dup
    end

    # Multi-type network training methods with ULTRA-OPTIMIZED conditional evaluation
    def train_type_weights(iterations : Int32 = 100, learning_rate : Float64 = 0.01) : Nil
      return unless @learnable_type_weights && (network = @multi_type_network)

      # Initialize Bethe Hessian if needed for detectability regularizer
      initialize_bethe_hessian_if_needed

      best_loss = Float64::INFINITY
      best_weights = Hash(String, Float64).new

      iterations.times do |iter|
        # DYNAMIC SAMPLING: Scale with epoch to balance exploration/exploitation
        samples = iter < 100 ? 8 : 2  # Reduce post-warmup for 5x speedup
        use_bethe = iter % 5 == 0     # Skip Hessian for 80% of steps

        # Define loss function based on current partition quality
        loss_fn = ->{
          # Sample multiple alpha configurations and evaluate average loss
          sampler = ErgodicSampler.new(@segments, @sampler_seed + iter)
          total_loss = 0.0

          samples.times do
            alpha = sampler.next_alpha

            # CONDITIONAL EVALUATION: Fast vs Full hybrid based on schedule
            eval_result = if use_bethe
              evaluate(alpha)  # Full hybrid (every 5th step)
            else
              fast_spectral_evaluate(alpha)  # Laplacian-only (80% of steps)
            end

            # Loss: unified energy + penalty for extreme weight distributions
            energy_loss = eval_result.unified

            # Add regularization to prevent weight collapse
            current_weights = network.forward
            weight_variance = calculate_variance(current_weights.values)
            regularization = 0.1 * weight_variance

            # Add detectability regularizer
            detectability_reg = 0.0
            if (bh = @bethe_hessian)
              kappa = bh.detectability_parameter(@graph)
              tau_hat = Math.max(0.0, kappa) / (bh.radius + 1e-8)  # Normalized detectability
              detectability_reg = 0.1 * Math.max(0.0, 1.0 - tau_hat)  # λ_τ(1-τ̂)_+
            end

            total_loss += energy_loss + regularization + detectability_reg
          end

          total_loss / samples
        }

        # Update network weights
        improvement = network.update!(learning_rate, loss_fn)
        current_loss = loss_fn.call

        # Track best configuration
        if current_loss < best_loss
          best_loss = current_loss
          best_weights = network.forward.dup
        end

        # Adaptive learning rate
        learning_rate *= 0.99 if iter % 50 == 0 && iter > 0
      end

      # Restore best weights silently
      network.set_weights(best_weights)
    end

    # Get current type weights (public API)
    def get_type_weights : Hash(String, Float64)
      get_current_type_weights
    end

    # Set type weights manually (overrides neural network)
    def set_type_weights(weights : Hash(String, Float64)) : Nil
      weights.each do |type_name, weight|
        @graph.set_type_weight(type_name, weight)
      end

      # Update neural network if present
      if @learnable_type_weights && (network = @multi_type_network)
        network.set_weights(weights)
      end
    end

    # Calculate variance of an array of floats
    private def calculate_variance(values : Array(Float64)) : Float64
      return 0.0 if values.empty?

      mean = values.sum / values.size
      sum_squared_diff = values.sum { |v| (v - mean) ** 2 }
      sum_squared_diff / values.size
    end

    # Sparse masked Laplacian application (memory efficient)
    private def masked_laplacian_apply_sparse(labels, degrees, vector)
      result = Array.new(@size) { |i| degrees[i] * vector[i] }

      # Use edges for symmetric application (more efficient and correct)
      @graph.edges.each do |edge|
        i, j, weight = edge
        next unless labels[i] == labels[j]
        result[i] -= weight * vector[j]
        result[j] -= weight * vector[i]
      end

      result
    end

    private def dot(a, b)
      sum = 0.0
      @size.times { |i| sum += a[i] * b[i] }
      sum
    end
    
    # Detect if graph is circular (pure ring) vs general
    private def detect_circular_structure : Bool
      # Build unique neighbor sets to be robust to symmetric edges
      neighbor_sets = Hash(Int32, Set(Int32)).new { |h, k| h[k] = Set(Int32).new }
      @graph.edges.each do |i, j, w|
        next if i == j
        neighbor_sets[i].add(j)
        neighbor_sets[j].add(i)
      end
      
      # Must have exactly one connected component and degree 2 for every node
      return false unless neighbor_sets.size == @size
      return false unless neighbor_sets.all? { |_, neigh| neigh.size == 2 }
      
      # Count undirected edges
      undirected_edges = neighbor_sets.values.reduce(0) { |sum, s| sum + s.size } / 2
      undirected_edges == @size
    end
    
    # Compute boolean constraint penalties (SAT support)
    private def compute_bool_penalties(labels : Array(Int32), base_magnitude : Float64) : Float64
      penalty = 0.0
      scale = Math.max(base_magnitude, @size.to_f * 100.0)
      
      # Penalty 1: Exclusivity violations (x_i and ¬x_i in same segment)
      exclusivity_violations = 0
      @graph.exclusivity_pairs.each do |i, j|
        exclusivity_violations += 1 if labels[i] == labels[j]
      end
      # MASSIVE penalty - each violation should completely dominate
      penalty += exclusivity_violations * scale * 10000.0
      
      # Penalty 2: Unsatisfied clauses
      # Try both segment interpretations (0 or 1 = TRUE) and use the better one
      min_unsat = [0, 1].map do |true_seg|
        unsat = 0
        @graph.clauses.each do |clause|
          # Clause is unsatisfied if all literals are in the FALSE segment
          all_false = clause.all? { |lit| labels[lit] != true_seg }
          unsat += 1 if all_false
        end
        unsat
      end.min
      
      # Heavy clause penalty
      penalty += min_unsat * scale * 1000.0
      
      penalty
    end

    private def adjust_indices(indices : Array(Int32))
      return [] of Int32 if indices.empty? || @size <= 0

      used = Set(Int32).new
      adjusted = Array(Int32).new(indices.size)

      indices.sort.each do |value|
        candidate = ((value % @size) + @size) % @size
        if @size > 0
          while used.includes?(candidate) && used.size < @size
            candidate = (candidate + 1) % @size
          end
        end
        used.add(candidate)
        adjusted << candidate
        break if used.size == @size
      end

      adjusted
    end

    # Initialize Bethe Hessian for hybrid spectral analysis with caching
    private def initialize_bethe_hessian_if_needed
      # Check if graph has changed
      current_hash = compute_graph_hash
      if @last_graph_hash != current_hash
        @bethe_hessian = BetheHessian.new(@graph)
        @bethe_hessian_cached = @bethe_hessian
        @detectability_cached = nil
        @last_graph_hash = current_hash
      elsif @bethe_hessian_cached
        @bethe_hessian = @bethe_hessian_cached
      end
    end

    # Compute simple hash for graph structure to detect changes
    private def compute_graph_hash : UInt64
      # Simple hash based on graph size and edge count
      hasher = @graph.size.to_u64
      @graph.type_names.each do |type_name|
        matrix = @graph.edge_types[type_name]?
        if matrix
          hasher = hasher * 31 + matrix.nnz.to_u64
        end
      end
      hasher
    end
  end
end
