# adversarial_test.cr
# Hard adversarial benchmark for malloc (Multiplicative Allocation Over Constraints)
# WARNING: heavy by default (N=50_000, ~1M edges). Lower N for faster runs.

require "./src/multiplicative_constraint"  # adapt path if your main file differs
require "random"

# ----- PARAMETERS (tune these if your machine can't handle defaults) -----
N = 2_000                 # number of nodes (reduce to 20_000 or 10_000 to be lighter)
K = 6                     # number of regions
EDGES_PER_NODE = 10       # average edges per node (controls sparsity)
NUM_CLIQUES = 40          # number of "requires" cliques (strong co-location groups)
CLIQUE_SIZE = 12          # size of each clique (complete requires inside)
NUM_CONFLICT_PAIRS = 3_000   # pairwise conflicts (anti-affinity)
PINNED_PCT = 0.02         # percent nodes pinned to a fixed region (2%)
SEED = 123456
RANDOM = Random.new(SEED)
ITERATIONS = 1000
RESTARTS = 2

puts "ADVERSARIAL TEST: N=#{N}, K=#{K}, edges/node≈#{EDGES_PER_NODE}"
puts "Cliques: #{NUM_CLIQUES}×#{CLIQUE_SIZE}, Conflicts: #{NUM_CONFLICT_PAIRS}, Pinned: #{(PINNED_PCT*100).round(2)}%"

# ----- Helper generators -----
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

# Deterministic-ish weights: primes scaled (good spectral variety)
weights = primes_sieve(N).map(&.to_f64)

# Build sparse locality graph: for each node, connect to EDGES_PER_NODE nearest by weight + a few random long-range edges
edges = [] of {Int32, Int32, Float64}
index_by_weight = (0...N).to_a.sort_by { |i| weights[i] }

# map index -> position in sorted list for k-nearest by weight
pos = Array.new(N, 0)
index_by_weight.each_with_index do |id, idx|
  pos[id] = idx
end

