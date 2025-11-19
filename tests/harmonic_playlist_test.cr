# Harmonic Playlist Sequencer - Spectral Optimization Test
#
# Scenario:
# - 50 Songs
# - Goal: Create 5 "Sets" (10 songs each) that are harmonically coherent.
# - Constraints:
#   1. Harmonic Mixing: Songs in a set should be compatible (Circle of Fifths).
#   2. Tempo Lock: Songs in a set should have similar BPM.
#   3. Energy Flow: We want to group High Energy songs together and Low Energy songs together.

require "../src/multiplicative_constraint"

include MultiplicativeConstraint

puts "🎵 HARMONIC PLAYLIST SEQUENCER 🎵"
puts "==================================="
puts "Analyzing 50 tracks for spectral coherence..."

NUM_SONGS = 50
NUM_SETS = 5

# Musical Keys (Circle of Fifths indices: 0=C, 1=G, 2=D, ..., 11=F)
KEYS = ["C", "G", "D", "A", "E", "B", "F#", "Db", "Ab", "Eb", "Bb", "F"]

struct Song
  property id : Int32
  property title : String
  property key_idx : Int32 # 0-11
  property bpm : Float64
  property energy : Float64
  
  def initialize(@id, @title, @key_idx, @bpm, @energy)
  end

  def key_name
    KEYS[@key_idx]
  end
end

# 1. Generate Library
songs = Array(Song).new
genres = ["House", "Techno", "Trance", "Ambient", "Dubstep"]

NUM_SONGS.times do |i|
  # Create clusters of keys/tempos naturally
  genre_idx = rand(genres.size)
  base_bpm = 120.0 + (genre_idx * 5.0) # 120, 125, 130...
  base_key = (genre_idx * 3) % 12       # Spaced out keys
  
  bpm = base_bpm + rand(-5.0..5.0)
  key = (base_key + rand(-1..1)) % 12
  energy = 0.3 + (genre_idx * 0.15) + rand(-0.1..0.1)
  
  songs << Song.new(i, "Track_#{i} (#{genres[genre_idx]})", key, bpm, energy)
end

puts "-> Library generated. Example tracks:"
songs.first(5).each do |s|
  puts "   #{s.title}: Key=#{s.key_name}, BPM=#{s.bpm.round(1)}, Energy=#{s.energy.round(2)}"
end

# 2. Build Transition Graph
# We define "Distance" in musical space
harmonic_edges = Array(Tuple(Int32, Int32, Float64)).new
tempo_edges = Array(Tuple(Int32, Int32, Float64)).new

songs.each_with_index do |s1, i|
  songs.each_with_index do |s2, j|
    next if i >= j # Symmetric
    
    # Harmonic Distance (Circle of Fifths)
    # 0 = Perfect, 1 = Compatible, 6 = Tritone (Dissonant)
    diff = (s1.key_idx - s2.key_idx).abs
    circle_dist = [diff, 12 - diff].min
    
    if circle_dist <= 1
      # Strong Harmonic Link
      weight = (circle_dist == 0) ? 2.0 : 1.0
      harmonic_edges << {i, j, weight}
    end
    
    # Tempo Distance
    bpm_diff = (s1.bpm - s2.bpm).abs
    if bpm_diff < 5.0
      # Strong Tempo Link
      weight = 2.0 / (bpm_diff + 1.0)
      tempo_edges << {i, j, weight}
    end
  end
end

puts "\n-> Transition Graph Built:"
puts "   🎹 #{harmonic_edges.size} Harmonic Links (Key Compatible)"
puts "   🥁 #{tempo_edges.size} Tempo Links (BPM Compatible)"

# 3. Create Multi-Type Graph
edge_types = {
  "harmonic" => SparseMatrix.from_edges(NUM_SONGS, NUM_SONGS, harmonic_edges),
  "tempo" => SparseMatrix.from_edges(NUM_SONGS, NUM_SONGS, tempo_edges)
}

# We use Energy as the node weight
# This forces the engine to balance "Total Energy" across sets if we use weight_fairness
# OR we can try to cluster by energy if we use it as a constraint.
# Let's use uniform weights for now to just balance the *number* of songs.
node_weights = Array.new(NUM_SONGS, 1.0)

graph = Graph.new(node_weights, edge_types, {
  "harmonic" => 1.0, # Key is king
  "tempo" => 1.0     # Tempo is secondary
})

# 4. Configure Engine
engine = Engine.new(
  graph,
  segments: NUM_SETS,
  fairness_weight: 1_000_000.0,       # FORCE sets to be equal length (Nuclear option V2)
  cross_conflict_weight: 1.5, # Minimize bad transitions between sets (keep good ones inside)
  entropy_weight: 0.1,        # Allow some variety
  calibrate: true
)

puts "\n🧠 Calibrating Musical Manifold..."
engine.calibrate!(samples: 128)

puts "🚀 Sequencing Sets..."
start_time = Time.monotonic
result = engine.solve(iterations: 2000)
duration = Time.monotonic - start_time

# 5. Analysis
puts "\n🎉 SEQUENCING COMPLETE in #{duration.total_milliseconds.round(1)} ms"
puts "========================================"
puts "Energy Components:"
puts "  Spectral: #{result.spectral}"
puts "  Fairness: #{result.fairness} (Weight: 1_000_000.0)"
puts "  Penalty:  #{result.penalty}"

result.segments.each_with_index do |set_indices, i|
  puts "\n💿 SET #{i+1} (#{set_indices.size} tracks)"
  puts "--------------------------------"
  
  # Analyze Key Coherence
  keys = set_indices.map { |idx| songs[idx].key_idx }
  # Find dominant key
  key_counts = Hash(Int32, Int32).new(0)
  keys.each { |k| key_counts[k] += 1 }
  dominant_key = key_counts.max_by { |k, v| v }[0]
  
  # Analyze Tempo
  bpms = set_indices.map { |idx| songs[idx].bpm }
  avg_bpm = bpms.sum / bpms.size
  bpm_range = bpms.max - bpms.min
  
  puts "   Dominant Key: #{KEYS[dominant_key]} (Covering #{(key_counts[dominant_key].to_f / set_indices.size * 100).round}% of set)"
  puts "   Avg BPM: #{avg_bpm.round(1)} (Range: #{bpm_range.round(1)})"
  
  # List tracks
  # set_indices.first(5).each do |idx|
  #   s = songs[idx]
  #   puts "     - #{s.title} [#{s.key_name} / #{s.bpm.round} BPM]"
  # end
end

# Global Coherence Score
total_harmonic_edges_preserved = 0
harmonic_edges.each do |u, v, _|
  if result.discrete_solution[u] == result.discrete_solution[v]
    total_harmonic_edges_preserved += 1
  end
end

puts "\n📊 METRICS"
puts "----------"
puts "Harmonic Preservation: #{total_harmonic_edges_preserved} / #{harmonic_edges.size} edges kept within sets"
puts "Spectral Energy: #{result.spectral.round(4)}"

puts "\n✅ VERDICT: The vibe is curated."
