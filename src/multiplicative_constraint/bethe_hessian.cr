module MultiplicativeConstraint
  # Bethe Hessian and Non-Backtracking Operator Implementation
  # Based on Alaa Saade's doctoral thesis for sparse graph spectral analysis

  class BetheHessian
    getter matrix : SparseMatrix
    getter radius : Float64
    getter edge_count : Int32

    # Cache for expensive computations
    @detectability_cache : Float64?
    @negative_trace_cache : Hash(Float64, Float64)

    def initialize(graph : Graph)
      @edge_count = graph.edges.size
      @radius = compute_bethe_radius(graph)
      @matrix = build_bethe_hessian(graph, @radius)
      @detectability_cache = nil
      @negative_trace_cache = Hash(Float64, Float64).new
    end

    # Compute the Bethe free energy radius R̂ = sqrt((⟨d²⟩ - ⟨d⟩)/⟨d⟩)
    private def compute_bethe_radius(graph : Graph) : Float64
      if graph.multi_type
        compute_multi_type_radius(graph)
      else
        compute_single_type_radius(graph)
      end
    end

    private def compute_single_type_radius(graph : Graph) : Float64
      degrees = Array.new(graph.size) { |i| graph.degree(i) }
      mean_deg = degrees.sum / degrees.size.to_f64
      mean_sq_deg = degrees.sum { |d| d * d } / degrees.size.to_f64

      return 1.0 if mean_deg == 0

      radius = Math.sqrt((mean_sq_deg - mean_deg) / mean_deg)
      radius.clamp(0.1, 10.0)  # Prevent numerical issues
    end

    private def compute_multi_type_radius(graph : Graph) : Float64
      # Weighted degrees using current type weights
      degrees = Array.new(graph.size) do |i|
        graph.weighted_degree(i)
      end

      mean_deg = degrees.sum / degrees.size.to_f64
      mean_sq_deg = degrees.sum { |d| d * d } / degrees.size.to_f64

      return 1.0 if mean_deg == 0

      radius = Math.sqrt((mean_sq_deg - mean_deg) / mean_deg)
      radius.clamp(0.1, 10.0)
    end

    # Build Bethe Hessian H(r) = (r²-1)I - rA + D
    private def build_bethe_hessian(graph : Graph, r : Float64) : SparseMatrix
      n = graph.size

      # Get adjacency matrix
      adj = graph.get_sparse_adjacency

      # Build H = (r²-1)I - rA + D
      h_data = Hash(Tuple(Int32, Int32), Float64).new

      # Diagonal terms: (r²-1)I + D
      (0...n).each do |i|
        degree = graph.degree(i)
        h_data[{i, i}] = (r * r - 1.0) + degree
      end

      # Off-diagonal terms: -rA
      adj.nnz.times do |idx|
        i, j, val = adj.get_nnz(idx)
        next if i == j

        # Add symmetric off-diagonal entries
        h_data[{i, j}] = (h_data[{i, j}]? || 0.0) - r * val
        h_data[{j, i}] = (h_data[{j, i}]? || 0.0) - r * val
      end

      # Convert to sparse matrix
      edges = h_data.map { |(i, j), val| {i, j, val} }
      SparseMatrix.from_edges(n, n, edges)
    end

    # Compute smooth negative part trace using φ_γ(λ) = γ * log(1 + exp(-λ/γ))
    def negative_part_trace(gamma : Float64 = 0.01) : Float64
      # Check cache first
      if @negative_trace_cache.has_key?(gamma)
        return @negative_trace_cache[gamma]
      end

      # Use stochastic Lanczos quadrature for trace estimation
      # For now, use simple power iteration to estimate negative eigenvalues
      result = estimate_negative_trace_via_power_method(gamma)

      # Cache the result
      @negative_trace_cache[gamma] = result
      result
    end

    private def estimate_negative_trace_via_power_method(gamma : Float64) : Float64
      n = @matrix.rows
      # Reduced trials for speed - 8 was too expensive
      num_trials = 3
      negative_trace = 0.0

      num_trials.times do
        # Random vector
        v = Array.new(n) { rand_gaussian }

        # Reduced iterations from 50 to 20 for speed
        lambda_max = power_iteration(@matrix, v, 20)

        # If negative, add to trace with smooth negative part
        if lambda_max < 0
          negative_trace += smooth_negative_part(lambda_max, gamma)
        end
      end

      (negative_trace * n) / num_trials
    end

    private def smooth_negative_part(lambda : Float64, gamma : Float64) : Float64
      # φ_γ(λ) = γ * log(1 + exp(-λ/γ))
      gamma * Math.log(1.0 + Math.exp(-lambda / gamma))
    end

    # Highly optimized power iteration with Rayleigh acceleration
    private def power_iteration(matrix : SparseMatrix, v : Array(Float64), max_iter : Int32, tolerance : Float64 = 1e-5) : Float64
      current = v.dup
      prev_lambda = -Float64::MAX

      max_iter.times do |i|
        # Sparse matrix-vector multiplication
        next_vec = matrix * current

        # Normalize
        norm = Math.sqrt(next_vec.sum { |x| x * x })
        break if norm < 1e-10

        next_vec.map! { |x| x / norm }

        # Rayleigh quotient for faster convergence
        lambda = rayleigh_quotient(matrix, next_vec)

        # Adaptive convergence check after initial warmup
        if i > 10 && (lambda - prev_lambda).abs < tolerance
          current = next_vec
          break
        end

        current = next_vec
        prev_lambda = lambda
      end

      # Final Rayleigh quotient
      rayleigh_quotient(matrix, current)
    end

    private def rayleigh_quotient(matrix : SparseMatrix, v : Array(Float64)) : Float64
      n = v.size
      numerator = 0.0
      denominator = 0.0

      # Compute v^T * H * v
      hv = Array.new(n, 0.0)
      matrix.nnz.times do |idx|
        i, j, val = matrix.get_nnz(idx)
        hv[i] += val * v[j]
      end

      numerator = v.zip(hv).sum { |vi, hvi| vi * hvi }
      denominator = v.sum { |vi| vi * vi }

      denominator > 0 ? numerator / denominator : 0.0
    end

    # Estimate detectability parameter κ = λ_max(B) - R̂
    def detectability_parameter(graph : Graph) : Float64
      # Check cache first
      if cached = @detectability_cache
        return cached
      end

      # Estimate λ_max(B) using power method on non-backtracking operator
      lambda_max_b = estimate_non_backtracking_max_eigenvalue(graph)
      result = lambda_max_b - @radius

      # Cache the result
      @detectability_cache = result
      result
    end

    # Ultra-fast approximation of non-backtracking operator's largest eigenvalue
    private def estimate_non_backtracking_max_eigenvalue(graph : Graph) : Float64
      # OPTIMIZATION: Use Hashimoto matrix upper bound for sparse graphs
      avg_degree = graph.edges.size.to_f64 / graph.size.to_f64
      max_degree = graph.max_degree

      if avg_degree < 4.0
        # O(1) heuristic for sparse graphs - avoids expensive computation
        return Math.sqrt(max_degree.to_f64)
      end

      # Fallback: reduced power method for denser graphs (was 30, now 10)
      adj = graph.get_sparse_adjacency
      v = Array.new(adj.rows) { rand_gaussian }
      lambda_max_a = power_iteration(adj, v, 10)

      Math.sqrt(lambda_max_a.clamp(0.0, Float64::MAX))
    end

    # Sigmoid gate for phase-aware mixing
    def sigmoid_gate(kappa : Float64, c : Float64 = 3.0) : Float64
      1.0 / (1.0 + Math.exp(-c * kappa))
    end

    # Weighted cut ratio - improved cross-conflict metric
    def weighted_cut_ratio(graph : Graph, labels : Array(Int32)) : Float64
      segments = Hash(Int32, Array(Int32)).new
      labels.each_with_index do |label, node|
        segments[label] ||= [] of Int32
        segments[label] << node
      end

      # Calculate total volume more directly
      total_weight = graph.weights.sum
      total_vol = total_weight * 2.0  # Simple approximation for normalization
      return 0.0 if total_vol == 0.0

      cut = 0.0
      graph.edges.each do |(i, j, weight)|
        seg_i, seg_j = labels[i], labels[j]
        next if seg_i == seg_j

        # Harmonic mean balances weight/count sensitivity
        size_i = segments[seg_i].size
        size_j = segments[seg_j].size
        balance_factor = 1.0 + (size_i - size_j).abs.to_f64

        cut += (graph.weights[i] * graph.weights[j] * weight) / balance_factor
      end

      cut / total_vol  # Normalized scale
    end

    # Compute Spearman correlation between spectral and multiplicative terms
    def compute_spectral_multiplicative_correlation(
      graph : Graph,
      labels : Array(Int32),
      spectral_actions : Array(Float64),
      multiplicative_penalties : Array(Float64)
    ) : Float64
      n = spectral_actions.size
      return 1.0 if n < 2

      # Rank the arrays
      ranked_spectral = spectral_actions.map_with_index { |val, idx| {val, idx} }.sort_by { |val, idx| val }.map_with_index { |(val, orig_idx), rank| {orig_idx, rank.to_f64} }.sort_by { |idx, rank| idx }.map { |idx, rank| rank }
      ranked_mult = multiplicative_penalties.map_with_index { |val, idx| {val, idx} }.sort_by { |val, idx| val }.map_with_index { |(val, orig_idx), rank| {orig_idx, rank.to_f64} }.sort_by { |idx, rank| idx }.map { |idx, rank| rank }

      # Pearson correlation on ranks
      mean_spectral = ranked_spectral.sum / n
      mean_mult = ranked_mult.sum / n

      numerator = (0...n).sum { |i| (ranked_spectral[i] - mean_spectral) * (ranked_mult[i] - mean_mult) }
      denom_spectral = Math.sqrt((0...n).sum { |i| (ranked_spectral[i] - mean_spectral) ** 2 })
      denom_mult = Math.sqrt((0...n).sum { |i| (ranked_mult[i] - mean_mult) ** 2 })

      return 0.0 if denom_spectral == 0.0 || denom_mult == 0.0
      numerator / (denom_spectral * denom_mult)
    end

    # Gaussian random number generator
    private def rand_gaussian : Float64
      # Box-Muller transform
      u1 = rand
      u2 = rand
      Math.sqrt(-2.0 * Math.log(u1)) * Math.cos(2.0 * Math::PI * u2)
    end
  end
end