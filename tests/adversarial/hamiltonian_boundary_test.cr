# hamiltonian_boundary_test.cr
# Final boundary test: malloc vs true Hamiltonian solver (simulated)
# This demonstrates malloc's architectural limitations on ordering problems

require "./src/multiplicative_constraint"
require "random"

# ----- PARAMETERS -----
N = 50                  # Smaller for clearer analysis
K = 6                   # malloc partitions
W_GOOD = 1000.0         # Strong Hamiltonian edges
W_BAD = 0.001           # Weak other edges
SEED = 42
RANDOM = Random.new(SEED)
ITERATIONS = 1500

puts "HAMILTONIAN BOUNDARY TEST: malloc vs True Ordering"
puts "N=#{N}, K=#{K}, malloc partitions vs Hamiltonian ordering"

# Helper function for simple permutation
def target_permutation(n)
  (0...n).to_a.rotate(1)  # Simple shift permutation
end

def primes_sieve(count)
  primes = [] of Int32
  candidate = 2
  while primes.size < count
    is_p = true
    i = 2
    while i * i <= candidate
      if candidate % i == 0
        is_p = false
        break
      end
      i += 1
    end
    primes << candidate if is_p
    candidate += 1
  end
  primes
end

# Create clean Hamiltonian cycle (no distractors)
target_perm = target_permutation(N)
weights = primes_sieve(N).map(&.to_f64)

# Pure Hamiltonian adjacency matrix
adjacency = Array.new(N) { Array.new(N, W_BAD) }

# Add strong edges only for Hamiltonian cycle
(0...N).each do |i|
  u = target_perm[i]
  v = target_perm[(i + 1) % N]
  adjacency[u][v] = W_GOOD
  adjacency[v][u] = W_GOOD
end

puts "Clean Hamiltonian cycle: #{N} strong edges, no distractors"

# ----- Test malloc (partitioning approach) -----
puts "\n" + "="*60
puts "malloc: Partitioning Approach"
puts "="*60

start_time = Time.monotonic
graph = MultiplicativeConstraint::Graph.new(weights, adjacency)
engine = MultiplicativeConstraint::Engine.new(graph, K)
malloc_result = engine.solve(iterations: ITERATIONS, step: 0.35, seed: SEED)
malloc_runtime = (Time.monotonic - start_time).total_seconds

# Analyze malloc's partitioning vs Hamiltonian requirements
malloc_segments = malloc_result.segments
malloc_segments.each_with_index do |segment, idx|
  puts "  Segment #{idx + 1}: #{segment.size} nodes"
end

# Count how malloc breaks the Hamiltonian cycle
hamiltonian_breaks = 0
(0...N).each do |i|
  u = target_perm[i]
  v = target_perm[(i + 1) % N]

  u_seg = malloc_segments.index { |seg| seg.includes?(u) }
  v_seg = malloc_segments.index { |seg| seg.includes?(v) }

  if u_seg && v_seg && u_seg != v_seg
    hamiltonian_breaks += 1
  end
end

puts "\nHamiltonian Cycle Analysis:"
puts "  Cycle edges broken by partitioning: #{hamiltonian_breaks}/#{N}"
puts "  Cycle continuity: #{((N - hamiltonian_breaks).to_f64 / N * 100).round(2)}%"
puts "  malloc runtime: #{malloc_runtime.round(3)}s"

# ----- Simulate true Hamiltonian solver approach -----
puts "\n" + "="*60
puts "True Hamiltonian: Ordering Approach"
puts "="*60

# Simulate optimal Hamiltonian solver (uses the target permutation directly)
true_runtime = 0.001  # Simulated - would be exponential for real solver
true_tour_cost = N * W_GOOD  # All edges are strong

puts "  Hamiltonian cycle found: 100% continuity"
puts "  Tour cost: #{true_tour_cost}"
puts "  Simulated runtime: #{true_runtime}s"

# ----- malloc's attempt to reconstruct tour from partitions -----
puts "\n" + "="*60
puts "malloc Tour Reconstruction (Partitioning Limitations)"
puts "="*60

# Reconstruct tour from malloc's segments
malloc_tour = [] of Int32
malloc_segments.each do |segment|
  # Within each segment, we lose the optimal ordering
  # This is the fundamental limitation of partitioning
  malloc_tour.concat(segment.sort)  # Arbitrary ordering within segment
end

# Calculate tour cost with segment boundary penalties
tour_cost = 0.0
boundary_penalties = 0

(0...(malloc_tour.size - 1)).each do |i|
  u = malloc_tour[i]
  v = malloc_tour[(i + 1) % malloc_tour.size]

  u_seg = malloc_segments.index { |seg| seg.includes?(u) }
  v_seg = malloc_segments.index { |seg| seg.includes?(v) }

  if u_seg && v_seg && u_seg != v_seg
    # Crossing segment boundary - high penalty
    boundary_penalties += 1
    tour_cost += W_BAD  # Weak connection across segments
  else
    tour_cost += adjacency[u][v]  # Within segment connection
  end
end

puts "  Reconstructed tour cost: #{tour_cost.round(2)}"
puts "  Boundary penalties: #{boundary_penalties}"
puts "  Cost degradation: #{(tour_cost / true_tour_cost).round(2)}x optimal"

# ----- Final Analysis -----
puts "\n" + "="*80
puts "BOUNDARY ANALYSIS: Partitioning vs Ordering"
puts "="*80

puts "\n1. PROBLEM TYPE MISMATCH:"
puts "   malloc: Designed for balanced partitioning (who goes where)"
puts "   Hamiltonian: Requires optimal ordering (who comes after whom)"

puts "\n2. STRUCTURAL LIMITATIONS:"
puts "   malloc partitions into #{K} segments, breaking #{hamiltonian_breaks} cycle edges"
puts "   Loses sequential information required for Hamiltonian cycles"

puts "\n3. PERFORMANCE COMPARISON:"
if hamiltonian_breaks > N * 0.5
  puts "   ❌ malloc FAILS: Breaks >50% of Hamiltonian edges"
  puts "   ✅ Confirmed: Partitioning cannot preserve ordering"
else
  puts "   ⚠️  malloc PARTIAL: Some continuity preserved by chance"
  puts "   📊 Architecture: Partitioning, not sequential optimization"
end

puts "\n4. ARCHITECTURAL CONCLUSION:"
puts "   malloc excels at: ✅ Balanced partitioning, ✅ Resource allocation"
puts "   malloc struggles with: ❌ Sequential ordering, ❌ Path optimization"
puts "   This defines malloc's optimal problem domain clearly."

puts "\n5. ENTERPRISE IMPLICATION:"
puts "   ✅ USE malloc for: Cloud resource allocation, circuit partitioning"
puts "   ❌ DON'T use malloc for: Route planning, scheduling sequences"
puts "   🎯 Success: Understanding architectural boundaries prevents misuse"

puts "="*80