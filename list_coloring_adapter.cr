# List Coloring Problem using Spectral-Multiplicative Framework
# Mapping list coloring to multiplicative constraint optimization

require "set"

# Extension to convert list coloring problems to the spectral-multiplicative framework
module ListColoringAdapter
  extend self

  # Convert a list coloring instance to the framework's format
  def convert_to_framework(num_vertices, edges, color_lists)
    # Create a vertex for each (v, c) pair where c is in L(v) 
    # This creates an assignment graph where segments represent colors
    assignment_vertices = [] of Array(Int32)  # [vertex_id, color_id]
    vertex_map = Hash(Tuple(Int32, Int32), Int32).new  # {(vertex, color) -> assignment_id}
    
    assignment_id = 0
    num_vertices.times do |v|
      color_lists[v].each do |c|
        assignment_vertices << [v, c]
        vertex_map[{v, c}] = assignment_id
        assignment_id += 1
      end
    end
    
    num_assignment_vars = assignment_vertices.size
    
    # Create weights for each assignment variable (uniform for now)
    weights = Array.new(num_assignment_vars, 1.0)
    
    # Create adjacency matrix with different constraint types
    # 1. One-color constraints: each original vertex gets exactly one color
    # 2. Adjacency constraints: adjacent vertices get different colors  
    # 3. List constraints: only allowed colors can be used (already encoded by vertex creation)
    
    one_color_edges = [] of Tuple(Int32, Int32, Float64)
    adjacency_edges = [] of Tuple(Int32, Int32, Float64)
    
    # One-color constraints: for each vertex v, ensure only one of its color assignments is true
    num_vertices.times do |v|
      allowed_colors = color_lists[v]
      if allowed_colors.size > 1
        # Create negative edges between different color assignments for same vertex
        allowed_colors.to_a.each_with_index do |c1, i|
          allowed_colors.to_a.each_with_index do |c2, j|
            next if i >= j  # Avoid duplicates
            pos1 = vertex_map[{v, c1}]
            pos2 = vertex_map[{v, c2}]
            # These should NOT both be in the same segment (color assignment)
            one_color_edges << {pos1, pos2, -10.0}  # Strong penalty for same color
          end
        end
      end
    end
    
    # Adjacency constraints: adjacent vertices should not have same colors
    edges.each do |u, v|
      # For each color c, ensure (u,c) and (v,c) are not both assigned
      color_lists[u].intersection(color_lists[v]).each do |c|
        if vertex_map[{u, c}]? && vertex_map[{v, c}]?
          pos_u_c = vertex_map[{u, c}]
          pos_v_c = vertex_map[{v, c}]
          # These should NOT both be in the same color segment
          adjacency_edges << {pos_u_c, pos_v_c, -15.0}  # Strong penalty for same color
        end
      end
    end
    
    # Create multi-type graph structure
    edge_types = Hash(String, Array(Tuple(Int32, Int32, Float64))).new
    edge_types["one_color"] = one_color_edges
    edge_types["adjacency"] = adjacency_edges
    
    {
      assignment_vertices: assignment_vertices,
      vertex_map: vertex_map,
      weights: weights,
      edge_types: edge_types,
      original_vertices: num_vertices,
      color_lists: color_lists
    }
  end
  
  # Extract list coloring solution from framework result
  def extract_solution(result, conversion_data)
    assignment_vertices = conversion_data[:assignment_vertices]
    vertex_map = conversion_data[:vertex_map] 
    original_vertices = conversion_data[:original_vertices]
    color_lists = conversion_data[:color_lists]
    
    # Map discrete solution to assignment variable indices
    solution_map = Hash(Int32, Int32).new  # assignment_var_id -> segment_id
    result.discrete_solution.each_with_index do |segment_id, var_id|
      solution_map[var_id] = segment_id
    end
    
    # Group assignment variables by their color/segment assignment
    vertex_colors = Hash(Int32, Int32).new  # vertex_id -> color_id
    
    # For each original vertex, find which color was assigned
    original_vertices.times do |v|
      assigned_color = nil
      color_lists[v].each do |c|
        assignment_id = vertex_map[{v, c}]
        if solution_map[assignment_id]? && solution_map[assignment_id] == 0  # Assuming segment 0 means "assigned"
          assigned_color = c
          break
        end
      end
      
      # Alternative approach: find which assignment variable for this vertex is in the "selected" segment
      # In the framework, segments represent different constraints, not colors directly
      # So we need to map back differently
      
      # Let's use a different approach: each color gets its own "segment"
      vertex_color_assignments = [] of {Int32, Int32, Int32}  # {vertex_id, color_id, assignment_var_id}
      
      color_lists[v].each do |c|
        assignment_id = vertex_map[{v, c}]
        vertex_color_assignments << {v, c, assignment_id}
      end
      
      # Find the assignment with the most "active" segment (this is approximate)
      best_assignment = vertex_color_assignments.min_by { |v, c, id| 
        result.discrete_solution[id] || 0
      }
      
      vertex_colors[v] = best_assignment[1] if best_assignment
    end
    
    vertex_colors
  end
end

# Example usage
if __FILE__ == $0
  puts "List Coloring with Spectral-Multiplicative Framework"
  puts "=" * 50
  
  # Example: Path graph with 4 nodes that should be 2-colorable
  num_vertices = 4
  edges = [
    {0, 1},  # 0-1 
    {1, 2},  # 1-2
    {2, 3}   # 2-3
  ]
  
  # Define list constraints: each vertex can use specific colors
  color_lists = {
    0 => Set{1, 2},  # Vertex 0: can be color 1 or 2
    1 => Set{1, 2},  # Vertex 1: can be color 1 or 2  
    2 => Set{1, 2},  # Vertex 2: can be color 1 or 2
    3 => Set{1, 2}   # Vertex 3: can be color 1 or 2
  }
  
  puts "Graph: Path with #{num_vertices} vertices"
  puts "Edges: #{edges}"
  puts "Color lists: #{color_lists}"
  
  # Convert to framework format
  conversion_data = ListColoringAdapter.convert_to_framework(num_vertices, edges, color_lists)
  
  puts "\nConverted to framework:"
  puts "- #{conversion_data[:weights].size} assignment variables"
  puts "- #{conversion_data[:edge_types]["one_color"].size} one-color constraints"
  puts "- #{conversion_data[:edge_types]["adjacency"].size} adjacency constraints"
  
  # In practice, we would use the Crystal framework here
  # Since we're in Ruby-like pseudocode, we'll show the structure
  
  puts "\nThe conversion creates a constraint satisfaction problem that can be solved by:"
  puts "1. The Spectral-Multiplicative Framework's multi-type optimization"
  puts "2. Using neural weight calibration to tune constraint importance"
  puts "3. Maintaining ρ ≥ 0.99 correlation for mathematical validity"
  puts "4. Extracting the solution back to original vertex-color assignments"
  
  # This would be the actual integration with the Crystal framework:
  # 1. Create MultiplicativeConstraint::Graph with the multi-type edges
  # 2. Use MultiplicativeConstraint::Engine with appropriate segment count  
  # 3. Apply neural calibration for optimal constraint weights
  # 4. Run optimization with correlation guard
  # 5. Map result back to vertex color assignments using extract_solution
  
  puts "\nExpected result for path graph: Valid 2-coloring (e.g., 1-2-1-2 or 2-1-2-1)"
end