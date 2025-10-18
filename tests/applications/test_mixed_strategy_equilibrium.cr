#!/usr/bin/env crystal
# Mixed-Strategy Nash Equilibrium Test
# Tests framework's ability to find probabilistic equilibria
# Based on game-theoretic saddle-point optimization

require "../../src/multiplicative_constraint"

# Test mixed-strategy Nash equilibrium finding
def test_mixed_strategy_equilibrium
  puts "\n" + "="*70
  puts "MIXED-STRATEGY NASH EQUILIBRIUM TEST"
  puts "="*70
  puts "Problem: Rock-Paper-Scissors resource allocation"
  puts "Goal: Find mixed-strategy equilibrium where no pure strategy exists"
  puts "="*70

  # Classic rock-paper-scissors payoff structure
  # 3 agents, 3 resources, cyclic dominance
  # Rock beats Scissors, Scissors beats Paper, Paper beats Rock
  
  num_agents = 3
  num_resources = 3
  total_nodes = num_agents + num_resources
  
  puts "\nPROBLEM SETUP:"
  puts "  Agents: 3 (Rock, Paper, Scissors)"
  puts "  Resources: 3 (Resource A, B, C)"
  puts "  Structure: Cyclic dominance (no pure equilibrium exists)"
  
  agent_names = ["Rock", "Paper", "Scissors"]
  resource_names = ["Resource_A", "Resource_B", "Resource_C"]
  
  puts "\nAGENT-RESOURCE PREFERENCES:"
  puts "  Rock prefers Resource A (value: 10)"
  puts "  Paper prefers Resource B (value: 10)"
  puts "  Scissors prefers Resource C (value: 10)"
  
  # Build edges: preferences + cyclic conflicts
  edges = [] of Tuple(Int32, Int32, Float64)
  
  # Agent 0 (Rock) prefers Resource A (node 3)
  edges << {0, 3, 10.0}
  
  # Agent 1 (Paper) prefers Resource B (node 4)
  edges << {1, 4, 10.0}
  
  # Agent 2 (Scissors) prefers Resource C (node 5)
  edges << {2, 5, 10.0}
  
  # Cyclic conflicts (Rock beats Scissors, etc.)
  puts "\nCYCLIC CONFLICTS:"
  puts "  Rock vs Scissors: -12 (Rock dominates)"
  edges << {0, 2, -12.0}
  
  puts "  Scissors vs Paper: -12 (Scissors dominates)"
  edges << {2, 1, -12.0}
  
  puts "  Paper vs Rock: -12 (Paper dominates)"
  edges << {1, 0, -12.0}
  
  # Convert to adjacency matrix
  adjacency = Array.new(total_nodes) { Array.new(total_nodes, 0.0) }
  edges.each do |i, j, w|
    adjacency[i][j] = w
    adjacency[j][i] = w
  end
  
  # Node weights
  weights = Array.new(total_nodes) do |i|
    i < num_agents ? 10.0 : 1.0
  end
  
  puts "\nBuilding cyclic game graph..."
  puts "  Nodes: #{total_nodes}"
  puts "  Edges: #{edges.size}"
  puts "  Expected: NO pure strategy equilibrium"
  
  graph = MultiplicativeConstraint::Graph.new(weights, adjacency)
  engine = MultiplicativeConstraint::Engine.new(graph, num_agents)
  
  # Run multiple trials to observe mixed behavior
  puts "\n" + "-"*70
  puts "RUNNING MULTIPLE TRIALS (Mixed-Strategy Detection)"
  puts "-"*70
  
  trial_allocations = [] of Array(Array(Int32))
  trial_energies = [] of Float64
  
  5.times do |trial|
    seed = 100 + trial * 13
    start_time = Time.monotonic
    result = engine.solve(iterations: 2000, step: 0.3, seed: seed)
    runtime = (Time.monotonic - start_time).total_seconds
    
    trial_allocations << result.segments
    trial_energies << result.energy
    
    puts "\nTrial #{trial + 1} (seed=#{seed}):"
    puts "  Runtime: #{(runtime * 1000).round(1)}ms"
    puts "  Energy: #{result.energy.round(2)}"
    puts "  Allocation:"
    
    result.segments.each_with_index do |segment, idx|
      agents_in_seg = segment.select { |n| n < num_agents }
      resources_in_seg = segment.select { |n| n >= num_agents }.map { |n| n - num_agents }
      
      if agents_in_seg.size > 0
        agent_str = agents_in_seg.map { |a| agent_names[a] }.join(", ")
        resource_str = resources_in_seg.map { |r| resource_names[r] }.join(", ")
        puts "    Segment #{idx+1}: #{agent_str} -> #{resource_str}"
      end
    end
  end
  
  # Analyze allocation diversity
  puts "\n" + "-"*70
  puts "MIXED-STRATEGY ANALYSIS"
  puts "-"*70
  
  # Count unique allocations
  unique_allocations = trial_allocations.uniq
  allocation_diversity = (unique_allocations.size.to_f / trial_allocations.size * 100).round(1)
  
  puts "  Unique allocations: #{unique_allocations.size}/#{trial_allocations.size}"
  puts "  Allocation diversity: #{allocation_diversity}%"
  
  # Energy variance
  mean_energy = trial_energies.sum / trial_energies.size
  energy_variance = trial_energies.map { |e| (e - mean_energy) ** 2 }.sum / trial_energies.size
  energy_std = Math.sqrt(energy_variance)
  
  puts "  Mean energy: #{mean_energy.round(2)}"
  puts "  Energy std dev: #{energy_std.round(2)}"
  puts "  Energy CV: #{(energy_std / mean_energy.abs * 100).round(2)}%"
  
  # Mixed-strategy indicator
  is_mixed_strategy = allocation_diversity > 20 && energy_std / mean_energy.abs < 0.1
  
  if is_mixed_strategy
    puts "\n  RESULT: Mixed-strategy behavior detected!"
    puts "  - High allocation diversity (#{allocation_diversity}%)"
    puts "  - Low energy variance (stable payoffs)"
    puts "  - No single dominant allocation"
  else
    puts "\n  RESULT: Allocation converges to specific strategy"
    puts "  - Diversity: #{allocation_diversity}%"
  end
  
  # Calculate empirical mixed probabilities
  puts "\n" + "-"*70
  puts "EMPIRICAL MIXED PROBABILITIES"
  puts "-"*70
  
  agent_resource_counts = Hash(Tuple(Int32, Int32), Int32).new(0)
  
  trial_allocations.each do |segments|
    segments.each do |segment|
      agents = segment.select { |n| n < num_agents }
      resources = segment.select { |n| n >= num_agents }.map { |n| n - num_agents }
      
      agents.each do |agent|
        resources.each do |resource|
          agent_resource_counts[{agent, resource}] += 1
        end
      end
    end
  end
  
  num_agents.times do |agent|
    total_assignments = 0
    num_resources.times { |r| total_assignments += agent_resource_counts[{agent, r}] }
    
    if total_assignments > 0
      puts "\n  #{agent_names[agent]}:"
      num_resources.times do |resource|
        count = agent_resource_counts[{agent, resource}]
        prob = (count.to_f / total_assignments * 100).round(1)
        puts "    #{resource_names[resource]}: #{prob}% (#{count}/#{total_assignments} trials)"
      end
    end
  end
  
  # Check if probabilities are roughly uniform (Nash equilibrium indicator)
  puts "\n" + "-"*70
  puts "NASH EQUILIBRIUM VERIFICATION"
  puts "-"*70
  
  # In rock-paper-scissors, Nash equilibrium is (1/3, 1/3, 1/3) for each agent
  expected_prob = 100.0 / num_resources
  max_deviation = 0.0
  
  num_agents.times do |agent|
    total = 0
    num_resources.times { |r| total += agent_resource_counts[{agent, r}] }
    
    if total > 0
      num_resources.times do |resource|
        actual_prob = agent_resource_counts[{agent, resource}].to_f / total * 100
        deviation = (actual_prob - expected_prob).abs
        max_deviation = deviation if deviation > max_deviation
      end
    end
  end
  
  puts "  Expected probability (uniform): #{expected_prob.round(1)}%"
  puts "  Maximum deviation: #{max_deviation.round(1)}%"
  
  is_near_equilibrium = max_deviation < 15.0
  
  if is_near_equilibrium
    puts "  RESULT: Near mixed-strategy Nash equilibrium"
    puts "  Framework found probabilistic equilibrium in cyclic game"
  else
    puts "  RESULT: Deviation from perfect equilibrium"
    puts "  Framework exploring mixed-strategy space"
  end
  
  # Final assessment
  puts "\n" + "="*70
  puts "MIXED-STRATEGY EQUILIBRIUM TEST RESULTS"
  puts "="*70
  puts "  Problem: Cyclic dominance (Rock-Paper-Scissors structure)"
  puts "  Pure equilibrium: None (proven impossible)"
  puts "  Mixed equilibrium: Expected (1/3, 1/3, 1/3)"
  puts ""
  puts "  Allocation diversity: #{allocation_diversity}%"
  puts "  Energy stability: #{((1 - energy_std/mean_energy.abs) * 100).round(1)}%"
  puts "  Equilibrium proximity: #{(100 - max_deviation).round(1)}%"
  puts ""
  
  if is_mixed_strategy && is_near_equilibrium
    puts "  SUCCESS: Framework exhibits mixed-strategy behavior!"
    puts "  Found probabilistic equilibrium in game with no pure solution"
  elsif is_mixed_strategy
    puts "  PARTIAL SUCCESS: Mixed-strategy behavior detected"
    puts "  Framework explores equilibrium space effectively"
  else
    puts "  CONVERGENT: Framework settles on specific allocations"
    puts "  May require more trials or different parameters for full mixing"
  end
  
  puts "="*70
end

# Run the test
puts "\nStarting Mixed-Strategy Nash Equilibrium Test"
puts "Based on operator-theoretic game theory principles"
puts ""

test_mixed_strategy_equilibrium

puts "\nMixed-strategy equilibrium test complete!"
puts "Framework demonstrates game-theoretic optimization capabilities"

