#!/usr/bin/env crystal

# Simplest test: Just convert a basic list coloring problem to SAT and solve it
puts "SIMPLEST LIST COLORING TO SAT TEST"
puts "=" * 40

# Test data: Triangle graph that needs 3 colors, but with 3-color lists so it should be solvable
edges = [{0, 1}, {1, 2}, {0, 2}]  # Triangle
color_lists = {
  0 => Set{1, 2, 3},
  1 => Set{1, 2, 3}, 
  2 => Set{1, 2, 3}
}
num_vertices = 3

puts "Graph: Triangle (0-1-2-0) with 3-color lists per vertex"
puts "This should be solvable with 3 colors"

# Create SAT variables: x_{v,c} means "vertex v gets color c"
# Variables will be numbered 1 to n where n is total possible assignments
variable_map = {} of Tuple(Int32, Int32) => Int32
var_counter = 1

num_vertices.times do |v|
  color_lists[v]?.try do |colors|
    colors.each do |c|
      variable_map[{v, c}] = var_counter
      var_counter += 1
    end
  end
end

num_variables = var_counter - 1
clauses = [] of Array(Int32)

puts "Created #{num_variables} SAT variables"

# Clause 1: Each vertex gets at least one color
num_vertices.times do |v|
  clause = [] of Int32
  color_lists[v]?.try do |colors|
    colors.each do |c|
      clause << variable_map[{v, c}]
    end
  end
  clauses << clause unless clause.empty?
end

# Clause 2: Each vertex gets at most one color (pairwise exclusion)
num_vertices.times do |v|
  colors = color_lists[v]? || Set(Int32).new
  colors.to_a.each_with_index do |c1, i|
    colors.to_a.each_with_index do |c2, j|
      next if i >= j  # Avoid duplicates
      var1 = variable_map[{v, c1}]
      var2 = variable_map[{v, c2}]
      clauses << [-var1, -var2]  # NOT (var1 AND var2) = (NOT var1 OR NOT var2)
    end
  end
end

# Clause 3: Adjacent vertices get different colors
edges.each do |u, v|
  u_colors = color_lists[u]? || Set(Int32).new
  v_colors = color_lists[v]? || Set(Int32).new
  common_colors = u_colors & v_colors
  
  common_colors.each do |c|
    var_u = variable_map[{u, c}]
    var_v = variable_map[{v, c}]
    clauses << [-var_u, -var_v]  # NOT (u gets c AND v gets c) = (NOT u_gets_c OR NOT v_gets_c)
  end
end

puts "Created #{clauses.size} SAT clauses"

# Now use the actual SAT solver
require "../src/multiplicative_constraint"

puts "\nSolving with Spectral-Multiplicative SAT solver..."
solver = MultiplicativeConstraint::SATSolver.new(num_variables, clauses)

# Solve
result = solver.solve(iterations: 1000)

puts "Satisfiable: #{result.satisfiable}"
puts "Satisfied clauses: #{result.satisfied_clauses}/#{result.total_clauses}"
if result.satisfiable
  puts "Assignment: #{result.assignment}"
  
  # Convert back to coloring
  coloring = {} of Int32 => Int32
  variable_map.each do |(vertex, color), var_id|
    if var_id <= result.assignment.size
      assigned = result.assignment[var_id - 1]  # 0-indexed array for 1-indexed vars
      if assigned
        coloring[vertex] = color
      end
    end
  end
  
  puts "Extracted coloring: #{coloring}"
  
  # Verify it's valid for triangle with 3 different colors
  if coloring.size == 3 && coloring[0] != coloring[1] && coloring[1] != coloring[2] && coloring[0] != coloring[2]
    puts "SUCCESS: Valid 3-coloring found for triangle!"
  else
    puts "Partial or invalid coloring found"
  end
else
  puts "No satisfying assignment found"
end