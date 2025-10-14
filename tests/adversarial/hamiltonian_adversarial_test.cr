# hamiltonian_adversarial_test.cr
# Test malloc on a Hamiltonian cycle problem designed to break partitioning approaches
# This creates a graph where the only good solution is a specific ordering, not partitioning

require "./src/multiplicative_constraint"
require "random"

# ----- PARAMETERS -----
N = 100                 # number of nodes
K = 6                   # number of regions (malloc will partition into K segments)
W_GOOD = 1000.0          # strong edge weight for correct Hamiltonian edges
W_BAD = 0.001            # tiny edge weight for all other edges
SEED = 999999
RANDOM = Random.new(SEED)
ITERATIONS = 2000

puts "HAMILTONIAN ADVERSARIAL TEST: N=#{N}, K=#{K}"
puts "Goal: Force malloc to find a specific ordering (π permutation)"
puts "Strong edges for Hamiltonian cycle: #{W_GOOD}, other edges: #{W_BAD}"

# ----- Helper functions -----
def random_permutation(n)
  (0...n).to_a.shuffle(random: Random.new(SEED))
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

# ----- Create the adversarial graph -----
# Target permutation (ground truth Hamiltonian cycle)
target_permutation = random_permutation(N)
puts "Target permutation: #{target_permutation.first(10)}...#{target_permutation.last(10)}"

# Create weights using primes (good for spectral variety)
weights = primes_sieve(N).map(&.to_f64)

# Create adjacency matrix with mostly tiny edges, strong edges only for Hamiltonian cycle
adjacency = Array.new(N) { Array.new(N, W_BAD) }

# Add strong edges for the Hamiltonian cycle
(0...N).each do |i|
  u = target_permutation[i]
  v = target_permutation[(i + 1) % N]  # wrap around for cycle
  adjacency[u][v] = W_GOOD
  adjacency[v][u] = W_GOOD
end

# Add some distractor cliques to mislead spectral methods
# These create strong community signals but don't align with Hamiltonian order
NUM_CLIQUE_GROUPS = 5
CLIQUE_SIZE = 15

(0...N).to_a.shuffle(random: Random.new(SEED + 1000))[0...(NUM_CLIQUE_GROUPS * CLIQUE_SIZE)].each_slice(CLIQUE_SIZE) do |clique_members|
  # Make clique members strongly connected to each other
  clique_members.each do |i|
    clique_members.each do |j|
      next if i == j
      adjacency[i][j] = 50.0
      adjacency[j][i] = 50.0
    end
  end
end

puts "Added #{NUM_CLIQUE_GROUPS} distractor cliques of size #{CLIQUE_SIZE}"

# Count Hamiltonian edges vs distractor edges
hamiltonian_edges = 0
distractor_edges = 0

(0...N).each do |i|
  (i+1...N).each do |j|
    w = adjacency[i][j]
    if w == W_GOOD
      hamiltonian_edges += 1
    elsif w > 1.0
      distractor_edges += 1
    end
  end
end

puts "Hamiltonian edges: #{hamiltonian_edges}, Distractor edges: #{distractor_edges}"

# ----- Run malloc on this adversarial graph -----
start_time = Time.monotonic
graph = MultiplicativeConstraint::Graph.new(weights, adjacency)
engine = MultiplicativeConstraint::Engine.new(graph, K)
result = engine.solve(iterations: ITERATIONS, step: 0.35, seed: SEED)
runtime = (Time.monotonic - start_time).total_seconds

# ----- Analyze results -----
puts "\n" + "=" * 80
puts "HAMILTONIAN ADVERSARIAL TEST RESULTS"
puts "=" * 80

puts "Target Hamiltonian cycle cost: #{N * W_GOOD} (#{N} strong edges)"
puts "malloc segments found: #{result.segments.size}"

# Count Hamiltonian edges preserved in malloc's partitioning
hamiltonian_preserved = 0
hamiltonian_violated = 0

(0...N).each do |i|
  u = target_permutation[i]
  v = target_permutation[(i + 1) % N]

  # Check if these consecutive nodes are in the same segment
  u_seg = result.segments.index { |seg| seg.includes?(u) }
  v_seg = result.segments.index { |seg| seg.includes?(v) }

  if u_seg && v_seg && u_seg == v_seg
    hamiltonian_preserved += 1
  else
    hamiltonian_violated += 1
  end
end

# Calculate how malloc would perform if we try to construct a tour from its segments
malloc_tour_cost = 0.0
malloc_segments = result.segments

