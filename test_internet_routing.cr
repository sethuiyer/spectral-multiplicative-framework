#!/usr/bin/env crystal
# Real-World Test: Neural Network on Internet Routing
#
# Testing whether neural adaptation can discover the essential routing factors
# in a complex internet backbone network with multiple constraints

require "./src/multiplicative_constraint"

puts "="*80
puts "NEURAL NETWORK ON INTERNET ROUTING"
puts "="*80
puts "Testing neural adaptation on real network routing optimization"
puts "Internet backbone with bandwidth, latency, and reliability constraints"
puts "="*80
puts

# Internet routing is fundamentally about finding optimal paths
# Core dimensions: Bandwidth capacity + Latency constraints
# Everything else (cost, reliability, load balancing) are secondary

# Create a realistic internet backbone topology
class InternetBackboneBuilder
  # Major internet exchange points and data centers
  NODES = [
    "Ashburn-VA",      # Major US East coast hub
    "San-Jose-CA",     # Major US West coast hub
    "Chicago-IL",      # Central US hub
    "Dallas-TX",       # Southern US hub
    "Toronto-ON",      # Canadian hub
    "Sao-Paulo-BR",    # South American hub
    "London-UK",       # European hub
    "Frankfurt-DE",    # German hub
    "Amsterdam-NL",    # Dutch hub
    "Paris-FR",        # French hub
    "Mumbai-IN",       # Asian hub
    "Singapore-SG",    # Southeast Asian hub
    "Tokyo-JP",        # Japanese hub
    "Sydney-AU",       # Australian hub
    "Johannesburg-ZA"  # African hub
  ]

  # Realistic backbone connections with properties
  BACKBONE_LINKS = [
    # Trans-Atlantic links
    ["Ashburn-VA", "London-UK", 10000, 45, 99.9],    # 10 Gbps, 45ms, 99.9% uptime
    ["Ashburn-VA", "Paris-FR", 8000, 55, 99.8],
    ["Toronto-ON", "London-UK", 6000, 42, 99.9],
    ["Toronto-ON", "Amsterdam-NL", 7000, 48, 99.8],

    # Trans-Pacific links
    ["San-Jose-CA", "Tokyo-JP", 12000, 85, 99.7],
    ["San-Jose-CA", "Singapore-SG", 10000, 120, 99.6],
    ["San-Jose-CA", "Sydney-AU", 8000, 150, 99.5],

    # European backbone
    ["London-UK", "Paris-FR", 15000, 8, 99.95],
    ["London-UK", "Amsterdam-NL", 12000, 5, 99.98],
    ["Frankfurt-DE", "Paris-FR", 14000, 10, 99.95],
    ["Frankfurt-DE", "Amsterdam-NL", 13000, 7, 99.96],

    # US backbone
    ["Ashburn-VA", "Chicago-IL", 20000, 15, 99.98],
    ["Ashburn-VA", "Dallas-TX", 18000, 25, 99.97],
    ["San-Jose-CA", "Chicago-IL", 16000, 35, 99.96],
    ["San-Jose-CA", "Dallas-TX", 14000, 30, 99.95],
    ["Chicago-IL", "Dallas-TX", 12000, 20, 99.97],

    # North-South American links
    ["Dallas-TX", "Sao-Paulo-BR", 8000, 95, 99.4],
    ["Ashburn-VA", "Sao-Paulo-BR", 6000, 110, 99.3],

    # European-African links
    ["London-UK", "Johannesburg-ZA", 4000, 120, 99.2],
    ["Frankfurt-DE", "Johannesburg-ZA", 5000, 130, 99.1],

    # Asian backbone
    ["Singapore-SG", "Tokyo-JP", 15000, 35, 99.98],
    ["Singapore-SG", "Mumbai-IN", 8000, 45, 99.7],
    ["Tokyo-JP", "Mumbai-IN", 6000, 95, 99.6],
    ["Singapore-SG", "Sydney-AU", 10000, 65, 99.8],

    # Additional inter-regional links
    ["Paris-FR", "Mumbai-IN", 7000, 75, 99.5],
    ["Amsterdam-NL", "Mumbai-IN", 6000, 70, 99.6],
    ["London-UK", "Singapore-SG", 8000, 95, 99.4]
  ]

  def self.build_backbone_graph
    n = NODES.size
    adjacency = Array.new(n) { Array.new(n, 0.0) }

    BACKBONE_LINKS.each do |link|
      node1, node2, bandwidth, latency, reliability = link[0], link[1], link[2], link[3], link[4]
      i = NODES.index(node1)
      j = NODES.index(node2)

      if i && j
        # Use inverse bandwidth as weight (higher capacity = lower cost)
        weight = 1.0 / bandwidth.to_f
        adjacency[i][j] = weight
        adjacency[j][i] = weight
      end
    end

    {adjacency: adjacency, nodes: NODES, links: BACKBONE_LINKS}
  end
