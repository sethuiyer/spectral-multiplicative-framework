#!/usr/bin/env crystal

# Proper List Coloring via SAT Translation using Spectral-Multiplicative Framework
require "../src/multiplicative_constraint"

module MultiplicativeConstraint
  # Utility to convert List Coloring to SAT format
  class ListColoringToSAT
    # Convert a list coloring instance to SAT clauses
    def self.convert_to_sat(num_vertices, edges, color_lists)
      clauses = [] of Array(Int32)
      variable_map = {} of Tuple(Int32, Int32) => Int32  # (vertex, color) -> variable_id
      next_var_id = 1
      
      # Create variable for each (vertex, allowed_color) pair
      num_vertices.times do |v|
        color_lists[v]?.try do |allowed_colors|
          allowed_colors.each do |c|
            variable_map[{v, c}] = next_var_id
            next_var_id += 1
          end
        end
      end
      
      num_variables = next_var_id - 1
      
      # Constraint 1: Each vertex gets at least one color from its list
      num_vertices.times do |v|
        allowed_colors = color_lists[v]? || Set(Int32).new
        if allowed_colors.size > 0
          at_least_one_clause = allowed_colors.map do |c|
            variable_map[{v, c}]
          end
          clauses << at_least_one_clause unless at_least_one_clause.empty?
        end
      end
      
      # Constraint 2: Each vertex gets at most one color (pairwise negation)
      num_vertices.times do |v|
        allowed_colors = color_lists[v]? || Set(Int32).new
        allowed_colors.to_a.each_with_index do |c1, i|
          allowed_colors.to_a.each_with_index do |c2, j|
            next if i >= j  # Avoid duplicates
            var1 = variable_map[{v, c1}]
            var2 = variable_map[{v, c2}]
            # NOT (var1 AND var2) => (NOT var1 OR NOT var2)
            clauses << [-var1, -var2]
          end
        end
      end
      
      # Constraint 3: Adjacent vertices get different colors
      edges.each do |u, v|
        u_colors = color_lists[u]? || Set(Int32).new
        v_colors = color_lists[v]? || Set(Int32).new
        common_colors = u_colors & v_colors  # intersection in Crystal
        
        common_colors.each do |c|
          u_var = variable_map[{u, c}]
          v_var = variable_map[{v, c}]
          # NOT (u gets c AND v gets c) => (NOT u_gets_c OR NOT v_gets_c)
          clauses << [-u_var, -v_var] if u_var && v_var
        end
      end
      
      {clauses: clauses, num_variables: num_variables, variable_map: variable_map}
    end
    
    # Convert SAT result back to vertex coloring
    def self.extract_coloring_from_sat(sat_result_assignment, variable_map)
      coloring = {} of Int32 => Int32
      
      # Map from variable id to (vertex, color) pairs
      var_to_vertex_color = {} of Int32 => {Int32, Int32}
      variable_map.each do |(vertex, color), var_id|
        var_to_vertex_color[var_id] = {vertex, color}
      end
      
      # Go through assignment and find which variables are true
      # The assignment array is 0-indexed, but variable IDs are 1-indexed based on creation
      # Actually, let's be more careful with the indexing
      sat_result_assignment.each_with_index do |is_true, idx|
        var_id = idx + 1  # Assignment[0] corresponds to variable 1
        if is_true && var_to_vertex_color[var_id]?
          vertex, color = var_to_vertex_color[var_id]
          coloring[vertex] = color
        end
      end
      
      coloring
    end
  end
  
  # List Coloring instance class (copied from earlier for completeness)  
  class ListColoringInstance
    getter num_vertices : Int32
    getter edges : Array(Tuple(Int32, Int32))
    getter color_lists : Hash(Int32, Set(Int32))
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
  
  # List Coloring solver using SAT translation
  class ListColoringViaSAT
    def self.solve(instance : ListColoringInstance, 
                   use_diagnostic : Bool = true,
                   iterations : Int32 = 1000) : ListColoringResult
      start_time = Time.monotonic
      
      # Convert to SAT
      sat_data = ListColoringToSAT.convert_to_sat(
        instance.num_vertices, 
        instance.edges, 
        instance.color_lists
      )
      
      clauses = sat_data[:clauses]
      num_variables = sat_data[:num_variables]
      variable_map = sat_data[:variable_map]
      
      if num_variables == 0
        solve_time = (Time.monotonic - start_time).total_seconds
        return ListColoringResult.new(false, {} of Int32 => Int32, 
                                     instance.edges.size + instance.num_vertices, 
                                     0.0, solve_time)
      end

      # Create SAT solver and solve
      begin
        sat_solver = SATSolver.new(num_variables, clauses)
        
        # Optionally run diagnostic 
        if use_diagnostic
          diagnostic = sat_solver.diagnostic
          # If diagnostic predicts unsolvable with high confidence, return early
          if !diagnostic.predicted_solvable && diagnostic.confidence > 0.8
            solve_time = (Time.monotonic - start_time).total_seconds
            return ListColoringResult.new(false, {} of Int32 => Int32, 
                                         instance.edges.size + instance.num_vertices, 
                                         0.0, solve_time)
          end
        end
        
        # Solve the SAT problem
        sat_result = sat_solver.solve(
          use_diagnostic: false,  # Diagnostic already done
          iterations: iterations
        )
        
        solve_time = (Time.monotonic - start_time).total_seconds
        
        # Extract coloring from SAT result
        coloring = {} of Int32 => Int32
        if sat_result.satisfiable
          coloring = ListColoringToSAT.extract_coloring_from_sat(
            sat_result.assignment, 
            variable_map
          )
        end
        
        # Count violations
        violations = instance.count_violations(coloring)
        success = sat_result.satisfiable && violations == 0
        
        return ListColoringResult.new(
          success, 
          coloring, 
          violations, 
          sat_result.energy,
          solve_time
        )
      rescue ex
        solve_time = (Time.monotonic - start_time).total_seconds
        return ListColoringResult.new(false, {} of Int32 => Int32, 
                                    instance.edges.size + instance.num_vertices, 
                                    0.0, solve_time)
      end
    end
  end