# More realistic tour construction: must follow segment boundaries
# This is where partitioning fails - we lose the ordering within/between segments
malloc_order = [] of Int32
malloc_segments.each do |segment|
  # Sort segments by some heuristic (here: by first node to be deterministic)
  sorted_segment = segment.sort
  malloc_order.concat(sorted_segment)
end

# Calculate tour cost for malloc's ordering
(0...(malloc_order.size - 1)).each do |i|
  u = malloc_order[i]
  v = malloc_order[(i + 1) % malloc_order.size]
  malloc_tour_cost += adjacency[u][v]
end

# Add penalty for crossing segment boundaries (this is the real cost of partitioning)
segment_crossings = 0
(0...(malloc_order.size - 1)).each do |i|
  u = malloc_order[i]
  v = malloc_order[(i + 1) % malloc_order.size]
  u_seg = result.segments.index { |seg| seg.includes?(u) }
  v_seg = result.segments.index { |seg| seg.includes?(v) }
  segment_crossings += 1 if u_seg && v_seg && u_seg != v_seg
end

# Apply heavy penalty for segment crossings (realistic cost)
segment_crossing_penalty = segment_crossings * W_GOOD * 10  # Heavy penalty
malloc_tour_cost += segment_crossing_penalty

# Calculate ideal tour cost
ideal_tour_cost = 0.0
(0...N).each do |i|
  u = target_permutation[i]
  v = target_permutation[(i + 1) % N]
  ideal_tour_cost += adjacency[u][v]
end

puts "\nTour Cost Analysis:"
puts "  Ideal tour cost (target permutation): #{ideal_tour_cost}"
puts "  malloc derived tour cost: #{malloc_tour_cost.round(2)}"
puts "  Cost ratio (malloc/ideal): #{(malloc_tour_cost / ideal_tour_cost).round(2)}x"
puts "  Segment crossings: #{segment_crossings} (penalty: #{segment_crossing_penalty})"

puts "\nHamiltonian Edge Preservation:"
puts "  Hamiltonian edges preserved: #{hamiltonian_preserved}/#{N} (#{(hamiltonian_preserved.to_f64 / N * 100).round(2)}%)"
puts "  Hamiltonian edges violated: #{hamiltonian_violated}/#{N} (#{(hamiltonian_violated.to_f64 / N * 100).round(2)}%)"

puts "\nSegment Analysis:"
malloc_segments.each_with_index do |segment, idx|
  puts "  Segment #{idx + 1}: #{segment.size} nodes, first: #{segment.first}, last: #{segment.last}"
end

puts "\nEngine Performance:"
puts "  Runtime: #{runtime.round(2)}s"
puts "  Unified energy: #{result.energy.round(2)}"
puts "  Spectral action: #{result.spectral.round(2)}"

# Success criteria for malloc on Hamiltonian problems:
puts "\n" + "=" * 80
puts "SUCCESS CRITERIA ANALYSIS"
puts "=" * 80

if hamiltonian_preserved >= N * 0.8
  puts "✅ EXCELLENT: malloc preserved #{(hamiltonian_preserved.to_f64 / N * 100).round(2)}% of Hamiltonian edges"
  puts "   (Unexpected: partitioning approach found the ordering!)"
elsif hamiltonian_preserved >= N * 0.5
  puts "⚠️  MODERATE: malloc preserved #{(hamiltonian_preserved.to_f64 / N * 100).round(2)}% of Hamiltonian edges"
  puts "   (Some ordering captured, but not complete)"
else
  puts "❌ FAILED: malloc only preserved #{(hamiltonian_preserved.to_f64 / N * 100).round(2)}% of Hamiltonian edges"
  puts "   (Expected: partitioning approach cannot capture ordering)"
end

cost_ratio = malloc_tour_cost / ideal_tour_cost
if cost_ratio <= 1.1
  puts "✅ EXCELLENT: malloc tour cost is within 10% of optimal"
  puts "   (Unexpected: partitioning found near-optimal ordering!)"
elsif cost_ratio <= 2.0
  puts "⚠️  MODERATE: malloc tour cost is #{cost_ratio.round(2)}x optimal"
  puts "   (Some ordering captured, but substantial degradation)"
else
  puts "❌ FAILED: malloc tour cost is #{cost_ratio.round(2)}x optimal"
  puts "   (Expected: partitioning approach cannot capture ordering)"
end

puts "\nCONCLUSION:"
puts "This test validates that malloc is designed for partitioning problems, not ordering problems."
puts "The poor performance on Hamiltonian cycles demonstrates the architectural limitations"
puts "and helps define the appropriate problem domain for the malloc engine."
puts "=" * 80