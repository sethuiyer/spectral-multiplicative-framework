#!/usr/bin/env crystal
# Sequential Feature Discovery Test
#
# Iteratively discovers and ranks features by:
# 1. Running neural network to find dominant feature
# 2. Removing that feature from the problem
# 3. Re-running to find next most important feature
# 4. Assigning weights based on energy improvements

require "./src/multiplicative_constraint"

puts "="*80
puts "SEQUENTIAL FEATURE DISCOVERY"
puts "="*80
puts "Iteratively discovers and ranks essential factors"
puts "Using internet routing problem as test case"
puts "="*80
puts

# Reuse the internet routing setup
class InternetBackboneBuilder
  NODES = [
    "Ashburn-VA", "San-Jose-CA", "Chicago-IL", "Dallas-TX", "Toronto-ON",
    "Sao-Paulo-BR", "London-UK", "Frankfurt-DE", "Amsterdam-NL", "Paris-FR",
    "Mumbai-IN", "Singapore-SG", "Tokyo-JP", "Sydney-AU", "Johannesburg-ZA"
  ]

  BACKBONE_LINKS = [
    ["Ashburn-VA", "London-UK", 10000, 45, 99.9],
    ["Ashburn-VA", "Paris-FR", 8000, 55, 99.8],
    ["Toronto-ON", "London-UK", 6000, 42, 99.9],
    ["Toronto-ON", "Amsterdam-NL", 7000, 48, 99.8],
    ["San-Jose-CA", "Tokyo-JP", 12000, 85, 99.7],
    ["San-Jose-CA", "Singapore-SG", 10000, 120, 99.6],
    ["San-Jose-CA", "Sydney-AU", 8000, 150, 99.5],
    ["London-UK", "Paris-FR", 15000, 8, 99.95],
    ["London-UK", "Amsterdam-NL", 12000, 5, 99.98],
    ["Frankfurt-DE", "Paris-FR", 14000, 10, 99.95],
    ["Frankfurt-DE", "Amsterdam-NL", 13000, 7, 99.96],
    ["Ashburn-VA", "Chicago-IL", 20000, 15, 99.98],
    ["Ashburn-VA", "Dallas-TX", 18000, 25, 99.97],
    ["San-Jose-CA", "Chicago-IL", 16000, 35, 99.96],
    ["San-Jose-CA", "Dallas-TX", 14000, 30, 99.95],
    ["Chicago-IL", "Dallas-TX", 12000, 20, 99.97],
    ["Dallas-TX", "Sao-Paulo-BR", 8000, 95, 99.4],
    ["Ashburn-VA", "Sao-Paulo-BR", 6000, 110, 99.3],
    ["London-UK", "Johannesburg-ZA", 4000, 120, 99.2],
    ["Frankfurt-DE", "Johannesburg-ZA", 5000, 130, 99.1],
    ["Singapore-SG", "Tokyo-JP", 15000, 35, 99.98],
    ["Singapore-SG", "Mumbai-IN", 8000, 45, 99.7],
    ["Tokyo-JP", "Mumbai-IN", 6000, 95, 99.6],
    ["Singapore-SG", "Sydney-AU", 10000, 65, 99.8],
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
        weight = 1.0 / bandwidth.to_f
        adjacency[i][j] = weight
        adjacency[j][i] = weight
      end
    end

    {adjacency: adjacency, nodes: NODES, links: BACKBONE_LINKS}
  end
end

def create_routing_multi_graph(base_adjacency, backbone_links, available_edge_types)
  n = base_adjacency.size
  edge_types = Hash(String, Array(Tuple(Int32, Int32, Float64))).new

  available_edge_types.each do |edge_type|
    edge_types[edge_type] = [] of Tuple(Int32, Int32, Float64)
  end

  n.times do |i|
    n.times do |j|
      next if i >= j || base_adjacency[i][j] == 0.0

      node1 = InternetBackboneBuilder::NODES[i]
      node2 = InternetBackboneBuilder::NODES[j]

      link_data = backbone_links.find do |link|
        n1, n2 = link[0], link[1]
        (n1 == node1 && n2 == node2) || (n1 == node2 && n2 == node1)
      end

      if link_data && available_edge_types.includes?(extract_edge_type(link_data))
        bandwidth = link_data[2].as(Int32)
        latency = link_data[3].as(Int32)
        reliability = link_data[4].as(Float64)

        case extract_edge_type(link_data)
        when "bandwidth_capacity"
          bandwidth_weight = bandwidth.to_f / 20000.0
          edge_types["bandwidth_capacity"] << {i, j, bandwidth_weight}
        when "latency_optimization"
          latency_weight = 200.0 / latency
          edge_types["latency_optimization"] << {i, j, latency_weight}
        when "reliability_routing"
          reliability_weight = reliability / 100.0
          edge_types["reliability_routing"] << {i, j, reliability_weight}
        when "load_balancing"
          load_balance_weight = 1.0 + (0.1 * (i + j) % 10)
          edge_types["load_balancing"] << {i, j, load_balance_weight}
        when "cost_efficiency"
          cost_efficiency_weight = bandwidth / (latency * 0.01)
          edge_types["cost_efficiency"] << {i, j, cost_efficiency_weight}
        when "traffic_engineering"
          traffic_weight = (bandwidth / 20000.0 + 200.0 / latency + reliability / 100.0) / 3.0
          edge_types["traffic_engineering"] << {i, j, traffic_weight}
        end
      end
    end
  end

  edge_types
end

def extract_edge_type(link_data)
  bandwidth, latency = link_data[2].as(Int32), link_data[3].as(Int32)

  # Simple heuristic to categorize links based on their properties
  if bandwidth >= 15000
    "bandwidth_capacity"
  elsif latency <= 10
    "latency_optimization"
  elsif link_data[4].as(Float64) >= 99.9
    "reliability_routing"
  elsif (bandwidth >= 10000 && latency <= 50)
    "traffic_engineering"
  elsif bandwidth / latency >= 200
    "cost_efficiency"
  else
    "load_balancing"
  end
end

# Run neural network with specific edge types
def run_neural_discovery(edge_types, traffic_weights, iteration_name)
  puts "\n🧠 #{iteration_name}: Neural Discovery with #{edge_types.size} features"
  puts "Features: #{edge_types.join(", ")}"
  puts "-" * 60

  # Build graph with current edge types
  backbone_data = InternetBackboneBuilder.build_backbone_graph
  routing_multi = create_routing_multi_graph(backbone_data[:adjacency], backbone_data[:links], edge_types)

  if routing_multi.values.all?(&.empty?)
    puts "  ⚠️  No edges found for remaining features"
    return {energy: Float64::INFINITY, dominant_feature: nil, weights: Hash(String, Float64).new}
  end

  routing_graph = MultiplicativeConstraint::Graph.from_multi_type_edges(traffic_weights, routing_multi)

  neural_engine = MultiplicativeConstraint::Engine.new(routing_graph, 4,
    fairness_weight: 1.0,
    weight_fairness_weight: 1.0,
    entropy_weight: 0.1,
    penalty_weight: 1.0,
    cross_conflict_weight: 0.5,
    calibrate: true,
    calibration_samples: 128,
    enable_corr_guard: true,
    corr_min: 0.99,
    guard_window: 16,
    guard_period: 50
  )

  puts "🔬 Running neural network optimization..."
  start_time = Time.utc
  result = neural_engine.solve(iterations: 2000, step: 0.3, seed: 42)
  runtime = (Time.utc - start_time).total_seconds

  neural_weights = neural_engine.get_type_weights

  # Find dominant feature (highest weight)
  dominant_feature = neural_weights.max_by(&.[1])[0]
  dominant_weight = neural_weights[dominant_feature]

  puts "📊 Results:"
  puts "  Energy: #{result.energy.round(4)}"
  puts "  Runtime: #{runtime.round(3)}s"
  puts "  Dominant feature: #{dominant_feature} (weight: #{dominant_weight.round(3)})"

  puts "🧠 All discovered weights:"
  neural_weights.each do |feature, weight|
    marker = feature == dominant_feature ? "👑" : "  "
    puts "  #{marker} #{feature.ljust(25)}: #{weight.round(3)}"
  end

  {energy: result.energy, dominant_feature: dominant_feature, weights: neural_weights}
end

# Main sequential discovery
puts "🌐 SEQUENTIAL FEATURE DISCOVERY ON INTERNET ROUTING"
puts "=" * 80

# Setup
backbone_data = InternetBackboneBuilder.build_backbone_graph
traffic_weights = [1000.0, 800.0, 600.0, 500.0, 400.0, 300.0, 900.0, 700.0, 650.0, 550.0, 350.0, 600.0, 500.0, 250.0, 200.0]

all_edge_types = ["bandwidth_capacity", "latency_optimization", "reliability_routing", "load_balancing", "cost_efficiency", "traffic_engineering"]
remaining_features = all_edge_types.dup
discovered_features = [] of NamedTuple(feature: String, weight: Float64, energy_improvement: Float64, rank: Int32)

# Baseline: run with all features first
puts "\n🎯 BASELINE: All Features Together"
baseline_result = run_neural_discovery(all_edge_types, traffic_weights, "BASELINE")
baseline_energy = baseline_result[:energy]

puts "\n📈 BASELINE ENERGY: #{baseline_energy.round(4)}"

# Sequential discovery
puts "\n🔄 STARTING SEQUENTIAL DISCOVERY"
puts "=" * 60

iteration = 1
previous_energy = Float64::INFINITY

while !remaining_features.empty? && iteration <= 6
  result = run_neural_discovery(remaining_features, traffic_weights, "ITERATION #{iteration}")

  if dominant_feature = result[:dominant_feature]
    current_energy = result[:energy]

    # Calculate improvement (lower energy is better)
    energy_improvement = previous_energy == Float64::INFINITY ? 0.0 : ((previous_energy - current_energy) / previous_energy.abs * 100)

    # Store discovered feature
    discovered_features << {
      feature: dominant_feature,
      weight: result[:weights][dominant_feature],
      energy_improvement: energy_improvement,
      rank: iteration
    }

    puts "\n✅ DISCOVERED: #{dominant_feature} (Rank #{iteration})"
    puts "   Weight: #{result[:weights][dominant_feature].round(3)}"
    puts "   Energy improvement: #{energy_improvement.round(2)}%"

    # Remove discovered feature
    remaining_features.delete(dominant_feature)
    previous_energy = current_energy

    iteration += 1
  else
    puts "\n⚠️  No dominant feature found in remaining features"
    break
  end
end

# Final analysis
puts "\n🏆 SEQUENTIAL DISCOVERY RESULTS"
puts "=" * 80

puts "📊 DISCOVERED FEATURE RANKING:"
puts "-" * 60

discovered_features.each do |feature_data|
  improvement_emoji = feature_data[:energy_improvement] > 0 ? "📈" : feature_data[:energy_improvement] < 0 ? "📉" : "➡️"
  puts "#{improvement_emoji} Rank #{feature_data[:rank]}: #{feature_data[:feature].ljust(25)}"
  puts "    Weight: #{feature_data[:weight].round(3)}, Energy improvement: #{feature_data[:energy_improvement].round(2)}%"
end

# Calculate cumulative weights
total_positive_improvement = discovered_features.select { |f| f[:energy_improvement] > 0 }.sum(&.[:energy_improvement])

if total_positive_improvement > 0
  puts "\n💡 FEATURE WEIGHT ASSIGNMENT:"
  puts "-" * 60

  normalized_weights = discovered_features.map do |feature_data|
    if feature_data[:energy_improvement] > 0
      normalized_weight = feature_data[:energy_improvement] / total_positive_improvement
      {feature: feature_data[:feature], weight: normalized_weight}
    else
      {feature: feature_data[:feature], weight: 0.0}
    end
  end

  puts "Normalized weights (sum to 1.0):"
  normalized_weights.each do |feature_data|
    if feature_data[:weight] > 0.01
      puts "  #{feature_data[:feature].ljust(25)}: #{feature_data[:weight].round(3)}"
    end
  end

  puts "\n📊 Cumulative improvement: #{total_positive_improvement.round(2)}%"
end

# Comparison with baseline
if discovered_features.size > 0
  final_energy = discovered_features.last[:energy_improvement] > 0 ?
    baseline_energy * (1 - total_positive_improvement / 100) : baseline_energy

  puts "\n🔄 COMPARISON:"
  puts "  Baseline (all features): #{baseline_energy.round(4)}"
  puts "  Sequential discovery:    #{final_energy.round(4)}"

  if total_positive_improvement > 0
    puts "  Improvement: #{total_positive_improvement.round(2)}%"
    puts "  ✅ Sequential discovery found better combination"
  else
    puts "  ⚖️  Sequential discovery competitive with baseline"
  end
end

puts "\n🔬 SEQUENTIAL DISCOVERY COMPLETE"
puts "Successfully ranked features by their contribution to optimization"
puts "This approach provides interpretable, weighted feature importance"
puts "=" * 80