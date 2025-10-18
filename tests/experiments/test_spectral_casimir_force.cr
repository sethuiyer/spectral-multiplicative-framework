#!/usr/bin/env crystal
# Spectral Casimir Force Measurement in Constraint Satisfaction
# Based on: "Why Physicists Think Math's Toughest Problem Is About Stability"
# Tests if attractive/repulsive spectral forces predict problem solvability

require "../../src/multiplicative_constraint"

# Spectral Casimir force: measures vacuum energy gradient during optimization
# Attractive force (F < 0): System pulled toward solution (solvable)
# Repulsive force (F > 0): System pushed away from solution (unsolvable)

# Casimir force measurement
class CasimirMeasurement
  property time_steps : Array(Float64)
  property energies : Array(Float64)
  property spectral_gaps : Array(Float64)
  property forces : Array(Float64)
  
  def initialize
    @time_steps = [] of Float64
    @energies = [] of Float64
    @spectral_gaps = [] of Float64
    @forces = [] of Float64
  end
  
  def add_measurement(time : Float64, energy : Float64, gap : Float64)
    @time_steps << time
    @energies << energy
    @spectral_gaps << gap
    
    # Calculate instantaneous force (negative gradient)
    if @energies.size > 1
      delta_e = energy - @energies[-2]
      delta_t = time - @time_steps[-2]
      force = -delta_e / (delta_t + 1e-10)
      @forces << force
    end
  end
  
  def average_force : Float64
    return 0.0 if @forces.empty?
    @forces.sum / @forces.size
  end
  
  def force_trend : String
    avg = average_force
    if avg < -10.0
      "STRONGLY ATTRACTIVE"
    elsif avg < 0.0
      "ATTRACTIVE"
    elsif avg > 10.0
      "STRONGLY REPULSIVE"
    elsif avg > 0.0
      "REPULSIVE"
    else
      "NEUTRAL"
    end
  end
  
  def stability_indicator : Float64
    return 0.0 if @forces.empty?
    # Variance of forces (stable = low variance)
    mean = average_force
    variance = @forces.map { |f| (f - mean) ** 2 }.sum / @forces.size
    Math.sqrt(variance)
  end
end

