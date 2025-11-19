#
# List Coloring to SAT Translation using Spectral-Multiplicative Framework
# Proper approach: Convert List Coloring to SAT, then use existing SAT solver
#

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
      
      num_colors = next_var_id - 1
      
      # Constraint 1: Each vertex gets at least one color from its list
      num_vertices.times do |v|
        at_least_one_clause = [] of Int32
        color_lists[v]?.try do |allowed_colors|
          allowed_colors.each do |c|
            var_id = variable_map[{v, c}]
            at_least_one_clause << var_id
          end
        end
        
        clauses << at_least_one_clause unless at_least_one_clause.empty?
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
        color_lists[u]?.try do |u_colors|
          color_lists[v]?.try do |v_colors|
            # Use colors that are in both lists (could be all colors if no special restriction)
            common_colors = (u_colors & v_colors).to_a
            common_colors.each do |c|
              if variable_map[{u, c}]? && variable_map[{v, c}]?
                var_u = variable_map[{u, c}]
                var_v = variable_map[{v, c}]
                # NOT (var_u AND var_v) => (NOT var_u OR NOT var_v)
                clauses << [-var_u, -var_v]
              end
            end
          end
        end
      end
      
      {clauses: clauses, num_variables: num_colors, variable_map: variable_map}
    end
    
    # Convert SAT result back to vertex coloring
    def self.extract_coloring_from_sat(sat_result_assignment, variable_map)
      coloring = {} of Int32 => Int32
      
      # Group variables by vertex
      vertex_vars = {} of Int32 => Array({Int32, Int32, Bool})  # {vertex, color, assigned_true}
      
      variable_map.each do |(vertex, color), var_id|
        if var_id <= sat_result_assignment.size
          assigned = sat_result_assignment[var_id - 1]  # SAT solver uses 1-based indexing of variables
          if vertex_vars[vertex]?
            vertex_vars[vertex] << {color, var_id, assigned}
          else
            vertex_vars[vertex] = [{color, var_id, assigned}]
          end
        end
      end
      
      # For each vertex, find which color was assigned true
      vertex_vars.each do |vertex, color_vars|
        color_vars.each do |color, var_id, assigned|
          if assigned
            coloring[vertex] = color
            break  # Assuming only one color per vertex due to constraints
          end
        end
      end
      
      coloring
    end
  end
  
  # List Coloring solver using SAT translation
  class ListColoringViaSAT
    def self.solve(instance : ListColoringInstance, 
                   use_diagnostic : Bool = true,
                   iterations : Int32 = 2000) : ListColoringResult
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
      
      return ListColoringResult.new(false, {} of Int32 => Int32, 
                                   instance.edges.size + instance.num_vertices, 
                                   0.0, (Time.monotonic - start_time).total_seconds) if num_variables == 0

      # Create SAT solver and solve
      sat_solver = SATSolver.new(num_variables, clauses)
      
      # Optionally run diagnostic 
      diagnostic_time = 0.0
      if use_diagnostic
        diagnostic = sat_solver.diagnostic
        diagnostic_time = diagnostic.runtime
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
      
      ListColoringResult.new(
        success, 
        coloring, 
        violations, 
        sat_result.energy,
        solve_time
      )
    end
  end
end

# Example usage
if __FILE__ == $0
  puts "LIST COLORING VIA SAT TRANSLATION"
  puts "=" * 50
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
  
  puts "SAT representation:"
  puts "  - #{clauses.size} clauses"
  puts "  - #{sat_data[:num_variables]} variables"
  puts "  Sample clauses (first 5): #{clauses.first(5)}"
  
  # Solve using SAT approach
  result = MultiplicativeConstraint::ListColoringViaSAT.solve(instance, iterations: 1000)
  
  puts
  puts "Result:"
  puts "  Success: #{result.success}"
  puts "  Violations: #{result.violations}"
  puts "  Solution: #{result.coloring}"
  puts "  Time: #{result.solve_time.round(3)}s"
  puts
  
  if result.success && !result.coloring.empty?
    valid = instance.is_valid_coloring?(result.coloring)
    puts "  Valid (verified): #{valid}"
  else
    puts "  Expected: Path graph should be 2-colorable"
    puts "  This may need more iterations or different approach"
  end
end