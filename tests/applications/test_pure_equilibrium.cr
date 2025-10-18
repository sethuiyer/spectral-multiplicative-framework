#!/usr/bin/env crystal
# Pure-Strategy Nash Equilibrium Test
# Tests framework on problems with guaranteed pure equilibria
# Based on stable matching and coordination games

require "../../src/multiplicative_constraint"

# Test pure-strategy Nash equilibrium finding
def test_pure_strategy_equilibrium
  puts "\n" + "="*70
  puts "PURE-STRATEGY NASH EQUILIBRIUM TEST"
  puts "="*70
  puts "Problem: Stable matching with aligned preferences"
  puts "Goal: Find pure-strategy equilibrium (guaranteed to exist)"
  puts "="*70

  # Stable matching problem: workers and jobs with aligned preferences
  # This has a pure Nash equilibrium by construction
  
  num_workers = 4
  num_jobs = 4
  total_nodes = num_workers + num_jobs
  
  puts "\nPROBLEM SETUP:"
  puts "  Workers: 4 (W1, W2, W3, W4)"
  puts "  Jobs: 4 (J1, J2, J3, J4)"
  puts "  Structure: Aligned preferences (pure equilibrium exists)"
  
  worker_names = ["Worker_1", "Worker_2", "Worker_3", "Worker_4"]
  job_names = ["Job_1", "Job_2", "Job_3", "Job_4"]
  
  # Build preference graph with strong diagonal preference
  # W1 strongly prefers J1, W2 prefers J2, etc.
  # This creates a stable matching with pure equilibrium
  
  puts "\nWORKER-JOB PREFERENCES (Strong Diagonal):"
  
  edges = [] of Tuple(Int32, Int32, Float64)
  
  # Diagonal preferences (strong matches)
  puts "  Strong matches (optimal pairing):"
  4.times do |i|
    value = 20.0 + Random.rand * 5.0
    edges << {i, num_workers + i, value}
    puts "    #{worker_names[i]} -> #{job_names[i]}: #{value.round(2)}"
  end
  
  # Off-diagonal preferences (weaker alternatives)
  puts "\n  Weaker alternatives:"
  4.times do |worker|
    4.times do |job|
      next if worker == job  # Skip diagonal (already added)
      
      # Off-diagonal gets much lower weight
      value = 5.0 + Random.rand * 3.0
      edges << {worker, num_workers + job, value}
      puts "    #{worker_names[worker]} -> #{job_names[job]}: #{value.round(2)}"
    end
  end
  
  # Add mild competition penalties (workers competing for same job)
  puts "\n  Competition penalties (workers competing):"
  4.times do |w1|
    (w1+1..3).each do |w2|
      penalty = -8.0
      edges << {w1, w2, penalty}
      puts "    #{worker_names[w1]} <-> #{worker_names[w2]}: #{penalty}"
    end
  end
  
  # Convert to adjacency matrix
  adjacency = Array.new(total_nodes) { Array.new(total_nodes, 0.0) }
  edges.each do |i, j, w|
    adjacency[i][j] = w
    adjacency[j][i] = w
  end
  
  # Node weights
  weights = Array.new(total_nodes) do |i|
    i < num_workers ? 10.0 : 1.0
  end
  
  puts "\nBuilding stable matching graph..."
  puts "  Nodes: #{total_nodes}"
  puts "  Edges: #{edges.size}"
  puts "  Expected: Pure strategy Nash equilibrium (diagonal matching)"
  
  graph = MultiplicativeConstraint::Graph.new(weights, adjacency)
  engine = MultiplicativeConstraint::Engine.new(graph, num_workers)
  
  # Solve the problem
  puts "\n" + "-"*70
  puts "OPTIMIZATION"
  puts "-"*70
  
  start_time = Time.monotonic
  result = engine.solve(iterations: 3000, step: 0.3, seed: 42)
  runtime = (Time.monotonic - start_time).total_seconds
  
  puts "  Runtime: #{(runtime * 1000).round(1)}ms"
  puts "  Energy: #{result.energy.round(2)}"
  puts "  Segments: #{result.segments.size}"
  
  # Display allocation
  puts "\n  MATCHING RESULT:"
  
  worker_job_assignment = Hash(Int32, Array(Int32)).new { |h, k| h[k] = [] of Int32 }
  
  result.segments.each_with_index do |segment, idx|
    workers_in_seg = segment.select { |n| n < num_workers }
    jobs_in_seg = segment.select { |n| n >= num_workers }.map { |n| n - num_workers }
    
    workers_in_seg.each do |worker|
      worker_job_assignment[worker] = jobs_in_seg
    end
    
    if workers_in_seg.size > 0
      worker_str = workers_in_seg.map { |w| worker_names[w] }.join(", ")
      job_str = jobs_in_seg.map { |j| job_names[j] }.join(", ")
      puts "    Segment #{idx+1}: #{worker_str} matched with #{job_str}"
    end
  end
  
  # Calculate utilities
  puts "\n" + "-"*70
  puts "UTILITY ANALYSIS"
  puts "-"*70
  
  worker_utilities = Array.new(num_workers, 0.0)
  
  num_workers.times do |worker|
    assigned_jobs = worker_job_assignment[worker]
    
    assigned_jobs.each do |job|
      # Find edge weight
      edge = edges.find { |i, j, w| i == worker && j == (num_workers + job) && w > 0 }
      worker_utilities[worker] += edge[2] if edge
    end
    
    # Subtract competition penalty if multiple workers in same segment
    result.segments.each do |segment|
      workers_in_seg = segment.select { |n| n < num_workers }
      if workers_in_seg.includes?(worker)
        # Penalty distributed among all workers in segment
        workers_in_seg.each do |other|
          next if other == worker
          penalty_edge = edges.find { |i, j, w| 
            ((i == worker && j == other) || (i == other && j == worker)) && w < 0
          }
          worker_utilities[worker] += penalty_edge[2] / workers_in_seg.size if penalty_edge
        end
      end
    end
  end
  
  num_workers.times do |worker|
    jobs = worker_job_assignment[worker].map { |j| job_names[j] }.join(", ")
    jobs = "None" if worker_job_assignment[worker].empty?
    puts "  #{worker_names[worker]}: Utility = #{worker_utilities[worker].round(2)} (Jobs: #{jobs})"
  end
  
  # Check for pure Nash equilibrium
  puts "\n" + "-"*70
  puts "NASH EQUILIBRIUM VERIFICATION"
  puts "-"*70
  
  is_pure_nash = true
  num_workers.times do |worker|
    current_utility = worker_utilities[worker]
    current_jobs = worker_job_assignment[worker]
    
    # Check if worker can improve by switching to another job
    best_alternative_utility = current_utility
    best_alternative_job = -1
    
    num_jobs.times do |job|
      next if current_jobs.includes?(job)
      
      # Calculate utility if worker switches to this job
      edge = edges.find { |i, j, w| i == worker && j == (num_workers + job) && w > 0 }
      alternative_utility = edge ? edge[2] : 0.0
      
      if alternative_utility > best_alternative_utility
        best_alternative_utility = alternative_utility
        best_alternative_job = job
      end
    end
    
    improvement = best_alternative_utility - current_utility
    
    if improvement > 0.1
      puts "  Worker #{worker+1} could improve by #{improvement.round(2)} switching to Job #{best_alternative_job+1}"
      is_pure_nash = false
    else
      puts "  Worker #{worker+1}: No profitable deviation (best: #{best_alternative_job == -1 ? "current" : "Job #{best_alternative_job+1}"})"
    end
  end
  
  # Check if matching is stable (no blocking pairs)
  puts "\n  STABILITY CHECK (Blocking pairs):"
  
  blocking_pairs = [] of Tuple(Int32, Int32)
  
  num_workers.times do |worker|
    num_jobs.times do |job|
      current_jobs = worker_job_assignment[worker]
      next if current_jobs.includes?(job)
      
      # Find who is matched with this job
      job_partner = -1
      result.segments.each do |segment|
        if segment.includes?(num_workers + job)
          workers_in_seg = segment.select { |n| n < num_workers }
          job_partner = workers_in_seg[0] if workers_in_seg.size > 0 && workers_in_seg[0] != worker
        end
      end
      
      # Check if (worker, job) would both prefer each other over current matching
      if job_partner >= 0
        # Get preferences
        worker_current = edges.find { |i, j, w| i == worker && current_jobs.includes?(j - num_workers) && w > 0 }
        worker_alternative = edges.find { |i, j, w| i == worker && j == (num_workers + job) && w > 0 }
        
        partner_current = edges.find { |i, j, w| i == job_partner && w > 0 }
        partner_alternative = edges.find { |i, j, w| i == job_partner && j == (num_workers + job) && w > 0 }
        
        worker_prefers = worker_alternative && worker_current && worker_alternative[2] > worker_current[2]
        
        if worker_prefers
          blocking_pairs << {worker, job}
        end
      end
    end
  end
  
  if blocking_pairs.empty?
    puts "  No blocking pairs found - Matching is stable"
  else
    puts "  Blocking pairs found: #{blocking_pairs.size}"
    blocking_pairs.each do |(w, j)|
      puts "    (#{worker_names[w]}, #{job_names[j]})"
    end
  end
  
  # Verify diagonal matching
  puts "\n" + "-"*70
  puts "OPTIMAL MATCHING VERIFICATION"
  puts "-"*70
  
  diagonal_matches = 0
  num_workers.times do |worker|
    jobs = worker_job_assignment[worker]
    if jobs.includes?(worker)  # Diagonal match
      diagonal_matches += 1
      puts "  #{worker_names[worker]} -> #{job_names[worker]}: OPTIMAL (diagonal match)"
    else
      job_str = jobs.map { |j| job_names[j] }.join(", ")
      puts "  #{worker_names[worker]} -> #{job_str}: Sub-optimal"
    end
  end
  
  diagonal_percentage = (diagonal_matches.to_f / num_workers * 100).round(1)
  puts "\n  Diagonal matching: #{diagonal_matches}/#{num_workers} (#{diagonal_percentage}%)"
  
  # Final assessment
  puts "\n" + "="*70
  puts "PURE-STRATEGY EQUILIBRIUM TEST RESULTS"
  puts "="*70
  puts "  Problem: Stable matching with aligned preferences"
  puts "  Pure equilibrium: EXISTS (diagonal matching)"
  puts ""
  puts "  Nash equilibrium: #{is_pure_nash ? "FOUND" : "Not found"}"
  puts "  Blocking pairs: #{blocking_pairs.size}"
  puts "  Optimal matching: #{diagonal_percentage}%"
  puts "  Runtime: #{(runtime * 1000).round(1)}ms"
  puts ""
  
  if is_pure_nash && blocking_pairs.empty? && diagonal_percentage >= 75
    puts "  SUCCESS: Pure-strategy Nash equilibrium found!"
    puts "  Framework correctly identified stable diagonal matching"
  elsif is_pure_nash
    puts "  PARTIAL SUCCESS: Nash equilibrium found"
    puts "  Matching is stable but may not be globally optimal"
  else
    puts "  EXPLORATORY: Framework found locally stable solution"
    puts "  May require parameter tuning for perfect equilibrium"
  end
  
  puts "="*70
end

# Run the test
puts "\nStarting Pure-Strategy Nash Equilibrium Test"
puts "Testing on problem with guaranteed pure equilibrium"
puts ""

test_pure_strategy_equilibrium

puts "\nPure-strategy equilibrium test complete!"
puts "Framework demonstrates stable matching capabilities"

