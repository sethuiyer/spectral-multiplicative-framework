#!/usr/bin/env crystal

# Test a simple case that must work: single edge with 2-color lists
puts "SIMPLE CASE TEST: Single Edge Graph"
puts "=" * 40

edges = [{0, 1}]  # Single edge
color_lists = {
  0 => Set{1, 2},  # Vertex 0: can be color 1 or 2
  1 => Set{1, 2}   # Vertex 1: can be color 1 or 2
}
num_vertices = 2

puts "Graph: Single edge 0-1, both vertices can be colored with colors 1 or 2"
puts "This should have solutions: (0 gets 1, 1 gets 2) or (0 gets 2, 1 gets 1)"

# Manual SAT encoding for this simple case:
# Variable meaning: x1 = vertex 0 gets color 1, x2 = vertex 0 gets color 2
#                   x3 = vertex 1 gets color 1, x4 = vertex 1 gets color 2

variable_map = {
  {0, 1} => 1,  # vertex 0 gets color 1
  {0, 2} => 2,  # vertex 0 gets color 2
  {1, 1} => 3,  # vertex 1 gets color 1
  {1, 2} => 4   # vertex 1 gets color 2
}

clauses = [] of Array(Int32)

# Each vertex gets at least one color:
# Vertex 0: (x1 OR x2)
clauses << [1, 2]
# Vertex 1: (x3 OR x4) 
clauses << [3, 4]

# Each vertex gets at most one color:
# Vertex 0: (NOT x1 OR NOT x2) - can't have both colors
clauses << [-1, -2]
# Vertex 1: (NOT x3 OR NOT x4) - can't have both colors  
clauses << [-3, -4]

# Adjacent vertices get different colors:
# Edge (0,1): Can't both get color 1: (NOT x1 OR NOT x3)
clauses << [-1, -3]
# Edge (0,1): Can't both get color 2: (NOT x2 OR NOT x4)
clauses << [-2, -4]

puts "Manually encoded SAT problem:"
puts "Variables: 4 (x1=0→1, x2=0→2, x3=1→1, x4=1→2)"
puts "Clauses: #{clauses.size}"
clauses.each_with_index do |clause, i|
  puts "  #{i+1}: #{clause}"
end

require "../src/multiplicative_constraint"

puts "\nSolving with Spectral-Multiplicative SAT solver..."
solver = MultiplicativeConstraint::SATSolver.new(4, clauses)

# Solve
result = solver.solve(iterations: 1000)

puts "Satisfiable: #{result.satisfiable}"
puts "Satisfied clauses: #{result.satisfied_clauses}/#{result.total_clauses}"

if result.satisfiable
  puts "Assignment: #{result.assignment}"
  
  # Convert back to coloring
  coloring = {} of Int32 => Int32
  variable_map.each do |(vertex, color), var_id|
    assigned = result.assignment[var_id - 1]  # 0-indexed for 1-indexed vars
    if assigned
      coloring[vertex] = color
    end
  end
  
  puts "Extracted coloring: #{coloring}"
  
  # Verify it's valid
  valid = true
  if coloring[0] == coloring[1]
    puts "Invalid: adjacent vertices have same color"
    valid = false
  end
  
  if !color_lists[0]?.try(&.includes?(coloring[0])) ||
     !color_lists[1]?.try(&.includes?(coloring[1])) 
    puts "Invalid: vertex assigned color not in its list"
    valid = false
  end
  
  puts "Solution is #{valid ? "VALID" : "INVALID"}!"
else
  puts "No satisfying assignment found - this is unexpected for a simple 2-colorable graph!"
end