end

# Create multi-type edge representation for routing
# Different optimization objectives for internet routing
def create_routing_multi_graph(base_adjacency, backbone_links)
  n = base_adjacency.size

  # Edge types based on routing optimization criteria
  edge_types = {
    "bandwidth_capacity" => [] of Tuple(Int32, Int32, Float64),
    "latency_optimization" => [] of Tuple(Int32, Int32, Float64),
    "reliability_routing" => [] of Tuple(Int32, Int32, Float64),
    "load_balancing" => [] of Tuple(Int32, Int32, Float64),
    "cost_efficiency" => [] of Tuple(Int32, Int32, Float64),
    "traffic_engineering" => [] of Tuple(Int32, Int32, Float64)
  }

  # Analyze backbone links and categorize edges
  n.times do |i|
    n.times do |j|
      next if i >= j || base_adjacency[i][j] == 0.0

      # Find the corresponding link data
      node1 = InternetBackboneBuilder::NODES[i]
      node2 = InternetBackboneBuilder::NODES[j]

      link_data = backbone_links.find do |link|
        n1, n2 = link[0], link[1]
        (n1 == node1 && n2 == node2) || (n1 == node2 && n2 == node1)
      end

      if link_data
        bandwidth = link_data[2].as(Int32)
        latency = link_data[3].as(Int32)
        reliability = link_data[4].as(Float64)

        # Bandwidth capacity edges (prioritize high-capacity links)
        bandwidth_weight = bandwidth.to_f / 20000.0  # Normalize to max bandwidth
        edge_types["bandwidth_capacity"] << {i, j, bandwidth_weight}

        # Latency optimization edges (prioritize low-latency links)
        latency_weight = 200.0 / latency  # Inverse latency
        edge_types["latency_optimization"] << {i, j, latency_weight}

        # Reliability routing edges (prioritize high-reliability links)
        reliability_weight = reliability / 100.0
        edge_types["reliability_routing"] << {i, j, reliability_weight}

        # Load balancing edges (distribute traffic)
        load_balance_weight = 1.0 + (0.1 * (i + j) % 10)
        edge_types["load_balancing"] << {i, j, load_balance_weight}

        # Cost efficiency edges (bandwidth per unit cost)
        cost_efficiency_weight = bandwidth / (latency * 0.01)
        edge_types["cost_efficiency"] << {i, j, cost_efficiency_weight}

        # Traffic engineering edges (complex optimization)
        traffic_weight = (bandwidth_weight + latency_weight + reliability_weight) / 3.0
        edge_types["traffic_engineering"] << {i, j, traffic_weight}
      end
    end
  end

  edge_types
end

# Test the internet routing
puts "🌐 BUILDING INTERNET BACKBONE ROUTING NETWORK"
puts "-" * 60

# Build the backbone graph
backbone_data = InternetBackboneBuilder.build_backbone_graph

puts "✅ Internet backbone: #{backbone_data[:nodes].size} nodes, #{backbone_data[:links].size} links"
puts "   Major hubs: #{backbone_data[:nodes].join(", ")}"

# Create multi-type representation
routing_multi = create_routing_multi_graph(backbone_data[:adjacency], backbone_data[:links])

# Node weights (traffic volume for each data center)
# Higher weights = more traffic to route
traffic_weights = [
  1000.0,  # Ashburn-VA (massive traffic hub)
  800.0,   # San-Jose-CA (major West coast hub)
  600.0,   # Chicago-IL (central hub)
  500.0,   # Dallas-TX (southern hub)
  400.0,   # Toronto-ON (Canadian hub)
  300.0,   # Sao-Paulo-BR (South American hub)
  900.0,   # London-UK (European hub)
  700.0,   # Frankfurt-DE (German hub)
  650.0,   # Amsterdam-NL (Dutch hub)
  550.0,   # Paris-FR (French hub)
  350.0,   # Mumbai-IN (Asian hub)
  600.0,   # Singapore-SG (Southeast Asian hub)
  500.0,   # Tokyo-JP (Japanese hub)
  250.0,   # Sydney-AU (Australian hub)
  200.0    # Johannesburg-ZA (African hub)
]