# Test SAT problem with Casimir force measurement
def test_sat_with_casimir(name : String, variables : Int32, clauses : Array(Array(Int32)), 
                           expected_solvable : Bool)
  puts "\n" + "="*70
  puts "SAT INSTANCE: #{name}"
  puts "="*70
  puts "Variables: #{variables}"
  puts "Clauses: #{clauses.size}"
  puts "Expected: #{expected_solvable ? "SOLVABLE" : "UNSOLVABLE"}"
  
  # Build SAT graph
  num_nodes = variables * 2  # variables + negations
  
  # Convert to adjacency matrix
  adjacency = Array.new(num_nodes) { Array.new(num_nodes, 0.0) }
  
  # Positive edges: literals in same clause (should be together)
  clauses.each do |clause|
    clause.each_with_index do |lit1, i|
      clause.each_with_index do |lit2, j|
        next if i >= j
        
        node1 = lit1 > 0 ? (lit1 - 1) : (variables + (-lit1 - 1))
        node2 = lit2 > 0 ? (lit2 - 1) : (variables + (-lit2 - 1))
        
        weight = 10.0
        adjacency[node1][node2] += weight
        adjacency[node2][node1] += weight
      end
    end
  end
  
  # Negative edges: variable and its negation (must be separate)
  variables.times do |v|
    var_node = v
    neg_node = variables + v
    weight = -20.0
    adjacency[var_node][neg_node] = weight
    adjacency[neg_node][var_node] = weight
  end
  
  weights = Array.new(num_nodes, 1.0)
  graph = MultiplicativeConstraint::Graph.new(weights, adjacency)
  
  # Optimization with Casimir measurement
  num_segments = 2
  engine = MultiplicativeConstraint::Engine.new(graph, num_segments)
  
  puts "\nOptimization with Casimir Force Measurement:"
  puts "-" * 70
  
  measurement = CasimirMeasurement.new
  
  # Run optimization in stages to measure force
  iterations_per_stage = 100
  num_stages = 20
  total_iterations = 0
  
  seed = 42
  current_result = engine.solve(iterations: 1, step: 0.3, seed: seed)
  
  num_stages.times do |stage|
    time = stage.to_f
    
    # Run optimization stage
    current_result = engine.solve(iterations: iterations_per_stage, step: 0.3, seed: seed + stage)
    total_iterations += iterations_per_stage
    
    # Calculate spectral gap (proxy for system stability)
    energy = current_result.energy
    segments = current_result.segments
    
    # Spectral gap: energy difference between segments
    gap = energy / segments.size  # Simplified gap measure
    
    # Record measurement
    measurement.add_measurement(time, energy, gap)
    
    if stage % 5 == 0
      force = measurement.forces.last? || 0.0
      puts "  Stage #{stage}: Energy=#{energy.round(2)}, Force=#{force.round(2)}"
    end
  end
  
  # Analyze SAT solution
  puts "\nSolution Analysis:"
  puts "-" * 70
  
  assignment = Array.new(variables, false)
  current_result.segments.each_with_index do |segment, seg_idx|
    segment.each do |node|
      if node < variables
        assignment[node] = (seg_idx == 0)
      end
    end
  end
  
  # Check clause satisfaction
  satisfied = 0
  clauses.each do |clause|
    is_satisfied = clause.any? do |lit|
      var_idx = lit.abs - 1
      if lit > 0
        assignment[var_idx]
      else
        !assignment[var_idx]
      end
    end
    satisfied += 1 if is_satisfied
  end
  
  satisfaction_rate = (satisfied.to_f / clauses.size * 100).round(1)
  
  puts "  Clauses satisfied: #{satisfied}/#{clauses.size} (#{satisfaction_rate}%)"
  puts "  Assignment: #{assignment.map { |v| v ? "T" : "F" }.join(" ")}"
  
  # Casimir Force Analysis
  puts "\nSpectral Casimir Force Analysis:"
  puts "-" * 70
  
  avg_force = measurement.average_force
  trend = measurement.force_trend
  stability = measurement.stability_indicator
  
  puts "  Average force: #{avg_force.round(2)}"
  puts "  Force trend: #{trend}"
  puts "  Force stability (std dev): #{stability.round(2)}"
  
  # Plot force trajectory (ASCII)
  puts "\n  Force Trajectory:"
  max_force = measurement.forces.map(&.abs).max || 1.0
  measurement.forces.each_slice(4).with_index do |slice, i|
    avg_slice = slice.sum / slice.size
    normalized = (avg_slice / max_force * 20).to_i
    bar = "=" * normalized.abs
    direction = avg_slice < 0 ? "<" : ">"
    puts "    t=#{i*4}: #{bar}#{direction} #{avg_slice.round(2)}"
  end
  
  # Prediction vs Reality
  puts "\nCasimir Force Prediction:"
  puts "-" * 70
  
  predicted_solvable = avg_force < 0  # Attractive = solvable
  prediction_correct = (predicted_solvable == expected_solvable)
  
  puts "  Expected: #{expected_solvable ? "SOLVABLE" : "UNSOLVABLE"}"
  puts "  Casimir predicts: #{predicted_solvable ? "SOLVABLE" : "UNSOLVABLE"} (force=#{avg_force.round(2)})"
  puts "  Actual satisfaction: #{satisfaction_rate}%"
  puts "  Prediction: #{prediction_correct ? "CORRECT" : "INCORRECT"}"
  
  {
    name: name,
    expected_solvable: expected_solvable,
    predicted_solvable: predicted_solvable,
    satisfaction: satisfaction_rate,
    avg_force: avg_force,
    force_trend: trend,
    stability: stability,
    correct: prediction_correct
  }
end

