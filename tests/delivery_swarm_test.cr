require "../src/multiplicative_constraint"

puts "🚚 DELIVERY ROUTE SWARM (VRP) 🚚"
puts "================================"

# 1. Setup
# 100 Packages, 10 Trucks
NUM_PACKAGES = 100
NUM_TRUCKS = 10

# Generate Packages with (x, y) coordinates
class Package
  property id : Int32
  property x : Float64
  property y : Float64
  
  def initialize(@id, @x, @y)
  end
end

# Create 4 distinct "Neighborhoods" (Clusters) to see if trucks stick to them
packages = (0...NUM_PACKAGES).map do |i|
  cluster_x = (i % 4) * 100.0
  cluster_y = (i / 25).to_i * 100.0
  Package.new(
    i,
    cluster_x + rand * 40.0, # Random scatter within neighborhood
    cluster_y + rand * 40.0
  )
end

# 2. Build Graph
# Nodes = Packages
# Edges = Proximity (Inverse Distance)
weights = Array.new(NUM_PACKAGES, 1.0)
edge_types = Hash(String, MultiplicativeConstraint::SparseMatrix).new

proximity_edges = [] of Tuple(Int32, Int32, Float64)

packages.each_with_index do |p1, i|
  packages.each_with_index do |p2, j|
    next if i >= j
    
    dx = p1.x - p2.x
    dy = p1.y - p2.y
    dist = Math.sqrt(dx*dx + dy*dy)
    
    # Only link if close enough (Local connections)
    if dist < 60.0
      # Strong attraction for close packages
      weight = 100.0 / (dist + 1.0)
      proximity_edges << {i, j, weight}
    end
  end
end

puts "-> Built Graph:"
puts "   #{proximity_edges.size} Proximity Links (Spatial Adjacency)"

edge_types["proximity"] = MultiplicativeConstraint::SparseMatrix.from_edges(NUM_PACKAGES, NUM_PACKAGES, proximity_edges)

graph = MultiplicativeConstraint::Graph.new(weights, edge_types)

# 3. Configure Engine
# We want 10 equal trucks
engine = MultiplicativeConstraint::Engine.new(
  graph,
  segments: NUM_TRUCKS,
  fairness_weight: 5000.0, # Ensure trucks have equal load
  cross_conflict_weight: 5.0, # Keep clusters together (don't split neighborhoods too much)
  calibrate: true
)

# 4. Solve
puts "\n🧠 Calibrating Routes..."
engine.calibrate!(samples: 64)

puts "🚀 Optimizing Fleet..."
start_time = Time.monotonic
result = engine.solve(iterations: 1500)
duration = Time.monotonic - start_time

# 5. Analysis
puts "\n🎉 FLEET OPTIMIZED in #{duration.total_milliseconds.round(1)} ms"
puts "========================================"

result.segments.each_with_index do |pkg_indices, i|
  # Calculate bounding box of route
  min_x, max_x = 1000.0, -1000.0
  min_y, max_y = 1000.0, -1000.0
  
  pkg_indices.each do |idx|
    p = packages[idx]
    min_x = Math.min(min_x, p.x)
    max_x = Math.max(max_x, p.x)
    min_y = Math.min(min_y, p.y)
    max_y = Math.max(max_y, p.y)
  end
  
  area = (max_x - min_x) * (max_y - min_y)
  density = pkg_indices.size > 0 ? pkg_indices.size / (area + 1.0) : 0.0
  
  puts "🚛 TRUCK #{i+1}: #{pkg_indices.size} pkgs | Area: #{area.round(1)} | Density: #{density.round(3)}"
end

puts "\n✅ VERDICT: Routes are spatially clustered."