puts "\n📊 ROUTING STATISTICS:"
puts "  Total traffic demand: #{traffic_weights.sum} units"
routing_multi.each do |edge_type, edges|
  puts "  #{edge_type}: #{edges.size} links"
end

# Test 1: Manual routing optimization
puts "\n🧪 TEST 1: MANUAL ROUTING OPTIMIZATION"
puts "Using traditional network engineering principles"
puts "-" * 60

# Traditional network engineering weights
# Bandwidth and latency are typically the most important factors
manual_weights = {
  "bandwidth_capacity" => 3.0,    # Most important - capacity constraints
  "latency_optimization" => 2.5,   # Very important - user experience
  "reliability_routing" => 2.0,    # Important - SLA requirements
  "load_balancing" => 1.5,        # Important for performance
  "cost_efficiency" => 1.0,        # Secondary consideration
  "traffic_engineering" => 0.8     # Complex optimization (last priority)
}

routing_graph = MultiplicativeConstraint::Graph.from_multi_type_edges(traffic_weights, routing_multi)
routing_engine = MultiplicativeConstraint::Engine.new(routing_graph, 4)  # 4 routing regions
routing_engine.set_type_weights(manual_weights)

puts "🌐 Optimizing internet routing with manual weights..."
start_time = Time.utc
routing_result = routing_engine.solve(iterations: 2000, step: 0.3, seed: 42)
routing_time = (Time.utc - start_time).total_seconds

puts "📊 Manual routing results:"
puts "  Energy: #{routing_result.energy.round(4)}"
puts "  Runtime: #{routing_time.round(3)}s"
puts "  Routing regions: #{routing_result.segments}"

# Test 2: Neural routing optimization
puts "\n🧠 TEST 2: NEURAL ROUTING OPTIMIZATION"
puts "Let neural network discover essential routing factors"
puts "-" * 60

neural_routing = MultiplicativeConstraint::Engine.new(routing_graph, 4,
  fairness_weight: 1.0,
  weight_fairness_weight: 1.0,
  entropy_weight: 0.1,
  penalty_weight: 1.0,
  cross_conflict_weight: 0.5,

  # Neural learning
  calibrate: true,
  calibration_samples: 128,
  enable_corr_guard: true,
  corr_min: 0.99,
  guard_window: 16,
  guard_period: 50
)

puts "🔬 Neural network learning internet routing properties..."
start_time = Time.utc
neural_routing_result = neural_routing.solve(iterations: 2000, step: 0.3, seed: 42)
neural_routing_time = (Time.utc - start_time).total_seconds

neural_weights = neural_routing.get_type_weights

puts "🌟 Neural routing results:"
puts "  Energy: #{neural_routing_result.energy.round(4)}"
puts "  Runtime: #{neural_routing_time.round(3)}s"
puts "  Routing regions: #{neural_routing.segments}"

puts "\n🧠 Neural-discovered routing weights:"
neural_weights.each do |routing_type, weight|
  manual_weight = manual_weights[routing_type]?
  diff = manual_weight ? ((weight - manual_weight) / manual_weight * 100).round(1) : 0.0
  puts "  #{routing_type.ljust(25)}: #{weight.round(3)} (manual: #{manual_weight || "N/A"}, diff: #{diff > 0 ? "+" : ""}#{diff}%)"
end

# Test 3: Analyze routing regions
puts "\n🗺️  TEST 3: ROUTING REGION ANALYSIS"
puts "Analyzing how nodes are grouped into routing regions"
puts "-" * 60

puts "\n📍 Manual routing regions:"
routing_result.segments.each_with_index do |region, idx|
  node_names = region.map { |i| backbone_data[:nodes][i] }
  total_traffic = region.sum { |i| traffic_weights[i] }
  puts "  Region #{idx + 1}: #{node_names.join(", ")}"
  puts "    Traffic: #{total_traffic} units, Nodes: #{region.size}"
end

puts "\n🧠 Neural routing regions:"
neural_routing_result.segments.each_with_index do |region, idx|
  node_names = region.map { |i| backbone_data[:nodes][i] }
  total_traffic = region.sum { |i| traffic_weights[i] }
  puts "  Region #{idx + 1}: #{node_names.join(", ")}"
  puts "    Traffic: #{total_traffic} units, Nodes: #{region.size}"
end

# Test 4: Low-dimensional subspace discovery
puts "\n🎯 TEST 4: LOW-DIMENSIONAL SUBSPACE DISCOVERY"
puts "Did neural network identify the essential routing dimensions?"
puts "-" * 60