end

# Example usage
if __FILE__ == $0
  puts "LIST COLORING VIA SAT TRANSLATION - REIMPLEMENTED"
  puts "=" * 60
  puts "Using the framework's SAT solver for List Coloring via reduction"
  puts

  # Example: Path graph with 4 nodes - should be 2-colorable
  puts "EXAMPLE: Path Graph (4 nodes) - 2-Colorable via SAT"
  puts "-" * 50
  
  edges = [{0, 1}, {1, 2}, {2, 3}]
  color_lists = {
    0 => Set{1, 2},
    1 => Set{1, 2}, 
    2 => Set{1, 2},
    3 => Set{1, 2}
  }
  instance = MultiplicativeConstraint::ListColoringInstance.new(4, edges, color_lists)

  puts "Graph: 0-1-2-3 (Path)"
  puts "Lists: #{color_lists}"
  
  # Convert to SAT to see the structure
  sat_data = MultiplicativeConstraint::ListColoringToSAT.convert_to_sat(4, edges, color_lists)
  clauses = sat_data[:clauses]
  num_vars = sat_data[:num_variables]
  
  puts "SAT representation:"
  puts "  - #{clauses.size} clauses"
  puts "  - #{num_vars} variables"
  puts "  First few clauses: #{clauses.first(5)}" unless clauses.empty?
  
  # Solve using SAT approach
  result = MultiplicativeConstraint::ListColoringViaSAT.solve(instance, iterations: 1000)
  
  puts
  puts "Result:"
  puts "  Success: #{result.success}"
  puts "  Violations: #{result.violations}"
  puts "  Solution: #{result.coloring}"
  puts "  Time: #{result.solve_time.round(3)}s"
  
  if result.success && !result.coloring.empty?
    valid = instance.is_valid_coloring?(result.coloring)
    puts "  Valid (verified): #{valid}"
    if valid
      puts "  SUCCESS: Found proper list coloring!"
    end
  else
    puts "  Status: Path graph should be 2-colorable, solution may need more optimization"
  end
  
  puts
  puts "KEY POINTS:"
  puts "- Proper List Coloring to SAT conversion implemented"
  puts "- Uses existing SAT solver with Casimir diagnostics"
  puts "- Maintains all list constraints and adjacency constraints"
  puts "- Each vertex variable set to TRUE corresponds to assigned color"
end