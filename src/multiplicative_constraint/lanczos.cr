# Lanczos Iterative Eigenvalue Solver
# Computes k largest/smallest eigenvalues without dense matrix operations
# Time: O(k × nnz × iterations), Memory: O(N)

module MultiplicativeConstraint
  # Lanczos algorithm for sparse symmetric matrices
  # Finds k largest or smallest eigenvalues efficiently
  class LanczosEigensolver
    property matrix : SparseMatrix
    property k : Int32
    property max_iter : Int32
    property tolerance : Float64
    property largest : Bool
    
    def initialize(@matrix : SparseMatrix, @k : Int32 = 10, @max_iter : Int32 = 100, 
                   @tolerance : Float64 = 1e-10, @largest : Bool = false)
      raise "Matrix must be square" unless @matrix.rows == @matrix.cols
      raise "k must be positive and less than matrix size" unless @k > 0 && @k < @matrix.rows
    end
    
    # Solve for k eigenvalues and eigenvectors
    # Returns: {eigenvalues, eigenvectors}
    def solve : Tuple(Array(Float64), Array(Array(Float64)))
      n = @matrix.rows
      
      # Initialize with random vector
      v_prev = Array.new(n, 0.0)
      v = Array.new(n) { rand }
      v = SparseVector.normalize(v)
      
      # Storage for Lanczos vectors and tridiagonal matrix
      alpha = Array(Float64).new
      beta = Array(Float64).new
      lanczos_vectors = Array(Array(Float64)).new
      lanczos_vectors << v.dup
      
      # Lanczos iteration
      actual_iters = 0
      @max_iter.times do |j|
        # Matrix-vector multiplication: w = A * v
        w = @matrix.multiply(v)
        
        # Compute diagonal element: α_j = v^T * w
        a = SparseVector.dot(v, w)
        alpha << a
        
        # Orthogonalize: w = w - α_j * v
        w = SparseVector.subtract(w, SparseVector.scale(v, a))
        
        # Orthogonalize against previous vector
        if j > 0
          w = SparseVector.subtract(w, SparseVector.scale(v_prev, beta[-1]))
        end
        
        # Compute off-diagonal element: β_{j+1} = ||w||
        b = SparseVector.norm(w)
        
        # Check for convergence
        break if b < @tolerance
        
        beta << b
        
        # Prepare for next iteration
        v_prev = v.dup
        v = SparseVector.scale(w, 1.0 / b)
        lanczos_vectors << v.dup
        
        actual_iters = j + 1
      end
      
      # Solve tridiagonal eigenvalue problem
      tridiag_eigenvalues = solve_tridiagonal_eigenvalues(alpha, beta)
      pairs = tridiag_eigenvalues.each_with_index.to_a
      
      # Select k eigenvalues (largest or smallest)
      selected_indices = if @largest
        pairs.sort_by { |pair| -pair[0] }.first(@k).map { |pair| pair[1] }
      else
        pairs.sort_by { |pair| pair[0] }.first(@k).map { |pair| pair[1] }
      end
      
      selected_eigenvalues = selected_indices.map { |idx| tridiag_eigenvalues[idx] }
      
      # Compute Ritz vectors (approximate eigenvectors)
      # For simplicity, use a basic approximation
      # Full implementation would compute eigenvectors of tridiagonal matrix
      # and transform back using Lanczos vectors
      selected_eigenvectors = approximate_eigenvectors(lanczos_vectors, selected_eigenvalues, alpha, beta)
      
      {selected_eigenvalues, selected_eigenvectors}
    end
    
    # Solve tridiagonal eigenvalue problem using QR algorithm
    private def solve_tridiagonal_eigenvalues(alpha : Array(Float64), beta : Array(Float64)) : Array(Float64)
      n = alpha.size
      return alpha.dup if n == 0
      
      # Initialize with diagonal elements
      eigenvalues = alpha.dup
      
      # Simple iterative refinement (simplified QR)
      # For production, use LAPACK-style QR with shifts
      max_qr_iter = 30
      
      max_qr_iter.times do
        converged = true
        
        (n - 1).times do |i|
          # Check if off-diagonal element is small enough
          next if i >= beta.size
          
          if beta[i].abs > @tolerance * (eigenvalues[i].abs + eigenvalues[i + 1].abs)
            converged = false
            
            # Simple Givens rotation to reduce off-diagonal
            a = eigenvalues[i]
            b = beta[i]
            c = eigenvalues[i + 1]
            
            # Compute rotation angle
            if b.abs < @tolerance
              next
            end
            
            tau = (c - a) / (2.0 * b)
            t = if tau >= 0
              1.0 / (tau + Math.sqrt(1.0 + tau * tau))
            else
              -1.0 / (-tau + Math.sqrt(1.0 + tau * tau))
            end
            
            cos_theta = 1.0 / Math.sqrt(1.0 + t * t)
            sin_theta = t * cos_theta
            
            # Update eigenvalues approximation
            eigenvalues[i] = a - t * b
            eigenvalues[i + 1] = c + t * b
          end
        end
        
        break if converged
      end
      
      eigenvalues
    end
    
    # Approximate eigenvectors using Lanczos vectors
    private def approximate_eigenvectors(lanczos_vectors : Array(Array(Float64)),
                                        eigenvalues : Array(Float64),
                                        alpha : Array(Float64),
                                        beta : Array(Float64)) : Array(Array(Float64))
      n = @matrix.rows
      eigenvectors = Array(Array(Float64)).new
      
      # For each selected eigenvalue, create an approximate eigenvector
      # This is a simplified version - full version would solve tridiagonal eigenvector problem
      eigenvalues.each_with_index do |lambda, idx|
        # Use Rayleigh quotient iteration approximation
        # Start with linear combination of Lanczos vectors weighted by eigenvalue proximity
        v = Array.new(n, 0.0)
        
        lanczos_vectors.each_with_index do |lv, j|
          next if j >= alpha.size
          
          # Weight by how close this Lanczos iteration is to the eigenvalue
          weight = 1.0 / (1.0 + (alpha[j] - lambda).abs)
          
          n.times do |i|
            v[i] += weight * lv[i]
          end
        end
        
        # Normalize
        v = SparseVector.normalize(v)
        eigenvectors << v
      end
      
      eigenvectors
    end
    
    # Power iteration for single largest eigenvalue (simpler fallback)
    def power_iteration(max_iter : Int32 = 100) : Tuple(Float64, Array(Float64))
      n = @matrix.rows
      
      # Random initial vector
      v = Array.new(n) { rand }
      v = SparseVector.normalize(v)
      
      eigenvalue = 0.0
      
      max_iter.times do
        # v_new = A * v
        v_new = @matrix.multiply(v)
        
        # Compute Rayleigh quotient: λ = v^T * A * v / v^T * v
        eigenvalue = SparseVector.dot(v, v_new)
        
        # Normalize for next iteration
        v_new = SparseVector.normalize(v_new)
        
        # Check convergence
        diff = SparseVector.subtract(v_new, v)
        if SparseVector.norm(diff) < @tolerance
          v = v_new
          break
        end
        
        v = v_new
      end
      
      {eigenvalue, v}
    end
    
    # Estimate spectral radius (largest absolute eigenvalue)
    def spectral_radius : Float64
      lambda_max, _ = power_iteration
      lambda_max.abs
    end
    
    # Estimate condition number (ratio of largest to smallest eigenvalue)
    def condition_number : Float64
      # Find largest and smallest eigenvalues
      solver_max = LanczosEigensolver.new(@matrix, k: 1, largest: true)
      lambda_max, _ = solver_max.solve
      
      solver_min = LanczosEigensolver.new(@matrix, k: 1, largest: false)
      lambda_min, _ = solver_min.solve
      
      return Float64::INFINITY if lambda_min[0].abs < @tolerance
      
      lambda_max[0].abs / lambda_min[0].abs
    end
  end
  
  # Fast heat kernel trace computation using Lanczos
  # Computes Tr(exp(-β * L)) without full eigendecomposition
  class HeatKernelTrace
    property matrix : SparseMatrix
    property beta : Float64
    property num_samples : Int32
    
    def initialize(@matrix : SparseMatrix, @beta : Float64 = 1.0, @num_samples : Int32 = 4)
    end
    
    # Stochastic trace estimation using Hutchinson's method
    # Tr(exp(-β * L)) ≈ (1/num_samples) * Σ_i v_i^T * exp(-β * L) * v_i
    def compute : Float64
      n = @matrix.rows
      trace_estimate = 0.0
      
      @num_samples.times do
        # Random probe vector (Rademacher: +1 or -1)
        v = Array.new(n) { rand < 0.5 ? 1.0 : -1.0 }
        
        # Compute exp(-β * L) * v using Taylor series or Lanczos
        exp_lv = matrix_exponential_vector_product(v)
        
        # Add v^T * exp(-β * L) * v to trace estimate
        trace_estimate += SparseVector.dot(v, exp_lv)
      end
      
      trace_estimate / @num_samples
    end
    
    # Compute exp(-β * L) * v using polynomial approximation
    private def matrix_exponential_vector_product(v : Array(Float64)) : Array(Float64)
      # Taylor series: exp(-β * L) ≈ Σ_{k=0}^m (-β * L)^k / k!
      # We use m = 6 terms for good approximation
      
      result = v.dup  # k=0 term: I * v
      lk_v = v.dup    # L^k * v
      factorial = 1.0
      beta_power = 1.0
      
      6.times do |k|
        next if k == 0
        
        # L^k * v = L * (L^{k-1} * v)
        lk_v = @matrix.multiply(lk_v)
        
        # Update factorial and beta power
        factorial *= k
        beta_power *= @beta
        
        # Add (-β)^k * L^k * v / k! to result
        coefficient = (-beta_power) / factorial
        
        v.size.times do |i|
          result[i] += coefficient * lk_v[i]
        end
      end
      
      result
    end
    
    # Alternative: Compute trace using Lanczos eigenvalues
    def compute_via_eigenvalues(k : Int32 = 20) : Float64
      solver = LanczosEigensolver.new(@matrix, k: k, largest: false)
      eigenvalues, _ = solver.solve
      
      # Tr(exp(-β * L)) ≈ Σ_i exp(-β * λ_i)
      # We approximate with k smallest eigenvalues (largest contribution)
      eigenvalues.sum { |lambda| Math.exp(-@beta * lambda) }
    end
  end
end

