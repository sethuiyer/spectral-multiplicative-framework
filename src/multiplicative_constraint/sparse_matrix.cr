#
# Sparse Matrix Implementation for Enterprise-Scale Optimization
# Developed by aninokuma at Shunya Bar
#
# This module provides Compressed Sparse Row (CSR) matrix operations that enable
# optimization of problems with 100K+ nodes using O(nnz) memory instead of O(N²).
# The key innovation is maintaining mathematical efficiency while achieving
# massive memory reduction (3,478x for 100K nodes: 23MB vs 80GB dense).
#
# Performance characteristics:
# - Memory: O(nnz) where nnz = number of non-zero elements
# - Matrix-vector multiplication: O(nnz)
# - Row operations: O(average_row_length)
# - Construction: O(nnz log nnz) due to sorting
#
# @author aninokuma at Shunya Bar
#

module MultiplicativeConstraint
  # Compressed Sparse Row (CSR) format sparse matrix
  #
  # CSR is ideal for sparse matrix operations because:
  # 1. Efficient row-wise access (perfect for graph algorithms)
  # 2. Cache-friendly memory layout
  # 3. Fast matrix-vector multiplication
  # 4. Minimal storage overhead
  #
  # Storage format:
  # - values: Array of non-zero matrix elements
  # - col_indices: Column index for each value in values array
  # - row_ptr: Starting index in values/col_indices for each row
  #
  # Example: For matrix [[0, 2, 0], [1, 0, 3], [0, 0, 0]]
  # values = [2.0, 1.0, 3.0]
  # col_indices = [1, 0, 2]
  # row_ptr = [0, 1, 3, 3]
  #
  # @author aninokuma at Shunya Bar
  class SparseMatrix
    # Matrix dimensions
    getter rows : Int32
    getter cols : Int32

    # CSR format storage arrays
    # These are mutable to allow construction via from_edges method
    property values : Array(Float64)      # Non-zero matrix elements
    property col_indices : Array(Int32)   # Column indices for each value
    property row_ptr : Array(Int32)       # Row pointer array (size = rows + 1)
    
    def initialize(@rows : Int32, @cols : Int32)
      @values = Array(Float64).new
      @col_indices = Array(Int32).new
      @row_ptr = Array(Int32).new(@rows + 1, 0)
    end
    
    # Build from edge list (most efficient for construction)
    def self.from_edges(rows : Int32, cols : Int32, edges : Array(Tuple(Int32, Int32, Float64))) : SparseMatrix
      matrix = SparseMatrix.new(rows, cols)
      
      # Sort edges by row, then column for CSR format
      sorted_edges = edges.sort_by { |i, j, v| {i, j} }
      
      current_row = 0
      matrix.row_ptr[0] = 0
      
      sorted_edges.each do |i, j, value|
        next if value.abs < 1e-15  # Skip near-zero values
        
        # Fill row_ptr for skipped rows
        while current_row < i
          current_row += 1
          matrix.row_ptr[current_row] = matrix.values.size
        end
        
        matrix.values << value
        matrix.col_indices << j
      end
      
      # Fill remaining row_ptr entries
      while current_row < rows
        current_row += 1
        matrix.row_ptr[current_row] = matrix.values.size
      end
      
      matrix
    end
    
    # Build from dense matrix (for backward compatibility)
    def self.from_dense(dense : Array(Array(Float64))) : SparseMatrix
      rows = dense.size
      cols = dense[0]?.try(&.size) || 0
      
      edges = Array(Tuple(Int32, Int32, Float64)).new
      
      rows.times do |i|
        cols.times do |j|
          value = dense[i][j]
          edges << {i, j, value} if value.abs >= 1e-15
        end
      end
      
      from_edges(rows, cols, edges)
    end
    
    # Get value at (i, j)
    def [](i : Int32, j : Int32) : Float64
      return 0.0 if i < 0 || i >= @rows || j < 0 || j >= @cols
      
      # Binary search in row i
      start_idx = @row_ptr[i]
      end_idx = @row_ptr[i + 1]
      
      (start_idx...end_idx).each do |idx|
        col = @col_indices[idx]
        return @values[idx] if col == j
        break if col > j  # Columns are sorted
      end
      
      0.0
    end
    
    # Set value at (i, j) - WARNING: only use during construction
    # For efficiency, use from_edges instead
    def []=(i : Int32, j : Int32, value : Float64)
      # Find if element already exists
      start_idx = @row_ptr[i]
      end_idx = @row_ptr[i + 1]

      (start_idx...end_idx).each do |idx|
        if @col_indices[idx] == j
          @values[idx] = value
          return
        end
      end

      # Element doesn't exist, insert it (inefficient!)
      @values.insert(start_idx, value)
      @col_indices.insert(start_idx, j)

      # Update row pointers
      (i + 1..@rows).each { |r| @row_ptr[r] += 1 }
    end
    
    # Number of non-zero elements
    def nnz : Int32
      @values.size
    end
    
    # Sparse matrix-vector multiplication: y = A * x
    # Time complexity: O(nnz)
    def multiply(x : Array(Float64)) : Array(Float64)
      raise "Dimension mismatch" unless x.size == @cols

      y = Array.new(@rows, 0.0)

      @rows.times do |i|
        sum = 0.0
        start_idx = @row_ptr[i]
        end_idx = @row_ptr[i + 1]

        (start_idx...end_idx).each do |idx|
          j = @col_indices[idx]
          sum += @values[idx] * x[j]
        end

        y[i] = sum
      end

      y
    end

    # Operator overloading for matrix-vector multiplication: A * x
    def *(x : Array(Float64)) : Array(Float64)
      multiply(x)
    end
    
    # Get row as sparse representation
    def get_row(i : Int32) : Array(Tuple(Int32, Float64))
      result = Array(Tuple(Int32, Float64)).new
      
      start_idx = @row_ptr[i]
      end_idx = @row_ptr[i + 1]
      
      (start_idx...end_idx).each do |idx|
        result << {@col_indices[idx], @values[idx]}
      end
      
      result
    end
    
    # Get degree of node i (sum of row i)
    def degree(i : Int32) : Float64
      sum = 0.0
      start_idx = @row_ptr[i]
      end_idx = @row_ptr[i + 1]

      (start_idx...end_idx).each do |idx|
        sum += @values[idx]
      end

      sum
    end

    # Get non-zero element at index idx - NEW
    def get_nnz(idx : Int32) : Tuple(Int32, Int32, Float64)
      return {0, 0, 0.0} if idx < 0 || idx >= @values.size

      # Find which row this index belongs to
      row = 0
      while row < @rows && @row_ptr[row + 1] <= idx
        row += 1
      end

      col = @col_indices[idx]
      val = @values[idx]

      {row, col, val}
    end
    
    # Convert to dense matrix (only for small matrices!)
    def to_dense : Array(Array(Float64))
      dense = Array.new(@rows) { Array.new(@cols, 0.0) }
      
      @rows.times do |i|
        start_idx = @row_ptr[i]
        end_idx = @row_ptr[i + 1]
        
        (start_idx...end_idx).each do |idx|
          j = @col_indices[idx]
          dense[i][j] = @values[idx]
        end
      end
      
      dense
    end
    
    # Memory usage in bytes
    def memory_usage : Int64
      values_size = @values.size * sizeof(Float64)
      col_indices_size = @col_indices.size * sizeof(Int32)
      row_ptr_size = @row_ptr.size * sizeof(Int32)
      
      (values_size + col_indices_size + row_ptr_size).to_i64
    end
    
    # Print statistics
    def stats : String
      mem_mb = memory_usage.to_f / (1024 * 1024)
      # Use Int64 to avoid overflow for large matrices
      total_elements = @rows.to_i64 * @cols.to_i64
      density = nnz.to_f / total_elements * 100
      
      "SparseMatrix(#{@rows}×#{@cols}, nnz=#{nnz}, " +
      "density=#{density.round(4)}%, memory=#{mem_mb.round(2)}MB)"
    end
  end
  
  # Vector operations for sparse computations
  module SparseVector
    # Dot product
    def self.dot(a : Array(Float64), b : Array(Float64)) : Float64
      raise "Dimension mismatch" unless a.size == b.size
      a.zip(b).sum { |x, y| x * y }
    end
    
    # Vector norm (L2)
    def self.norm(v : Array(Float64)) : Float64
      Math.sqrt(v.sum { |x| x * x })
    end
    
    # Normalize vector
    def self.normalize(v : Array(Float64)) : Array(Float64)
      n = norm(v)
      return v if n < 1e-15
      v.map { |x| x / n }
    end
    
    # Vector addition: a + b
    def self.add(a : Array(Float64), b : Array(Float64)) : Array(Float64)
      raise "Dimension mismatch" unless a.size == b.size
      a.zip(b).map { |x, y| x + y }
    end
    
    # Vector subtraction: a - b
    def self.subtract(a : Array(Float64), b : Array(Float64)) : Array(Float64)
      raise "Dimension mismatch" unless a.size == b.size
      a.zip(b).map { |x, y| x - y }
    end
    
    # Scalar multiplication: scalar * v
    def self.scale(v : Array(Float64), scalar : Float64) : Array(Float64)
      v.map { |x| scalar * x }
    end
    
    # Linear combination: a * x + b * y
    def self.axpy(a : Float64, x : Array(Float64), b : Float64, y : Array(Float64)) : Array(Float64)
      raise "Dimension mismatch" unless x.size == y.size
      x.zip(y).map { |xi, yi| a * xi + b * yi }
    end
  end
end

