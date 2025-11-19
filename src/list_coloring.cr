#
# List Coloring Problem Interface for Spectral-Multiplicative Framework
# Maps the List Coloring NP-hard problem to the framework's optimization approach
#

require "./multiplicative_constraint"

module MultiplicativeConstraint
  # List coloring instance
  class ListColoringInstance
    getter num_vertices : Int32
    getter edges : Array(Tuple(Int32, Int32))
    getter color_lists : Hash(Int32, Set(Int32))  # vertex -> allowed colors
    getter all_colors : Set(Int32)

    def initialize(@num_vertices, @edges, @color_lists)
      # Collect all colors used across all lists
      @all_colors = Set(Int32).new
      @color_lists.each_value { |colors| @all_colors.concat(colors) }
    end

    # Validate a coloring solution
    def is_valid_coloring?(coloring : Hash(Int32, Int32)) : Bool
      # Check each vertex has an allowed color
      @color_lists.each do |vertex, allowed_colors|
        color = coloring[vertex]?
        return false if color.nil?
        return false unless allowed_colors.includes?(color)
      end

      # Check adjacent vertices have different colors
      @edges.each do |u, v|
        return false if coloring[u] == coloring[v]
      end

      true
    end

    # Count violations in a potential solution
    def count_violations(coloring : Hash(Int32, Int32)) : Int32
      violations = 0

      # Count list constraint violations
      @color_lists.each do |vertex, allowed_colors|
        color = coloring[vertex]?
        if color.nil? || !allowed_colors.includes?(color)
          violations += 1
        end
      end

      # Count adjacency violations
      @edges.each do |u, v|
        if coloring[u]? && coloring[v]? && coloring[u] == coloring[v]
          violations += 1
        end
      end

      violations
    end
  end

  # List coloring result
  struct ListColoringResult
    getter success : Bool
    getter coloring : Hash(Int32, Int32)
    getter violations : Int32
    getter original_energy : Float64
    getter solve_time : Float64

    def initialize(@success, @coloring, @violations, @original_energy, @solve_time)
    end
  end

  # List Coloring Solver using Spectral-Multiplicative Framework
  class ListColoringSolver
    # Map the list coloring problem to the framework's multi-type constraint system
    def self.solve_with_framework(instance : ListColoringInstance, 
                                 iterations : Int32 = 2000,
                                 segments : Int32? = nil) : ListColoringResult
      start_time = Time.monotonic

      # Create a variable for each (vertex, color) assignment where color is allowed
      assignment_vars = Array(Tuple(Int32, Int32)).new  # [(vertex, color), ...]
      assignment_to_index = Hash(Tuple(Int32, Int32), Int32).new  # {(v,c) -> index}
      
      idx = 0
      instance.num_vertices.times do |v|
        instance.color_lists[v]?.try do |allowed_colors|
          allowed_colors.each do |c|
            assignment_vars << {v, c}
            assignment_to_index[{v, c}] = idx
            idx += 1
          end
        end
      end

      num_assignments = assignment_vars.size
      return ListColoringResult.new(false, Hash(Int32, Int32).new, 
                                   instance.edges.size + instance.num_vertices, 
                                   0.0, 0.0) if num_assignments == 0

      # Create node weights (uniform for now)
      weights = Array.new(num_assignments, 1.0)

      # Create multi-type constraints
      one_color_edges = [] of Tuple(Int32, Int32, Float64)  # For each vertex, one color only
      adjacency_edges = [] of Tuple(Int32, Int32, Float64)  # Adjacent vertices, same color

      # One-color constraints: for each vertex v, only one of (v,c) can be "active"
      instance.num_vertices.times do |v|
        allowed_colors = instance.color_lists[v]? || Set(Int32).new
        color_indices = allowed_colors.map { |c| assignment_to_index[{v, c}]? || -1 }.reject { |i| i < 0 }
        
        # Create negative edges between different color assignments for same vertex
        color_indices.each_with_index do |idx1, i|
          color_indices.each_with_index do |idx2, j|
            next if i >= j  # Avoid duplicates
            one_color_edges << {idx1, idx2, -50.0}  # Strong penalty
          end
        end
      end

      # Adjacency constraints: if (u,v) is an edge, then for any color c,
      # (u,c) and (v,c) cannot both be "active"
      instance.edges.each do |u, v|
        instance.all_colors.each do |c|
          if assignment_to_index[{u, c}]? && assignment_to_index[{v, c}]?
            idx_u = assignment_to_index[{u, c}]
            idx_v = assignment_to_index[{v, c}]
            adjacency_edges << {idx_u, idx_v, -50.0}  # Prevent same color on adjacent vertices
          end
        end
      end

      # Create multi-type graph
      edge_types = Hash(String, SparseMatrix).new
      edge_types["one_color"] = SparseMatrix.from_edges(num_assignments, num_assignments, one_color_edges)
      edge_types["adjacency"] = SparseMatrix.from_edges(num_assignments, num_assignments, adjacency_edges)

      graph = Graph.new(weights, edge_types)

      # Use optimal number of segments (colors) if not specified
      num_segments = segments || [instance.all_colors.size, 5].min  # Limit segments for efficiency

      # Create engine with correlation guard and calibration
      engine = Engine.new(
        graph,
        num_segments,
        calibrate: true,
        calibration_samples: 128,
        enable_corr_guard: true,
        corr_min: 0.98,
        penalty_weight: 5.0,
        fairness_weight: 1.0
      )

      # Solve the optimization
      result = engine.solve(iterations: iterations, step: 0.3, seed: 42)

      # Extract the coloring from the optimization result
      coloring = extract_coloring_from_result(result, assignment_vars, instance)

      # Validate the result
      violations = instance.count_violations(coloring)
      success = violations == 0

      solve_time = (Time.monotonic - start_time).total_seconds

      ListColoringResult.new(success, coloring, violations, result.energy, solve_time)
    end

    # Extract vertex coloring from partition result
    private def self.extract_coloring_from_result(partition_result, assignment_vars, instance)
      # Each assignment variable (v,c) is mapped to a segment
      # We need to determine which assignment is "active" for each vertex
      
      coloring = Hash(Int32, Int32).new

      # Group assignment variables by vertex
      vertex_assignments = Hash(Int32, Array(Tuple(Int32, Int32, Int32))).new # vertex -> [(color, var_idx, segment_id), ...]
      
      assignment_vars.each_with_index do |(vertex, color), var_idx|
        segment_id = partition_result.discrete_solution[var_idx] || 0
        
        if vertex_assignments[vertex]?
          vertex_assignments[vertex] << {color, var_idx, segment_id}
        else
          vertex_assignments[vertex] = [{color, var_idx, segment_id}]
        end
      end

      # For each vertex, choose the color assignment with the lowest segment ID
      # (or use other heuristics like alpha values)
      instance.num_vertices.times do |v|
        assignments = vertex_assignments[v]? || [] of Tuple(Int32, Int32, Int32)
        next if assignments.empty?

        # Choose assignment with the most "preferred" segment (lowest number)
        best_assignment = assignments.min_by { |_, _, seg_id| seg_id }
        if best_assignment
          coloring[v] = best_assignment[0]
        end
      end

      coloring
    end
  end
end