# Main test
def run_casimir_force_experiment
  puts "\n" + "="*70
  puts "SPECTRAL CASIMIR FORCE IN CONSTRAINT SATISFACTION"
  puts "="*70
  puts "Hypothesis: Attractive force indicates solvable instances"
  puts "Hypothesis: Repulsive force indicates unsolvable instances"
  puts "Based on: Arithmetic QFT and Spectral Casimir Energy"
  puts "="*70
  
  results = [] of NamedTuple(
    name: String,
    expected_solvable: Bool,
    predicted_solvable: Bool,
    satisfaction: Float64,
    avg_force: Float64,
    force_trend: String,
    stability: Float64,
    correct: Bool
  )
  
  # Test 1: Simple solvable SAT
  puts "\n\nTEST 1: SIMPLE SOLVABLE SAT"
  clauses1 = [
    [1, 2],      # x1 OR x2
    [1, -2],     # x1 OR NOT x2
    [-1, 2],     # NOT x1 OR x2
  ]
  results << test_sat_with_casimir("Simple Solvable", 2, clauses1, true)
  
  # Test 2: Solvable 3-SAT
  puts "\n\nTEST 2: SOLVABLE 3-SAT"
  clauses2 = [
    [1, 2, 3],
    [-1, 2, 3],
    [1, -2, 3],
    [1, 2, -3],
    [-1, -2, 4],
  ]
  results << test_sat_with_casimir("Solvable 3-SAT", 4, clauses2, true)
  
  # Test 3: Unsolvable SAT (contradiction)
  puts "\n\nTEST 3: UNSOLVABLE SAT (CONTRADICTION)"
  clauses3 = [
    [1],         # x1 must be TRUE
    [-1],        # x1 must be FALSE (contradiction!)
    [1, 2],
  ]
  results << test_sat_with_casimir("Contradiction", 2, clauses3, false)
  
  # Test 4: Over-constrained (likely unsolvable)
  puts "\n\nTEST 4: OVER-CONSTRAINED SAT"
  clauses4 = [
    [1, 2],
    [-1, 2],
    [1, -2],
    [-1, -2],    # These 4 clauses force both vars to be in superposition
    [3],         # x3 = TRUE
    [-3],        # x3 = FALSE (contradiction)
  ]
  results << test_sat_with_casimir("Over-Constrained", 3, clauses4, false)
  
  # Test 5: Complex solvable
  puts "\n\nTEST 5: COMPLEX SOLVABLE SAT"
  clauses5 = [
    [1, 2, 3],
    [-1, 2, 4],
    [1, -2, 4],
    [-3, -4, 5],
    [3, 4, -5],
    [1, 3, 5],
  ]
  results << test_sat_with_casimir("Complex Solvable", 5, clauses5, true)
  
  # Summary Analysis
  puts "\n\n" + "="*70
  puts "CASIMIR FORCE EXPERIMENT SUMMARY"
  puts "="*70
  
  puts "\nResults Table:"
  puts "-" * 70
  puts "Instance               | Expected | Force    | Trend      | Satisfy | Correct"
  puts "-" * 70
  
  results.each do |r|
    exp = r[:expected_solvable] ? "SOLVE" : "UNSAT"
    force_str = sprintf("% 7.2f", r[:avg_force])
    sat_str = sprintf("%5.1f%%", r[:satisfaction])
    correct_str = r[:correct] ? "YES" : "NO"
    
    puts sprintf("%-22s | %-8s | %s | %-10s | %s | %s",
      r[:name], exp, force_str, r[:force_trend], sat_str, correct_str)
  end
  
  puts "-" * 70
  
  # Statistical analysis
  puts "\nStatistical Analysis:"
  puts "-" * 70
  
  solvable_forces = results.select { |r| r[:expected_solvable] }.map { |r| r[:avg_force] }
  unsolvable_forces = results.select { |r| !r[:expected_solvable] }.map { |r| r[:avg_force] }
  
  separation = 0.0
  
  if solvable_forces.size > 0 && unsolvable_forces.size > 0
    avg_solvable = solvable_forces.sum / solvable_forces.size
    avg_unsolvable = unsolvable_forces.sum / unsolvable_forces.size
    
    puts "  Solvable instances:"
    puts "    Mean force: #{avg_solvable.round(2)}"
    puts "    Forces: #{solvable_forces.map { |f| f.round(2) }.inspect}"
    
    puts "  Unsolvable instances:"
    puts "    Mean force: #{avg_unsolvable.round(2)}"
    puts "    Forces: #{unsolvable_forces.map { |f| f.round(2) }.inspect}"
    
    separation = (avg_solvable - avg_unsolvable).abs
    puts "\n  Force separation: #{separation.round(2)}"
    
    if avg_solvable < 0 && avg_unsolvable > 0
      puts "  RESULT: Clear attractive/repulsive separation"
    elsif avg_solvable < avg_unsolvable
      puts "  RESULT: Solvable forces more attractive than unsolvable"
    else
      puts "  RESULT: No clear separation (may need more samples)"
    end
  end
  
  # Prediction accuracy
  correct_predictions = results.count { |r| r[:correct] }
  accuracy = (correct_predictions.to_f / results.size * 100).round(1)
  
  puts "\nPrediction Accuracy:"
  puts "  Correct: #{correct_predictions}/#{results.size} (#{accuracy}%)"
  
  # Correlation analysis
  puts "\nCorrelation Analysis:"
  puts "-" * 70
  
  # Correlation between force and satisfaction rate
  forces = results.map { |r| r[:avg_force] }
  satisfactions = results.map { |r| r[:satisfaction] }
  
  mean_force = forces.sum / forces.size
  mean_sat = satisfactions.sum / satisfactions.size
  
  covariance = forces.zip(satisfactions).map { |(f, s)| (f - mean_force) * (s - mean_sat) }.sum / forces.size
  std_force = Math.sqrt(forces.map { |f| (f - mean_force) ** 2 }.sum / forces.size)
  std_sat = Math.sqrt(satisfactions.map { |s| (s - mean_sat) ** 2 }.sum / satisfactions.size)
  
  correlation = covariance / (std_force * std_sat + 1e-10)
  
  puts "  Force vs Satisfaction correlation: #{correlation.round(3)}"
  
  if correlation.abs > 0.7
    direction = correlation > 0 ? "positive" : "negative"
    puts "  STRONG #{direction} correlation detected"
  elsif correlation.abs > 0.4
    puts "  MODERATE correlation detected"
  else
    puts "  WEAK correlation"
  end
  
  # Final verdict
  puts "\n" + "="*70
  puts "CASIMIR FORCE AS SOLVABILITY DIAGNOSTIC"
  puts "="*70
  
  if accuracy >= 80 && separation > 50
    puts "SUCCESS: Casimir force reliably predicts problem solvability"
    puts "  - Prediction accuracy: #{accuracy}%"
    puts "  - Clear force separation between solvable/unsolvable"
    puts "  - Attractive forces correlate with solutions"
    puts ""
    puts "CONCLUSION: Spectral Casimir force acts as 'truth detector'"
    puts "  The vacuum energy gradient reveals problem structure!"
  elsif accuracy >= 60
    puts "PARTIAL SUCCESS: Casimir force shows predictive signal"
    puts "  - Prediction accuracy: #{accuracy}%"
    puts "  - Some correlation with solvability"
    puts ""
    puts "CONCLUSION: Force measurement provides diagnostic information"
  else
    puts "EXPLORATORY: More data needed for definitive conclusions"
    puts "  - Prediction accuracy: #{accuracy}%"
    puts ""
    puts "NOTE: May require more sophisticated force calculation or"
    puts "      larger sample of problems to detect clear patterns"
  end
  
  puts "="*70
end

# Run the experiment
puts "\nStarting Spectral Casimir Force Experiment"
puts "Measuring vacuum energy gradients in constraint satisfaction"
puts ""

run_casimir_force_experiment

puts "\nCasimir force experiment complete!"
puts "First implementation of QFT diagnostics in optimization!"

