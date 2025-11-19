require "../src/multiplicative_constraint"

puts "🏙️ FRACTAL URBAN PLANNER 🏙️"
puts "============================"

# 1. Setup
# 10x10 Grid = 100 Blocks
GRID_SIZE = 10
NUM_BLOCKS = GRID_SIZE * GRID_SIZE

# Zones: 0=Residential, 1=Commercial, 2=Industrial
ZONES = ["Residential", "Commercial", "Industrial"]

# 2. Build Graph (Grid Topology)
weights = Array.new(NUM_BLOCKS, 1.0)
edge_types = Hash(String, MultiplicativeConstraint::SparseMatrix).new

adjacency_edges = [] of Tuple(Int32, Int32, Float64)
zoning_edges = [] of Tuple(Int32, Int32, Float64)

(0...NUM_BLOCKS).each do |i|
  row = i // GRID_SIZE
  col = i % GRID_SIZE
  
  # Connect to neighbors (Up, Down, Left, Right)
  neighbors = [] of Int32
  neighbors << i - GRID_SIZE if row > 0
  neighbors << i + GRID_SIZE if row < GRID_SIZE - 1
  neighbors << i - 1 if col > 0
  neighbors << i + 1 if col < GRID_SIZE - 1
  
  neighbors.each do |n|
    next if i >= n # Avoid duplicates
    
    # Base Adjacency (Traffic Flow)
    adjacency_edges << {i, n, 1.0}
    
    # Zoning Constraint:
    # We want to define "Incompatible" zones implicitly.
    # But the engine partitions into K sets.
    # We can use "Conflict" weights to say "Neighbors should be different" (Graph Coloring)
    # or "Neighbors should be same" (Clustering).
    
    # Let's try a mix:
    # We want Commercial to cluster (High Street) -> Attraction
    # We want Res/Ind to separate -> Repulsion? 
    # Actually, the engine handles "Partitioning".
    # If we want Res and Ind to NOT touch, that's a "Conflict" between specific sets.
    # The current engine supports "Cross-Conflict" (minimize edges between different sets).
    
    # For this test, we'll rely on the "Spectral Aesthetics":
    # We'll use a "Fractal Weighting" where prime-numbered blocks are "Heritage Sites"
    # and must be Residential.
    
    if [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97].includes?(i)
      # Prime Block -> "Heritage" -> Should be Residential (Zone 0)
      # We can't force a specific zone easily without "Anchor Nodes".
      # Instead, we'll give them high weight to make them "Centers of Gravity".
      weights[i] = 5.0 
    end
  end
end

puts "-> Built City Grid:"
puts "   #{adjacency_edges.size} Street Connections"

edge_types["streets"] = MultiplicativeConstraint::SparseMatrix.from_edges(NUM_BLOCKS, NUM_BLOCKS, adjacency_edges)

graph = MultiplicativeConstraint::Graph.new(weights, edge_types)

# 3. Configure Engine
# Partition into 3 Zones
engine = MultiplicativeConstraint::Engine.new(
  graph,
  segments: 3,
  fairness_weight: 10.0, # Balanced zones
  cross_conflict_weight: 0.5, # Allow some mixing, but prefer clustering
  calibrate: true
)

# 4. Solve
puts "\n🧠 Zoning the District..."
engine.calibrate!(samples: 64)

puts "🚀 Optimizing Layout..."
start_time = Time.monotonic
result = engine.solve(iterations: 1000)
duration = Time.monotonic - start_time

# 5. Analysis & Visualization
puts "\n🎉 CITY PLANNED in #{duration.total_milliseconds.round(1)} ms"
puts "========================================"

# Create a map
city_map = Array.new(GRID_SIZE) { Array.new(GRID_SIZE, ".") }

# Assign zones
result.segments.each_with_index do |blocks, zone_idx|
  zone_char = case zone_idx
              when 0 then "R" # Residential
              when 1 then "C" # Commercial
              when 2 then "I" # Industrial
              else "?"
              end
  
  blocks.each do |b|
    r = b // GRID_SIZE
    c = b % GRID_SIZE
    city_map[r][c] = zone_char
  end
end

puts "\n🗺️ ZONING MAP (10x10)"
puts "   R=Res, C=Com, I=Ind"
puts "   -------------------"
city_map.each do |row|
  puts "   | " + row.join(" ") + " |"
end
puts "   -------------------"

# 6. Fractal Skyline Analysis
# We calculate "Skyline Height" based on the Spectral Energy of the block.
# High Energy = Skyscraper, Low Energy = Park.
puts "\n🏙️ FRACTAL SKYLINE (First 10 Blocks)"
(0...10).each do |i|
  # Mocking "Spectral Height" using the weight * zone_id (as a proxy for energy)
  # In a real implementation, we'd pull the eigenvector component.
  zone = 0
  result.segments.each_with_index { |s, z| zone = z if s.includes?(i) }
  
  height = (weights[i] * (zone + 1)).to_i
  bar = "█" * height
  puts "   Block #{i}: #{bar} (#{height} stories)"
end

puts "\n✅ VERDICT: The city breathes."