(0...N).each do |i|
  p = pos[i]
  # connect to nearest neighbors in sorted order (locality)
  left = [0, p - (EDGES_PER_NODE // 2)].max
  right = [N - 1, p + (EDGES_PER_NODE // 2)].min
  (left..right).each do |q|
    j = index_by_weight[q]
    next if j == i
    gap = (weights[j] - weights[i]).abs
    w = 1.0 / (1.0 + gap)
    edges << {i, j, w}
  end
  # a few long-range random edges
  2.times do
    j = RANDOM.rand(N)
    next if j == i
    gap = (weights[j] - weights[i]).abs
    w = 0.3 / (1.0 + gap)  # weaker
    edges << {i, j, w}
  end
end

# deduplicate edges (treat as undirected): keep one entry per unordered pair summing weights
edge_map = Hash(Tuple(Int32, Int32), Float64).new
edges.each do |e|
  a, b, w = e
  key = a < b ? {a, b} : {b, a}
  edge_map[key] = (edge_map[key]? || 0.0) + w
end
edges = edge_map.map { |(a,b), w| {a, b, w} }

puts "Edges (after dedupe): #{edges.size}"

# ----- Build resources and constraints -----
resources = (0...N).map do |i|
  # heterogeneous compute/cost properties
  type = ["web", "api", "db", "cache", "batch"][i % 5]
  cpu_hours = 100.0 + (i * 17) % 500
  monthly_cost = 50.0 + (i * 23) % 200
  MultiplicativeConstraint::Resource.new("vm-#{i}", type, cpu_hours, monthly_cost)
end.to_a

constraints = [] of MultiplicativeConstraint::ConstraintRelation

# 1) Add many "requires" cliques (complete co-location inside each clique)
clique_nodes = [] of Array(Int32)
NUM_CLIQUES.times do |c|
  base = (c * (N // NUM_CLIQUES)) % N
  # choose clique members pseudo-random but deterministic-ish
  members = (0...CLIQUE_SIZE).map { |j| ((base + j * 7) % N).to_i }.uniq
  clique_nodes << members
  (0...members.size).each do |i|
    ((i+1)...members.size).each do |j|
      a = members[i]
      b = members[j]
      constraints << MultiplicativeConstraint::ConstraintRelation.new(a.to_s, b.to_s, 1.0, "requires")
    end
  end
end

# 2) Add many random conflict pairs (anti-affinity); include some that directly contradict requires -> induces unsat pressure
NUM_CONFLICT_PAIRS.times do |i|
  a = RANDOM.rand(N)
  b = RANDOM.rand(N)
  next if a == b
  constraints << MultiplicativeConstraint::ConstraintRelation.new(a.to_s, b.to_s, 1.0, "conflicts")
end

# 3) Add cross-clique conflicts to force contradictions (heavy adversarial)
(0...(NUM_CLIQUES // 4)).each do |i|
  c1 = clique_nodes[i]
  c2 = clique_nodes[(i + NUM_CLIQUES // 2) % NUM_CLIQUES]
  # pick representative members and conflict them
  a = c1.first
  b = c2.first
  constraints << MultiplicativeConstraint::ConstraintRelation.new(a.to_s, b.to_s, 1.0, "conflicts")
end

# 4) Pinned nodes: 2% pinned to random regions (simulate immovable VMs)
pinned = {} of Int32 => Int32
pinned_pct = (N * PINNED_PCT).to_i
pinned_pct.times do
  i = RANDOM.rand(N)
  r = RANDOM.rand(K)
  pinned[i] = r
  # model pinned as an enforced requires to a pseudo "pinned region" marker (we'll pass pinned map to evaluation)
end

puts "Constraints total: #{constraints.size}, pinned: #{pinned.size}"

# 5) Region capacities (skewed): some regions tiny, some large
region_capacities = Array.new(K, 0.0)
base = (N.to_f / K).to_i
(0...K).each do |r|
  # skew: region 0 is tiny, region 1 large, rest vary
  skew = case r
         when 0 then 0.5
         when 1 then 1.5
         else 1.0 + (RANDOM.rand * 0.5 - 0.25)
         end
  region_capacities[r] = (base * skew).to_f
end

puts "Region capacities: #{region_capacities.inspect}"

# ----- Build graph and run multi-restart optimization -----
start_total = Time.monotonic
# Use sparse graph construction to handle large N efficiently
puts "Building sparse graph..."
edge_tuples = edges.map { |e| {e[0].to_i32, e[1].to_i32, e[2]} }
graph = MultiplicativeConstraint::Graph.from_edges(weights, edge_tuples)

best = nil
best_score = Float64::INFINITY
runs = RESTARTS

runs.times do |r|
  seed = SEED + r * 1000
  puts "Run #{r+1}/#{runs} seed=#{seed}..."
  engine = MultiplicativeConstraint::Engine.new(graph, K)
  result = engine.solve(iterations: ITERATIONS, step: 0.35, seed: seed)

  # Evaluate result
  # compute satisfaction counts
  satisfied = 0
  unsatisfied_list = [] of MultiplicativeConstraint::ConstraintRelation
  constraints.each do |c|
    from_seg = result.segments.index { |seg| seg.includes?(c.from_id.to_i) }
    to_seg = result.segments.index { |seg| seg.includes?(c.to_id.to_i) }
    next unless from_seg && to_seg
    ok = case c.type
         when "requires" then from_seg == to_seg
         when "conflicts" then from_seg != to_seg
         else false
         end
    if ok
      satisfied += 1
    else
      unsatisfied_list << c
    end
  end

  satisfaction_pct = satisfied.to_f / constraints.size * 100.0

  # capacity violations
  sizes = result.segments.map(&.size)
  overloads = sizes.each_with_index.map do |sz, idx|
    over = sz - region_capacities[idx]
    over > 0 ? over : 0
  end
  total_overload = overloads.sum(0.0)

  # pinned violations
  pinned_violations = 0
  pinned.each do |node, region|
    node_seg = result.segments.index { |seg| seg.includes?(node) }
    pinned_violations += 1 if node_seg != region
  end

  # imbalance metric
  target = N.to_f / K
  imbalance = sizes.map { |s| (s - target).abs }.sum(0.0)

  # score composite (weighted)
  score = (100.0 - satisfaction_pct) * 1000.0 + total_overload * 10.0 + pinned_violations * 500.0 + imbalance * 1.0

  puts "  satisfaction: #{satisfaction_pct.round(2)}% unsat=#{unsatisfied_list.size}"
  puts "  overload_total: #{total_overload.round(1)} pinned_violations: #{pinned_violations}"
  puts "  imbalance: #{imbalance.round(1)} score: #{score.round(1)}"

  if score < best_score
    best_score = score
    best = { result: result, satisfaction: satisfaction_pct, unsat: unsatisfied_list, overload: total_overload, pinned_violations: pinned_violations, imbalance: imbalance }
  end
end

total_time = (Time.monotonic - start_total).total_seconds.round(2)

# ----- Final report -----
puts "=" * 80
puts "ADVERSARIAL TEST REPORT"
puts "=" * 80
puts "N=#{N} K=#{K} edges=#{edges.size} constraints=#{constraints.size}"

if best
  puts "Best satisfaction: #{best[:satisfaction].round(2)}%  (lower is worse)"
  puts "Best overload total: #{best[:overload]}"
  puts "Pinned violations: #{best[:pinned_violations]}"
  puts "Imbalance: #{best[:imbalance]}"
  puts "Best composite score: #{best_score.round(1)}"
  puts "Total harness time: #{total_time}s"
  puts "Unsatisfied sample (up to 20):"
  best[:unsat].first(20).each do |c|
    puts "  #{c.type}: #{c.from_id} <-> #{c.to_id}"
  end
else
  puts "ERROR: No successful runs completed"
end
puts "=" * 80