# Energy improvements
routing_improvement = ((routing_result.energy - neural_routing_result.energy) / routing_result.energy.abs * 100).round(2)
puts "📈 Routing optimization improvement: #{routing_improvement}%"

# Analyze what neural network kept
non_zero_weights = neural_weights.select { |_, weight| weight > 0.1 }
puts "\n🔍 ESSENTIAL ROUTING FACTORS (Neural Network):"
puts "Non-zero weights: #{non_zero_weights.size}/#{neural_weights.size}"
non_zero_weights.each do |factor, weight|
  puts "  #{factor}: #{weight.round(3)}"
end

# Check if neural network found the "bandwidth + latency" essence
bandweight_zero = neural_weights["bandwidth_capacity"] < 0.1
latency_zero = neural_weights["latency_optimization"] < 0.1

puts "\n🔬 FUNDAMENTAL DIMENSIONS ANALYSIS:"
if !bandweight_zero && !latency_zero
  puts "  ✅ Neural network kept both BANDWIDTH and LATENCY factors"
  puts "     This matches network engineering fundamentals"
elsif !bandweight_zero
  puts "  ⚡ Neural network prioritized BANDWIDTH only"
  puts "     Focus on capacity constraints"
elsif !latency_zero
  puts "  ⏱️  Neural network prioritized LATENCY only"
  puts "     Focus on performance optimization"
else
  puts "  ❓ Neural network eliminated both fundamental factors"
  puts "     May have found different optimization strategy"
end

# Test 5: Cross-continental routing analysis
puts "\n🌍 TEST 5: CROSS-CONTINENTAL ROUTING ANALYSIS"
puts "How are different continents grouped in routing regions?"
puts "-" * 60

def analyze_regional_grouping(segments, nodes)
  segments.each_with_index do |region, idx|
    continents = region.map do |node_idx|
      node_name = nodes[node_idx]
      case node_name
      when /VA|CA|IL|TX|ON/ then "North America"
      when /BR|ZA/ then "South America & Africa"
      when /UK|DE|NL|FR/ then "Europe"
      when /IN|SG|JP|AU/ then "Asia-Pacific"
      else "Unknown"
      end
    end.uniq

    puts "  Region #{idx + 1}: #{continents.join(" + ")}"
  end
end

puts "\n📍 Manual regional grouping:"
analyze_regional_grouping(routing_result.segments, backbone_data[:nodes])

puts "\n🧠 Neural regional grouping:"
analyze_regional_grouping(neural_routing_result.segments, backbone_data[:nodes])

# Final assessment
puts "\n🏆 INTERNET ROUTING TEST RESULTS:"
puts "=" * 60

puts "📊 Performance Summary:"
puts "  Manual routing: #{routing_result.energy.round(4)}"
puts "  Neural routing: #{neural_routing_result.energy.round(4)}"
puts "  Improvement: #{routing_improvement}%"

puts "\n🧠 Neural Network Insights:"

# Check if neural found better solution
neural_better = neural_routing_result.energy < routing_result.energy
puts "  Routing optimization: #{neural_better ? "✅ Neural improved" : "⚖️ Manual competitive"}"

# Essential factors analysis
essential_factors = non_zero_weights.map(&.[0])
puts "  Essential factors: #{essential_factors.join(", ")}"

if essential_factors.includes?("bandwidth_capacity") && essential_factors.includes?("latency_optimization")
  puts "  ✅ Neural network identified fundamental routing dimensions"
  puts "     (Bandwidth + Latency = Internet routing essence)"
elsif essential_factors.size == 1
  single_factor = essential_factors.first
  puts "  🎯 Neural network focused on single essential factor: #{single_factor}"
else
  puts "  🔍 Neural network found alternative optimization strategy"
end

puts "\n💡 REAL-WORLD IMPLICATIONS:"
if neural_better && routing_improvement > 10
  puts "  Neural adaptation could improve real internet routing efficiency"
  puts "  Automatic discovery of essential optimization factors"
  puts "  Potential for cost savings and performance improvements"
elsif neural_better
  puts "  Neural adaptation shows promise for routing optimization"
  puts "  Competitive with traditional network engineering"
else
  puts "  Traditional network engineering remains effective"
  puts "  Neural adaptation provides alternative approaches"
end

puts "\n🌐 INTERNET ROUTING TEST COMPLETE"
puts "Neural adaptation tested on real network topology with bandwidth and latency constraints"
puts "=" * 80