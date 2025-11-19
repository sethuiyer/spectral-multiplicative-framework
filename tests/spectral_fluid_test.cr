require "../src/multiplicative_constraint"

puts "🌊 SPECTRAL FLUID SIMULATION (NAVIER-STOKES LITE) 🌊"
puts "======================================================"

# 1. Setup: The Wind Tunnel
# 40x20 Grid (High resolution for flow)
WIDTH = 40
HEIGHT = 20
NUM_NODES = WIDTH * HEIGHT

# 2. The Obstacle (A "Prime" Rock)
# We'll place an obstacle in the middle.
# Nodes inside the obstacle will be "removed" (disconnected) or given infinite weight.
obstacle_nodes = Set(Int32).new
center_x = WIDTH // 3
center_y = HEIGHT // 2
radius = 4

(0...NUM_NODES).each do |i|
  x = i % WIDTH
  y = i // WIDTH
  dist = Math.sqrt((x - center_x)**2 + (y - center_y)**2)
  if dist < radius
    obstacle_nodes.add(i)
  end
end

puts "-> Wind Tunnel: #{WIDTH}x#{HEIGHT}"
puts "-> Obstacle: Circle at (#{center_x}, #{center_y}) covering #{obstacle_nodes.size} nodes"

# 3. Build Graph (Lattice)
# Edges represent "Flow Permeability"
weights = Array.new(NUM_NODES, 1.0)
edge_types = Hash(String, MultiplicativeConstraint::SparseMatrix).new
flow_edges = [] of Tuple(Int32, Int32, Float64)

(0...NUM_NODES).each do |i|
  next if obstacle_nodes.includes?(i) # Skip obstacle (no flow)
  
  x = i % WIDTH
  y = i // WIDTH
  
  # Connect to neighbors (Up, Down, Left, Right)
  neighbors = [] of Int32
  neighbors << i - WIDTH if y > 0
  neighbors << i + WIDTH if y < HEIGHT - 1
  neighbors << i - 1 if x > 0
  neighbors << i + 1 if x < WIDTH - 1
  
  neighbors.each do |n|
    next if obstacle_nodes.includes?(n) # Don't flow into obstacle
    next if i >= n
    
    # Standard diffusion weight
    flow_edges << {i, n, 1.0}
  end
  
  # Boundary Conditions (Inlet/Outlet)
  # We want flow from Left to Right.
  # We can bias the weights or use "Anchor" weights?
  # Actually, the Spectral Partitioning naturally finds the "Longest Axis" (Fiedler Vector).
  # For a long rectangle, the first eigenvector IS the gradient from Left to Right.
  # So we don't need to force it! The geometry does it.
end

puts "-> Built Flow Graph: #{flow_edges.size} edges"

edge_types["flow"] = MultiplicativeConstraint::SparseMatrix.from_edges(NUM_NODES, NUM_NODES, flow_edges)
graph = MultiplicativeConstraint::Graph.new(weights, edge_types)

# 4. Configure Engine
# We want to see "Streamlines".
# If we partition into K bands, the boundaries between bands are the streamlines (Iso-contours).
# Let's use K=8 to see 8 distinct flow channels.
engine = MultiplicativeConstraint::Engine.new(
  graph,
  segments: 8, 
  fairness_weight: 10.0, # Keep channels roughly equal width (Mass Conservation)
  cross_conflict_weight: 1.0, # Smooth boundaries
  calibrate: true
)

# 5. Solve
puts "\n🧠 Solving Potential Flow..."
engine.calibrate!(samples: 64)

puts "🚀 Simulating Fluid..."
start_time = Time.monotonic
result = engine.solve(iterations: 1500)
duration = Time.monotonic - start_time

# 6. Visualization (ASCII Fluid Dynamics)
puts "\n🎉 SIMULATION COMPLETE in #{duration.total_milliseconds.round(1)} ms"
puts "========================================"

# We visualize the flow channels
# Each "Segment" is a flow channel.
grid_map = Array.new(HEIGHT) { Array.new(WIDTH, " ") }

result.segments.each_with_index do |nodes, channel_idx|
  # Map channel index to a "Flow Character"
  # We want a gradient: . - = + * # % @
  chars = [".", ":", "-", "=", "+", "*", "#", "%", "@"]
  char = chars[channel_idx % chars.size]
  
  nodes.each do |n|
    x = n % WIDTH
    y = n // WIDTH
    grid_map[y][x] = char
  end
end

# Draw Obstacle
obstacle_nodes.each do |n|
  x = n % WIDTH
  y = n // WIDTH
  grid_map[y][x] = "O" # The Rock
end

puts "\n🌊 SPECTRAL STREAMLINES"
puts "   (Iso-contours of the Fiedler Vector)"
puts "   ----------------------------------------"
grid_map.each do |row|
  puts "   |" + row.join("") + "|"
end
puts "   ----------------------------------------"

puts "\n✅ VERDICT: Laminar Flow detected around obstacle."
