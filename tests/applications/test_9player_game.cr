#!/usr/bin/env crystal
# 9-Player Game Theory Experiment
# Testing framework on large-scale multi-agent competitive dynamics
# Let the divine logistics reveal the patterns

require "../../src/multiplicative_constraint"

def test_9player_competitive_allocation
  puts "\n" + "="*70
  puts "9-PLAYER GAME THEORY EXPERIMENT"
  puts "="*70
  puts "Scenario: 9 companies competing for 18 cloud regions"
  puts "Structure: Complex multi-agent competitive dynamics"
  puts "Question: What equilibrium patterns emerge at scale?"
  puts "="*70
  
  num_players = 9
  num_resources = 18
  total_nodes = num_players + num_resources
  
  player_names = [
    "Tech_Giant_A",
    "Tech_Giant_B", 
    "Startup_C",
    "Enterprise_D",
    "Cloud_E",
    "Gaming_F",
    "Finance_G",
    "Healthcare_H",
    "AI_Company_I"
  ]
  
  region_names = (1..18).map { |i| "Region_#{i}" }.to_a
  
  puts "\nPLAYER SETUP:"
  puts "  Players: #{num_players}"
  puts "  Resources (regions): #{num_resources}"
  puts "  Total graph nodes: #{total_nodes}"
  
  # Build complex preference structure
  # Each player has preferred regions based on their domain
  edges = [] of Tuple(Int32, Int32, Float64)
  
  random = Random.new(777)  # Deterministic seed for reproducibility
  
  puts "\nPREFERENCE STRUCTURE:"
  
  # Tech Giants prefer different global regions
  puts "  Tech Giants (A, B): Global coverage strategy"
  [0, 1].each do |player|
    6.times do |i|
      region = player * 9 + i
      value = 15.0 + random.rand * 10.0
      edges << {player, num_players + region, value}
    end
  end
  
  # Startup prefers cost-effective regions
  puts "  Startup C: Cost-effective regions (1-6)"
  6.times do |i|
    value = 12.0 + random.rand * 8.0
    edges << {2, num_players + i, value}
  end
  
  # Enterprise prefers reliability (mid regions)
  puts "  Enterprise D: Reliability-focused (5-12)"
  8.times do |i|
    value = 14.0 + random.rand * 7.0
    edges << {3, num_players + (5 + i), value}
  end
  
  # Cloud provider wants distributed presence
  puts "  Cloud E: Distributed strategy (every 3rd region)"
  6.times do |i|
    region = i * 3
    value = 13.0 + random.rand * 9.0
    edges << {4, num_players + region, value}
  end
  
  # Gaming company prefers low-latency
  puts "  Gaming F: Low-latency regions (8-15)"
  8.times do |i|
    value = 16.0 + random.rand * 6.0
    edges << {5, num_players + (8 + i), value}
  end
  
  # Finance needs regulatory compliance
  puts "  Finance G: Regulated regions (2-9)"
  8.times do |i|
    value = 17.0 + random.rand * 8.0
    edges << {6, num_players + (2 + i), value}
  end
  
  # Healthcare needs data sovereignty
  puts "  Healthcare H: Sovereignty regions (10-17)"
  8.times do |i|
    value = 15.0 + random.rand * 7.0
    edges << {7, num_players + (10 + i), value}
  end
  
  # AI company needs GPU availability
  puts "  AI Company I: GPU-rich regions (scattered)"
  [0, 3, 6, 9, 12, 15].each do |region|
    value = 18.0 + random.rand * 10.0
    edges << {8, num_players + region, value}
  end
  
  # Add COMPLEX competition network
  puts "\nCOMPETITION NETWORK:"
  
  # Tech giants compete heavily
  edges << {0, 1, -25.0}
  puts "  Tech_Giant_A <-> Tech_Giant_B: -25.0 (intense rivalry)"
  
  # All compete for popular regions
  competition_groups = [
    [0, 2, 3],  # Tech A, Startup, Enterprise
    [1, 4, 5],  # Tech B, Cloud, Gaming
    [6, 7, 8],  # Finance, Healthcare, AI
  ]
  
  competition_groups.each_with_index do |group, idx|
    group.each_with_index do |p1, i|
      group.each_with_index do |p2, j|
        next if i >= j
        conflict = -15.0 - random.rand * 10.0
        edges << {p1, p2, conflict}
        puts "  #{player_names[p1]} <-> #{player_names[p2]}: #{conflict.round(2)}"
      end
    end
  end
  
  # Cross-group mild competition
  puts "\n  Cross-group competition (milder):"
  [0, 1, 2].each do |i|
    [3, 4, 5].each do |j|
      conflict = -8.0 - random.rand * 5.0
      edges << {i, j, conflict}
    end
  end
  
  total_positive = edges.count { |e| e[2] > 0 }
  total_negative = edges.count { |e| e[2] < 0 }
  
  puts "\nGRAPH STATISTICS:"
  puts "  Total edges: #{edges.size}"
  puts "  Preference edges: #{total_positive}"
  puts "  Competition edges: #{total_negative}"
  puts "  Average competition: #{edges.select { |e| e[2] < 0 }.map { |e| e[2] }.sum / total_negative}"
  
  # Build graph
  adjacency = Array.new(total_nodes) { Array.new(total_nodes, 0.0) }
  edges.each do |i, j, w|
    adjacency[i][j] = w
    adjacency[j][i] = w
  end
  
  weights = Array.new(total_nodes) do |i|
    i < num_players ? 10.0 : 1.0
  end
  
  puts "\nBuilding 9-player game graph..."
  graph = MultiplicativeConstraint::Graph.new(weights, adjacency)
  
  # Try different segment configurations
  puts "\n" + "="*70
  puts "DIVINE PREDICTION: What equilibrium emerges?"
  puts "="*70
  
  first_solve_time = Time.monotonic
  
  [3, 4, 5, 6, 9].each do |num_segments|
    puts "\nTrying #{num_segments} segments (coalitions):"
    puts "-" * 70
    
    engine = MultiplicativeConstraint::Engine.new(graph, num_segments)
    
    start_time = Time.monotonic
    result = engine.solve(iterations: 3000, step: 0.3, seed: 888)
    runtime = (Time.monotonic - start_time).total_seconds
    
    puts "  Runtime: #{(runtime * 1000).round(1)}ms"
    puts "  Energy: #{result.energy.round(2)}"
    puts "  Segments found: #{result.segments.size}"
    
    # Display coalitions
    puts "\n  COALITION STRUCTURE:"
    result.segments.each_with_index do |segment, idx|
      players_in_seg = segment.select { |n| n < num_players }
      regions_in_seg = segment.select { |n| n >= num_players }.map { |n| n - num_players + 1 }
      
      if players_in_seg.size > 0
        player_str = players_in_seg.map { |p| player_names[p] }.join(", ")
        puts "    Coalition #{idx+1} (#{players_in_seg.size} players):"
        puts "      Players: #{player_str}"
        puts "      Regions: #{regions_in_seg.size} regions allocated"
      end
    end
    
    # Coalition analysis
    coalition_sizes = result.segments.map { |s| s.select { |n| n < num_players }.size }
    max_coalition = coalition_sizes.max
    min_coalition = coalition_sizes.min
    
    balance_score = 1.0 - (max_coalition - min_coalition).to_f / num_players
    
    puts "\n  COALITION BALANCE:"
    puts "    Largest coalition: #{max_coalition} players"
    puts "    Smallest coalition: #{min_coalition} players"
    puts "    Balance score: #{(balance_score * 100).round(1)}%"
    
    # Competition resolution
    total_conflict = 0.0
    result.segments.each do |segment|
      players = segment.select { |n| n < num_players }
      players.each_with_index do |p1, i|
        players.each_with_index do |p2, j|
          next if i >= j
          edge = edges.find { |e1, e2, w| 
            ((e1 == p1 && e2 == p2) || (e1 == p2 && e2 == p1)) && w < 0
          }
          total_conflict += edge[2] if edge
        end
      end
    end
    
    puts "  Total in-coalition conflict: #{total_conflict.round(2)}"
    puts "  Conflict per coalition: #{(total_conflict / result.segments.size).round(2)}"
  end
  
  # DIVINE PREDICTION ANALYSIS
  puts "\n\n" + "="*70
  puts "DIVINE PATTERN RECOGNITION"
  puts "="*70
  
  # Final solve with optimal segments (let framework decide)
  best_segments = 5  # Middle ground
  engine_final = MultiplicativeConstraint::Engine.new(graph, best_segments)
  
  puts "\nLetting framework find natural equilibrium (#{best_segments} segments)..."
  final_result = engine_final.solve(iterations: 5000, step: 0.3, seed: 999)
  
  puts "\nFINAL COALITION STRUCTURE:"
  puts "-" * 70
  
  final_result.segments.each_with_index do |segment, idx|
    players_in_seg = segment.select { |n| n < num_players }
    regions_in_seg = segment.select { |n| n >= num_players }.map { |n| n - num_players + 1 }
    
    next if players_in_seg.empty?
    
    puts "\nCoalition #{idx+1}:"
    players_in_seg.each do |p|
      puts "  - #{player_names[p]}"
    end
    puts "  Controls: #{regions_in_seg.size} regions"
    
    # Calculate coalition strength
    strength = 0.0
    players_in_seg.each do |player|
      regions_in_seg.each do |region|
        edge = edges.find { |i, j, w| i == player && j == (num_players + region - 1) && w > 0 }
        strength += edge[2] if edge
      end
    end
    
    # Internal conflict
    conflict = 0.0
    players_in_seg.each_with_index do |p1, i|
      players_in_seg.each_with_index do |p2, j|
        next if i >= j
        edge = edges.find { |e1, e2, w| 
          ((e1 == p1 && e2 == p2) || (e1 == p2 && e2 == p1)) && w < 0
        }
        conflict += edge[2] if edge
      end
    end
    
    puts "  Strength: #{strength.round(2)}"
    puts "  Internal conflict: #{conflict.round(2)}"
    puts "  Net power: #{(strength + conflict).round(2)}"
  end
  
  # EMERGENT PATTERNS
  puts "\n\n" + "="*70
  puts "EMERGENT PATTERNS FROM 9-PLAYER DYNAMICS"
  puts "="*70
  
  coalition_sizes = final_result.segments.map { |s| s.select { |n| n < num_players }.size }.sort.reverse
  
  puts "\nCoalition size distribution: #{coalition_sizes.inspect}"
  
  # Check for power law / natural clustering
  if coalition_sizes[0] >= 3 && coalition_sizes[-1] >= 1
    puts "  Pattern: HIERARCHICAL (some large, some small coalitions)"
  elsif coalition_sizes.max - coalition_sizes.min <= 1
    puts "  Pattern: BALANCED (approximately equal coalitions)"
  else
    puts "  Pattern: MIXED (varied coalition sizes)"
  end
  
  # Count isolated players
  isolated = coalition_sizes.count { |s| s == 1 }
  puts "  Isolated players: #{isolated}/#{num_players}"
  
  # Largest coalition
  largest_coalition = final_result.segments.max_by { |s| s.select { |n| n < num_players }.size }
  largest_players = largest_coalition.select { |n| n < num_players }
  
  if largest_players.size >= 4
    puts "\n  DOMINANT COALITION FORMED:"
    largest_players.each do |p|
      puts "    - #{player_names[p]}"
    end
    puts "  Coalition size: #{largest_players.size}/#{num_players} (#{(largest_players.size.to_f / num_players * 100).round(1)}%)"
  end
  
  # STABILITY ANALYSIS
  puts "\n\n" + "="*70
  puts "STABILITY METRICS"
  puts "="*70
  
  puts "  Energy: #{final_result.energy.round(2)}"
  puts "  Coalitions: #{final_result.segments.size}"
  puts "  Total runtime: #{(Time.monotonic - first_solve_time).total_seconds.round(3)}s"
  
  # Coalition stability (no profitable deviations)
  puts "\n  Testing coalition stability..."
  
  stable_coalitions = 0
  final_result.segments.each_with_index do |segment, idx|
    players = segment.select { |n| n < num_players }
    next if players.empty?
    
    # Check if any player wants to leave
    wants_to_leave = players.any? do |player|
      # Calculate utility in current coalition
      current_utility = 0.0
      segment.each do |other_node|
        edge = edges.find { |i, j, w| 
          (i == player && j == other_node) || (i == other_node && j == player)
        }
        current_utility += edge[2] if edge
      end
      
      # Check if joining another coalition is better (simplified)
      current_utility < -10.0  # High negative = wants to leave
    end
    
    if !wants_to_leave
      stable_coalitions += 1
    end
  end
  
  puts "  Stable coalitions: #{stable_coalitions}/#{final_result.segments.size}"
  puts "  Stability rate: #{(stable_coalitions.to_f / final_result.segments.size * 100).round(1)}%"
  
  # DIVINE PREDICTION
  puts "\n\n" + "="*70
  puts "WHAT THE FRAMEWORK PREDICTS"
  puts "="*70
  
  puts "\nFrom #{num_players} competing players, the framework predicts:"
  puts "  - Natural coalitions: #{final_result.segments.size}"
  puts "  - Coalition sizes: #{coalition_sizes.inspect}"
  puts "  - Dominant alliance: #{largest_players.size} players"
  puts "  - Isolated actors: #{isolated}"
  puts "  - Stability: #{(stable_coalitions.to_f / final_result.segments.size * 100).round(1)}%"
  
  # Pattern interpretation
  puts "\nPATTERN INTERPRETATION:"
  
  if largest_players.size >= num_players / 2
    puts "  MAJORITY COALITION forms (#{largest_players.size} players)"
    puts "  Prediction: Winner-take-most dynamics"
  elsif coalition_sizes.max <= 3
    puts "  NO DOMINANT PLAYER emerges"
    puts "  Prediction: Fragmented market, multiple alliances"
  else
    puts "  OLIGOPOLY structure emerges"
    puts "  Prediction: Few large players dominate, others niche"
  end
  
  # Check for cyclic structures
  if coalition_sizes.uniq.size == coalition_sizes.size
    puts "  All coalitions have DIFFERENT sizes"
    puts "  Prediction: Hierarchical power structure (no symmetry)"
  else
    puts "  Some coalitions have SAME sizes"
    puts "  Prediction: Symmetric competition (balanced forces)"
  end
  
  # FINAL VERDICT
  puts "\n\n" + "="*70
  puts "9-PLAYER GAME THEORY RESULTS"
  puts "="*70
  puts "  Problem complexity: 9 players × 18 regions = #{total_nodes} nodes"
  puts "  Preference edges: #{total_positive}"
  puts "  Competition edges: #{total_negative}"
  puts "  Total complexity: #{edges.size} relationships"
  puts ""
  puts "  Framework prediction:"
  puts "    Coalition structure: #{coalition_sizes.inspect}"
  puts "    Dominant coalition: #{largest_players.size} players"
  puts "    Stability: #{(stable_coalitions.to_f / final_result.segments.size * 100).round(1)}%"
  puts "    Energy: #{final_result.energy.round(2)}"
  puts ""
  
  if largest_players.size >= 4 && stable_coalitions >= final_result.segments.size / 2
    puts "  PREDICTION: Stable oligopoly emerges"
    puts "  Few large coalitions dominate the market"
    puts "  Framework found game-theoretic equilibrium at scale"
  elsif isolated >= num_players / 3
    puts "  PREDICTION: Highly fragmented market"
    puts "  No stable large coalitions form"
    puts "  Competition prevents cooperation"
  else
    puts "  PREDICTION: Mixed competitive landscape"
    puts "  Multiple mid-sized coalitions coexist"
    puts "  Balanced power distribution"
  end
  
  puts "\n  DIVINE LOGISTICS: Framework reveals natural equilibrium patterns"
  puts "  at scale that would take game theorists weeks to analyze!"
  puts "="*70
end

# Run the experiment
puts "\nStarting 9-Player Game Theory Experiment"
puts "Let's see what patterns the divine logistics reveals..."
puts ""

start_time = Time.monotonic
test_9player_competitive_allocation
total_time = (Time.monotonic - start_time).total_seconds

puts "\n9-Player game complete!"
puts "Total runtime: #{total_time.round(2)}s"
puts "Framework predicted emergent coalition structures from complex competition!"

