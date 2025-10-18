require "../../src/multiplicative_constraint"

puts "🔥 INSANITY TEST: Quantum Physics vs Contradictory Logic"
puts "=" * 60

# Create a problem that should break spectral methods:
# 1. Impossible constraints (paradoxical requirements)
# 2. Local vs global optimization conflict
# 3. Number theory constraints that contradict spectral efficiency

# THE PARADOXICAL PROBLEM:
# - Want items with similar primes grouped together (local)
# - But also want perfect alternating prime/composite pattern (global)
# - These requirements are mathematically contradictory

weights = [] of Float64
names = [] of String

# Create 20 items with conflicting constraints
(1..20).each do |i|
  names << "Item#{i}"

  # Weights designed to create spectral chaos
  # Prime-indexed items get prime weights
  # Composite-indexed items get composite weights
  if [2, 3, 5, 7, 11, 13, 17, 19].includes?(i)
    weights << (2.0 + i * 1.618)  # Golden ratio + prime
  else
    weights << (Math.sqrt(i) * Math::PI)  # Irrational for composites
  end
end

# Create adjacency matrix that creates spectral nightmares
adjacency = Array.new(20) { Array.new(20, 0.0) }

# Constraint 1: Create strong local clusters (good for spectral)
[[1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12], [13, 14, 15, 16], [17, 18, 19, 20]].each do |cluster|
  cluster.each do |i|
    cluster.each do |j|
      next if i == j
      adjacency[i-1][j-1] = 10.0  # Strong local connections
    end
  end
end

# Constraint 2: Add global alternating pattern (contradicts local clusters)
(1..19).each do |i|
  if i % 2 == 0  # Even indices should hate odd indices
    (1..20).each do |j|
      if j % 2 == 1  # Connect even to odd with negative weight
        adjacency[i-1][j-1] = -5.0  # Contradictory global constraint
      end
    end
  end
end

# Constraint 3: Prime-composite conflict (number theory vs spectral)
primes = [2, 3, 5, 7, 11, 13, 17, 19]
primes.each do |p|
  (1..20).each do |c|
    if c % p == 0 && c != p  # Composite numbers connected to their prime factors
      adjacency[p-1][c-1] = 7.0
      adjacency[c-1][p-1] = 7.0
    end
  end
end

puts "🎯 IMPOSSIBLE PROBLEM DESIGN:"
puts "  • 20 items with golden ratio/irrational weights"
puts "  • Local clusters want to group together"
puts "  • Global pattern wants perfect alternation"
puts "  • Prime factor constraints create number theory conflicts"
puts "  • These requirements are mathematically contradictory!"
puts

# Test on different numbers of segments to find the breaking point
[3, 4, 5, 7].each do |segments|
  puts "🔥 TESTING WITH #{segments} SEGMENTS:"
  puts "-" * 40

  begin
    graph = MultiplicativeConstraint::Graph.new(weights, adjacency)
    engine = MultiplicativeConstraint::Engine.new(graph, segments)

    start_time = Time.monotonic
    result = engine.solve(iterations: 1000, seed: 42)
    end_time = Time.monotonic

    runtime = ((end_time - start_time).total_milliseconds).round(1)

    puts "⚡ Runtime: #{runtime} ms"
    puts "📊 Final Energy: #{result.energy.round(3)}"
    puts "📊 Spectral Action: #{result.spectral.round(3)}"
    puts "📊 Multiplicative Penalty: #{result.penalty.round(6)}"
    puts "📊 Cross-Conflict: #{result.cross_conflict.round(3)}"

    puts "\n🎯 SEGMENT ANALYSIS:"
    result.segments.each_with_index do |segment, i|
      puts "  Segment #{i+1}: #{segment.size} items"
      segment.each do |item_idx|
        name = names[item_idx]
        weight = weights[item_idx]
        puts "    #{name} (weight: #{weight.round(3)})"
      end
    end

    # Check for contradictions in the solution
    puts "\n🔍 CONTRADICTION DETECTION:"

    # Check 1: Are local clusters broken?
    local_broken = false
    cluster_groups = [[1,2,3,4], [5,6,7,8], [9,10,11,12], [13,14,15,16], [17,18,19,20]]
    cluster_groups.each do |cluster|
      segments_for_cluster = cluster.map { |i| result.discrete_solution[i-1] }.uniq.size
      if segments_for_cluster > 2
        puts "  ❌ Local cluster broken: #{cluster} split into #{segments_for_cluster} segments"
        local_broken = true
      end
    end

    # Check 2: Is alternating pattern broken?
    alternating_broken = false
    even_segments = (2..20).step(2).map { |i| result.discrete_solution[i-1] }.uniq.size
    odd_segments = (1..19).step(2).map { |i| result.discrete_solution[i-1] }.uniq.size
    if even_segments > segments/2 || odd_segments > segments/2
      puts "  ❌ Alternating pattern broken: evens in #{even_segments} segments, odds in #{odd_segments}"
      alternating_broken = true
    end

    # Check 3: Are prime constraints violated?
    prime_violations = 0
    primes.each do |p|
      p_segment = result.discrete_solution[p-1]
      (1..20).each do |c|
        if c % p == 0 && c != p
          if result.discrete_solution[c-1] != p_segment
            prime_violations += 1
          end
        end
      end
    end
    if prime_violations > 0
      puts "  ❌ Prime constraints violated: #{prime_violations} violations"
    end

    # Final verdict
    puts "\n🏆 VERDICT:"
    if local_broken && alternating_broken && prime_violations > 0
      puts "  🤯 ALL CONSTRAINTS VIOLATED - Quantum physics failed!"
    elsif local_broken || alternating_broken || prime_violations > 0
      puts "  ⚠️  Some constraints violated - Framework struggling!"
    else
      puts "  ✅ Some miracle occurred - Quantum magic worked!"
    end

  rescue ex
    puts "  💥 CRASHED: #{ex.message}"
    puts "  🎯 Quantum physics surrendered to logic!"
  end

  puts "\n" + "=" * 60 + "\n"
end

puts "🎯 FINAL INSANITY TEST CONCLUSION:"
puts "If this framework can handle our contradictory constraints,"
puts "it might actually be as revolutionary as they claim!"
puts "If it breaks, we've found the limits of spectral-multiplicative optimization."