module MultiplicativeConstraint
  class Graph
    getter adjacency : Array(Array(Float64))?
    getter sparse_adjacency : SparseMatrix?
    getter weights : Array(Float64)
    getter edges : Array(Tuple(Int32, Int32, Float64))
    getter use_sparse : Bool

    # Multi-type support
    getter edge_types : Hash(String, SparseMatrix)
    getter type_weights : Hash(String, Float64)
    getter multi_type : Bool = false
    
    # Boolean constraint support (for SAT problems)
    getter exclusivity_pairs : Array(Tuple(Int32, Int32))
    getter clauses : Array(Array(Int32))
    getter has_bool_constraints : Bool = false

    # Dense adjacency constructor (backward compatible)
    def initialize(weights : Array(Float64), dense_adjacency : Array(Array(Float64)))
      @weights = weights
      raise ArgumentError.new("weights cannot be empty") if @weights.empty?
      raise ArgumentError.new("adjacency must be square") unless square?(dense_adjacency)
      raise ArgumentError.new("dimension mismatch") unless dense_adjacency.size == @weights.size

      @adjacency = dense_adjacency
      @sparse_adjacency = nil
      @use_sparse = false
      @edges = build_edges(dense_adjacency)

      # Initialize multi-type support as single-type
      @edge_types = Hash(String, SparseMatrix).new
      @type_weights = Hash(String, Float64).new
      @multi_type = false
      
      # Initialize boolean constraints (empty by default)
      @exclusivity_pairs = Array(Tuple(Int32, Int32)).new
      @clauses = Array(Array(Int32)).new
      @has_bool_constraints = false
    end

      # Sparse adjacency constructor (efficient for large graphs)
    def initialize(weights : Array(Float64), edges : Array(Tuple(Int32, Int32, Float64)))
      @weights = weights
      @edges = edges
      raise ArgumentError.new("weights cannot be empty") if @weights.empty?

      n = @weights.size
      @sparse_adjacency = SparseMatrix.from_edges(n, n, @edges)
      @adjacency = nil
      @use_sparse = true

      # Initialize multi-type support as single-type
      @edge_types = Hash(String, SparseMatrix).new
      @type_weights = Hash(String, Float64).new
      @multi_type = false
      
      # Initialize boolean constraints (empty by default)
      @exclusivity_pairs = Array(Tuple(Int32, Int32)).new
      @clauses = Array(Array(Int32)).new
      @has_bool_constraints = false
    end

    # Create from edge list with automatic symmetry
    def self.from_edges(weights : Array(Float64), edges : Array(Tuple(Int32, Int32, Float64)), symmetric : Bool = true)
      if symmetric
        # Add reverse edges for undirected graphs
        symmetric_edges = Array(Tuple(Int32, Int32, Float64)).new
        edges.each do |i, j, w|
          symmetric_edges << {i, j, w}
          symmetric_edges << {j, i, w} unless i == j
        end
        new(weights, symmetric_edges)
      else
        new(weights, edges)
      end
    end

    # Multi-type constructor - NEW
    def initialize(
      weights : Array(Float64),
      edge_types : Hash(String, SparseMatrix),
      type_weights : Hash(String, Float64) = Hash(String, Float64).new
    )
      @weights = weights
      @edge_types = edge_types
      @type_weights = type_weights
      raise ArgumentError.new("weights cannot be empty") if @weights.empty?
      raise ArgumentError.new("edge_types cannot be empty") if @edge_types.empty?

      # Validate that all edge type matrices have correct dimensions
      n = @weights.size
      @edge_types.each do |type_name, matrix|
        raise ArgumentError.new("Edge type '#{type_name}' matrix must be #{n}×#{n}") unless matrix.rows == n && matrix.cols == n
      end

      # Set default weights if not provided
      @edge_types.keys.each do |type_name|
        @type_weights[type_name] = 1.0 unless @type_weights.has_key?(type_name)
      end

      # Backward compatibility: create single combined adjacency for existing code
      @edges = build_edges_from_types
      @sparse_adjacency = combine_edge_types
      @adjacency = nil
      @use_sparse = true
      @multi_type = true
      
      # Initialize boolean constraints (empty by default)
      @exclusivity_pairs = Array(Tuple(Int32, Int32)).new
      @clauses = Array(Array(Int32)).new
      @has_bool_constraints = false
    end

    # Create from multi-type edge lists - NEW
    def self.from_multi_type_edges(
      weights : Array(Float64),
      edge_type_lists : Hash(String, Array(Tuple(Int32, Int32, Float64))),
      type_weights : Hash(String, Float64) = Hash(String, Float64).new,
      symmetric : Bool = true
    )
      raise ArgumentError.new("weights cannot be empty") if weights.empty?
      raise ArgumentError.new("edge_type_lists cannot be empty") if edge_type_lists.empty?

      n = weights.size
      edge_types = Hash(String, SparseMatrix).new

      edge_type_lists.each do |type_name, edges|
        processed_edges = symmetric ? self.make_symmetric_edges(edges) : edges
        edge_types[type_name] = SparseMatrix.from_edges(n, n, processed_edges)
      end

      new(weights, edge_types, type_weights)
    end
    
    # SAT-specific constructor with boolean constraints
    def self.from_sat(
      weights : Array(Float64),
      edges : Array(Tuple(Int32, Int32, Float64)),
      exclusivity_pairs : Array(Tuple(Int32, Int32)),
      clauses : Array(Array(Int32))
    )
      graph = from_edges(weights, edges, symmetric: false)
      graph.set_bool_constraints(exclusivity_pairs, clauses)
      graph
    end
    
    # Set boolean constraints (SAT support)
    def set_bool_constraints(
      exclusivity_pairs : Array(Tuple(Int32, Int32)),
      clauses : Array(Array(Int32))
    )
      @exclusivity_pairs = exclusivity_pairs
      @clauses = clauses
      @has_bool_constraints = true
    end

    def size
      @weights.size
    end

    # Get adjacency value (works for both dense and sparse)
    def adjacency_value(i : Int32, j : Int32) : Float64
      if @use_sparse && (sparse = @sparse_adjacency)
        sparse[i, j]
      elsif (dense = @adjacency)
        dense[i][j]
      else
        0.0
      end
    end

    # Get degree of node i
    def degree(i : Int32) : Float64
      if @use_sparse && (sparse = @sparse_adjacency)
        sparse.degree(i)
      elsif (dense = @adjacency)
        dense[i].sum
      else
        0.0
      end
    end

    # Get maximum degree in the graph
    def max_degree : Int32
      if @use_sparse && (sparse = @sparse_adjacency)
        max_deg = 0
        (0...size).each do |i|
          deg = sparse.degree(i).to_i
          max_deg = deg if deg > max_deg
        end
        max_deg
      elsif (dense = @adjacency)
        dense.map { |row| row.sum }.max.to_i
      else
        0
      end
    end

    # Convert to sparse (if currently dense)
    def to_sparse! : Nil
      return if @use_sparse
      
      if (dense = @adjacency)
        @sparse_adjacency = SparseMatrix.from_dense(dense)
        @adjacency = nil
        @use_sparse = true
      end
    end

    # Convert to dense (if currently sparse) - WARNING: memory intensive!
    def to_dense! : Nil
      return unless @use_sparse
      
      if (sparse = @sparse_adjacency)
        @adjacency = sparse.to_dense
        @sparse_adjacency = nil
        @use_sparse = false
      end
    end

    # Get dense adjacency (creates if needed) - WARNING: memory intensive!
    def get_dense_adjacency : Array(Array(Float64))
      if (dense = @adjacency)
        dense
      elsif (sparse = @sparse_adjacency)
        sparse.to_dense
      else
        raise "No adjacency matrix available"
      end
    end

    # Get sparse adjacency (creates if needed)
    def get_sparse_adjacency : SparseMatrix
      if (sparse = @sparse_adjacency)
        sparse
      elsif (dense = @adjacency)
        SparseMatrix.from_dense(dense)
      else
        raise "No adjacency matrix available"
      end
    end

    # Memory usage statistics
    def memory_usage : String
      if @multi_type
        total_memory = @edge_types.sum { |_, matrix| matrix.memory_usage }
        combined_stats = "#{@edge_types.size} edge types, "
        combined_stats += "total memory=#{(total_memory.to_f / (1024 * 1024)).round(2)}MB"
        combined_stats += " (#{@edge_types.map { |t, m| "#{t}:#{m.nnz}" }.join(", ")})"
        "MultiTypeGraph(#{size()}, #{combined_stats})"
      elsif @use_sparse && (sparse = @sparse_adjacency)
        sparse.stats
      elsif (dense = @adjacency)
        mem_mb = (dense.size * dense.size * sizeof(Float64)).to_f / (1024 * 1024)
        "DenseMatrix(#{dense.size}×#{dense.size}, memory=#{mem_mb.round(2)}MB)"
      else
        "Empty graph"
      end
    end

    # Multi-type specific methods - NEW
    def has_type?(type_name : String) : Bool
      @edge_types.has_key?(type_name)
    end

    def get_type_matrix(type_name : String) : SparseMatrix?
      @edge_types[type_name]?
    end

    def get_type_weight(type_name : String) : Float64
      @type_weights[type_name]? || 1.0
    end

    def set_type_weight(type_name : String, weight : Float64) : Nil
      @type_weights[type_name] = weight if @edge_types.has_key?(type_name)
    end

    def type_names : Array(String)
      @edge_types.keys
    end

    def num_types : Int32
      @edge_types.size
    end

    # Get adjacency value for specific edge type - NEW
    def adjacency_value(i : Int32, j : Int32, type_name : String) : Float64
      if (matrix = @edge_types[type_name]?)
        matrix[i, j]
      else
        0.0
      end
    end

    # Get degree for specific edge type - NEW
    def degree(i : Int32, type_name : String) : Float64
      if (matrix = @edge_types[type_name]?)
        matrix.degree(i)
      else
        0.0
      end
    end

    # Get weighted degree across all edge types - NEW
    def weighted_degree(i : Int32) : Float64
      @edge_types.sum do |type_name, matrix|
        weight = @type_weights[type_name]? || 1.0
        weight * matrix.degree(i)
      end
    end

    private def square?(matrix)
      matrix.all? { |row| row.size == matrix.size }
    end

    private def build_edges(matrix)
      edges = Array(Tuple(Int32, Int32, Float64)).new
      matrix.size.times do |i|
        ((i + 1)...matrix.size).each do |j|
          weight = matrix[i][j]
          next if weight == 0.0
          edges << {i.to_i32, j.to_i32, weight}
        end
      end
      edges
    end

    # Helper methods for multi-type constructor - NEW
    private def build_edges_from_types
      all_edges = Array(Tuple(Int32, Int32, Float64)).new

      @edge_types.each do |type_name, matrix|
        weight = @type_weights[type_name]? || 1.0
        matrix.nnz.times do |idx|
          i, j, val = matrix.get_nnz(idx)
          if i < j  # Only add once for undirected graphs
            weighted_val = val * weight
            all_edges << {i, j, weighted_val}
          end
        end
      end

      all_edges
    end

    private def combine_edge_types : SparseMatrix
      unless @multi_type
        return @sparse_adjacency || SparseMatrix.new(size, size)
      end

      n = size
      combined = SparseMatrix.new(n, n)

      @edge_types.each do |type_name, matrix|
        weight = @type_weights[type_name]? || 1.0
        matrix.nnz.times do |idx|
          i, j, val = matrix.get_nnz(idx)
          combined[i, j] += val * weight
          combined[j, i] += val * weight if i != j  # Symmetric
        end
      end

      combined
    end

    private def self.make_symmetric_edges(edges : Array(Tuple(Int32, Int32, Float64))) : Array(Tuple(Int32, Int32, Float64))
      symmetric_edges = Array(Tuple(Int32, Int32, Float64)).new
      edges.each do |i, j, w|
        symmetric_edges << {i, j, w}
        symmetric_edges << {j, i, w} unless i == j
      end
      symmetric_edges
    end
  end
end
