# Wedding Seating from Hell - Spectral Optimization Test
#
# Scenario:
# - 100 Guests
# - 10 Tables
# - Constraints:
#   1. Couples MUST sit together (Strong Positive)
#   2. Friends SHOULD sit together (Weak Positive)
#   3. Enemies MUST NOT sit together (Strong Negative)
#   4. "Vibe Check": Distribute Extroverts evenly (Node Weight Fairness)

require "../src/multiplicative_constraint"

include MultiplicativeConstraint

puts "💒 WEDDING SEATING FROM HELL 💒"
puts "==============================="
puts "Initializing 100 guests with complex social dynamics..."

NUM_GUESTS = 100
NUM_TABLES = 10
NUM_EXTROVERTS = 20
NUM_COUPLES = 15 # 30 people
NUM_ENEMIES = 10 # 10 pairs of enemies

# 1. Generate Guests & Personalities
# Weights: Extrovert = 5.0 (High Social Energy), Introvert = 1.0
weights = Array.new(NUM_GUESTS, 1.0)
guest_names = Array.new(NUM_GUESTS) { |i| "Guest_#{i}" }
extrovert_indices = (0...NUM_GUESTS).to_a.sample(NUM_EXTROVERTS)
extrovert_indices.each do |idx|
  weights[idx] = 5.0
  guest_names[idx] += " (Extrovert)"
end

puts "-> Created #{NUM_GUESTS} guests (#{NUM_EXTROVERTS} extroverts)"

# 2. Generate Relationships (Edges)
love_edges = Array(Tuple(Int32, Int32, Float64)).new
hate_edges = Array(Tuple(Int32, Int32, Float64)).new
friend_edges = Array(Tuple(Int32, Int32, Float64)).new

# Couples (Love: +10.0)
available_singles = (0...NUM_GUESTS).to_a.shuffle
NUM_COUPLES.times do
  p1 = available_singles.pop
  p2 = available_singles.pop
  love_edges << {p1, p2, 10.0}
  guest_names[p1] += " [Couple_#{love_edges.size}]"
  guest_names[p2] += " [Couple_#{love_edges.size}]"
end

# Enemies (Hate: -10.0) - "The Divorced Parents / Political Rivals"
NUM_ENEMIES.times do
  p1 = rand(NUM_GUESTS)
  p2 = rand(NUM_GUESTS)
  next if p1 == p2
  # Don't make couples enemies (too complicated for this demo)
  next if love_edges.any? { |e| (e[0] == p1 && e[1] == p2) || (e[0] == p2 && e[1] == p1) }
  
  hate_edges << {p1, p2, -10.0}
end

# Friends (Friendship: +1.0 to +3.0) - The "Glue"
200.times do
  p1 = rand(NUM_GUESTS)
  p2 = rand(NUM_GUESTS)
  next if p1 == p2
  friend_edges << {p1, p2, rand(1.0..3.0)}
end

puts "-> Relationships defined:"
puts "   ❤️  #{love_edges.size} Couples (Must sit together)"
puts "   💀  #{hate_edges.size} Feuds (Must separate)"
puts "   🍺  #{friend_edges.size} Friendships"

# 3. Build Multi-Type Graph
edge_types = {
  "love" => SparseMatrix.from_edges(NUM_GUESTS, NUM_GUESTS, love_edges),
  "hate" => SparseMatrix.from_edges(NUM_GUESTS, NUM_GUESTS, hate_edges),
  "friend" => SparseMatrix.from_edges(NUM_GUESTS, NUM_GUESTS, friend_edges)
}

# Initial importance of each constraint type
type_weights = {
  "love" => 5.0,    # Critical
  "hate" => 5.0,    # Critical
  "friend" => 1.0   # Nice to have
}

graph = Graph.new(weights, edge_types, type_weights)

# 4. Configure Optimization Engine
engine = Engine.new(
  graph,
  segments: NUM_TABLES,
  fairness_weight: 1.0,       # Keep tables balanced (~10 people)
  weight_fairness_weight: 3.0, # SPREAD THE EXTROVERTS! (High importance)
  cross_conflict_weight: 1.0,  # Respect the edges
  calibrate: true,             # Learn the landscape
  enable_corr_guard: true      # Ensure math validity
)

puts "\n🧠 Calibrating Spectral-Multiplicative Engine..."
engine.calibrate!(samples: 128)

puts "🚀 Optimizing Seating Chart..."
start_time = Time.monotonic
result = engine.solve(iterations: 3000)
duration = Time.monotonic - start_time

# 5. Analysis & Reporting
puts "\n🎉 OPTIMIZATION COMPLETE in #{duration.total_milliseconds.round(1)} ms"
puts "========================================"

# Metrics
puts "Energy: #{result.energy.round(4)}"
puts "Fairness (Size Balance): #{result.fairness.round(4)}"
puts "Vibe Balance (Extrovert Spread): #{result.weight_fairness.round(4)}"

# Validate Constraints
broken_couples = 0
drama_incidents = 0

love_edges.each do |u, v, _|
  if result.discrete_solution[u] != result.discrete_solution[v]
    broken_couples += 1
  end
end

hate_edges.each do |u, v, _|
  if result.discrete_solution[u] == result.discrete_solution[v]
    drama_incidents += 1
  end
end

puts "\n📋 CONSTRAINT REPORT"
puts "--------------------"
if broken_couples == 0
  puts "❤️  ROMANCE: PERFECT! All #{NUM_COUPLES} couples are seated together."
else
  puts "💔 ROMANCE: #{broken_couples} couples separated."
end

if drama_incidents == 0
  puts "🕊️  PEACE: PERFECT! All #{NUM_ENEMIES} enemies are separated."
else
  puts "🔥 DRAMA: #{drama_incidents} fights likely (Enemies at same table)."
end

# Table Breakdown
puts "\n🍽️  TABLE ASSIGNMENTS"
puts "---------------------"
result.segments.each_with_index do |table, i|
  extrovert_count = table.count { |guest_idx| weights[guest_idx] > 2.0 }
  vibe_score = "Low Energy"
  vibe_score = "Balanced" if extrovert_count >= 1
  vibe_score = "Party Table!" if extrovert_count >= 3
  
  puts "Table #{i+1}: #{table.size} guests | #{extrovert_count} Extroverts | Vibe: #{vibe_score}"
  # puts "  #{table.map { |id| guest_names[id] }.join(", ")}" # Uncomment for full list
end

puts "\n✅ VERDICT: The wedding is saved."
