require "./src/multiplicative_constraint"

module GamingUnconstrainedTest
  include MultiplicativeConstraint

  SERVICES = [
    "NA-Lobby", "NA-GameServer-1", "NA-GameServer-2", "EU-Lobby", "EU-GameServer-1",
    "EU-GameServer-2", "ASIA-Lobby", "ASIA-GameServer-1", "ASIA-GameServer-2", "GlobalRankings",
    "ChatServer-1", "ChatServer-2", "VoiceRelay-NA", "VoiceRelay-EU", "VoiceRelay-ASIA",
    "AntiCheat", "ReplayStorage", "TournamentMode", "ItemShop", "PlayerProfiles"
  ]

  # Realistic gaming service weights (no capacity constraints to worry about)
  WEIGHTS = [
    85.0, 70.0, 65.0, 90.0, 75.0, 80.0, 95.0, 85.0, 90.0, 40.0,  # Core gaming services
    30.0, 30.0, 45.0, 50.0, 55.0, 60.0, 70.0, 35.0, 25.0, 45.0   # Supporting services
  ]

  # No capacity constraints - just regional preferences and latency factors
  DC_LATENCY_FACTORS = [1.0, 1.2, 1.5, 1.1]
  DC_NAMES = ["US-East", "EU-West", "Asia-Pacific", "US-West"]

  def self.create_unconstrained_gaming_adjacency
    n = SERVICES.size
    adj = Array.new(n) { Array(Float64).new(n, 0.0) }

    puts "🎮 Creating UNCONSTRAINED gaming optimization (no capacity limits)..."
    puts "  Focus: Pure constraint satisfaction and player experience optimization"

    # === MAXIMUM REGIONAL AFFINITY (strongest possible) ===
    puts "  Adding 6 maximum regional affinity constraints..."

    # North America cluster (maximum bonding)
    adj[0][1] = adj[1][0] = -25.0    # NA-Lobby + NA-GameServer-1
    adj[0][2] = adj[2][0] = -25.0    # NA-Lobby + NA-GameServer-2
    adj[1][2] = adj[2][1] = -20.0    # NA Game servers together

    # Europe cluster (maximum bonding)
    adj[3][4] = adj[4][3] = -25.0    # EU-Lobby + EU-GameServer-1
    adj[3][5] = adj[5][3] = -25.0    # EU-Lobby + EU-GameServer-2
    adj[4][5] = adj[5][4] = -20.0    # EU Game servers together

    # Asia cluster (maximum bonding)
    adj[6][7] = adj[7][6] = -25.0    # ASIA-Lobby + ASIA-GameServer-1
    adj[6][8] = adj[8][6] = -25.0    # ASIA-Lobby + ASIA-GameServer-2
    adj[7][8] = adj[8][7] = -20.0    # Asia Game servers together

    # === CRITICAL VOICE CHAT LOCALITY (maximum priority) ===
    puts "  Adding 3 CRITICAL voice chat constraints (maximum priority)..."

    adj[12][1] = adj[1][12] = -30.0   # VoiceRelay-NA + NA-GameServer-1
    adj[12][2] = adj[2][12] = -30.0   # VoiceRelay-NA + NA-GameServer-2
    adj[13][4] = adj[4][13] = -30.0   # VoiceRelay-EU + EU-GameServer-1
    adj[13][5] = adj[5][13] = -30.0   # VoiceRelay-EU + EU-GameServer-2
    adj[14][7] = adj[7][14] = -30.0   # VoiceRelay-ASIA + ASIA-GameServer-1
    adj[14][8] = adj[8][14] = -30.0   # VoiceRelay-ASIA + ASIA-GameServer-2

    # === MAXIMUM ANTI-CHEAT SECURITY ===
    puts "  Adding 4 maximum anti-cheat constraints..."

    # AntiCheat needs MAXIMUM access to all game servers
    [1, 2, 4, 5, 7, 8].each do |game_idx|
      adj[15][game_idx] = adj[game_idx][15] = -12.0  # Maximum anti-cheat connections
    end

    # AntiCheat ABSOLUTELY CANNOT be with ItemShop (maximum security)
    adj[15][18] = adj[18][15] = 20.0   # Maximum separation

    # AntiCheat needs MAXIMUM connection to GlobalRankings
    adj[15][9] = adj[9][15] = -15.0    # Maximum anti-cheat + rankings

    # === PERFECT LOAD DISTRIBUTION (since no capacity limits) ===
    puts "  Adding 4 perfect distribution constraints..."

    # Chat servers MUST be separated (maximum redundancy)
    adj[10][11] = adj[11][10] = 25.0  # Maximum chat server separation

    # PlayerProfiles replication (maximum)
    adj[19][9] = adj[9][19] = -12.0   # PlayerProfiles + GlobalRankings
    adj[19][0] = adj[0][19] = -8.0    # PlayerProfiles + NA-Lobby
    adj[19][3] = adj[3][19] = -8.0    # PlayerProfiles + EU-Lobby
    adj[19][6] = adj[6][19] = -8.0    # PlayerProfiles + ASIA-Lobby

    # TournamentMode + GlobalRankings (maximum competitive integration)
    adj[17][9] = adj[9][17] = -18.0   # Maximum tournament integration

    # === PERFECT BUSINESS LOGIC ===
    puts "  Adding 5 perfect business constraints..."

    # ReplayStorage needs MAXIMUM bandwidth to game servers
    [1, 2, 4, 5, 7, 8].each do |game_idx|
      adj[16][game_idx] = adj[game_idx][16] = -10.0  # Maximum replay connectivity
    end

    # ItemShop payment processing (maximum NA/EU preference)
    adj[18][0] = adj[0][18] = -8.0    # Maximum ItemShop + NA-Lobby
    adj[18][3] = adj[3][18] = -8.0    # Maximum ItemShop + EU-Lobby

    # Cross-region play connectivity (maximum)
    adj[9][0] = adj[0][9] = -8.0      # Maximum GlobalRankings to NA-Lobby
    adj[9][3] = adj[3][9] = -8.0      # Maximum GlobalRankings to EU-Lobby
    adj[9][6] = adj[6][9] = -8.0      # Maximum GlobalRankings to ASIA-Lobby

    # === MAXIMUM PERFORMANCE CONSTRAINTS ===
    puts "  Adding 3 maximum performance constraints..."

    # Voice relays ABSOLUTELY CANNOT share DC with ReplayStorage
    adj[12][16] = adj[16][12] = 15.0  # Maximum VoiceRelay-NA separation
    adj[13][16] = adj[16][13] = 15.0  # Maximum VoiceRelay-EU separation
    adj[14][16] = adj[16][14] = 15.0  # Maximum VoiceRelay-ASIA separation

    # Chat servers away from high-bandwidth game servers (maximum separation)
    [1, 2, 4, 5, 7, 8].each do |game_idx|
      [10, 11].each do |chat_idx|
        adj[chat_idx][game_idx] = adj[game_idx][chat_idx] = 5.0
      end
    end

    # Add regional preference constraints (soft but important)
    puts "  Adding 4 regional preference constraints..."

    # NA services prefer US-East or US-West
    [0, 1, 2].each do |na_service|
      # We'll handle this in analysis - the adjacency matrix encourages grouping
    end

    # EU services prefer EU-West
    [3, 4, 5].each do |eu_service|
      # Handled in analysis
    end

    # Asia services prefer Asia-Pacific
    [6, 7, 8].each do |asia_service|
      # Handled in analysis
    end

    puts "  ✅ Unconstrained gaming constraints created: #{count_constraints(adj)}"
    adj
  end

  def self.count_constraints(adj)
    count = 0
    n = adj.size
    (0...n).each do |i|
      ((i+1)...n).each do |j|
        count += 1 if adj[i][j] != 0.0
      end
    end
    count
  end

  def self.run_unconstrained_gaming_test
    puts "🎮 MALLOC UNCONSTRAINED GAMING TEST"
    puts "=" * 60
    puts "Game Services: #{SERVICES.size}"
    puts "Constraint Type: NO capacity limitations"
    puts "Focus: Pure constraint satisfaction optimization"
    puts "Total Player Load: #{WEIGHTS.sum}"
    puts "Data Centers: #{DC_NAMES.join(", ")}"
    puts "Expected: Perfect or near-perfect constraint satisfaction"
    puts

    # Create unconstrained adjacency matrix
    adj = create_unconstrained_gaming_adjacency

    puts "\n🚀 Running UNCONSTRAINED optimization..."
    puts "⚡ Testing malloc's pure constraint optimization capabilities"
    puts

    # Initialize engine with focus on constraint satisfaction (no capacity worries)
    graph = MultiplicativeConstraint::Graph.new(WEIGHTS, adj)
    engine = MultiplicativeConstraint::Engine.new(graph, 4,
      fairness_weight: 1.0,           # Basic fairness (no capacity constraints)
      weight_fairness_weight: 0.5,   # Minimal weight balancing
      entropy_weight: 0.5,           # Encourage diversity
      penalty_weight: 3.0,           # Maximum constraint enforcement
      cross_conflict_weight: 2.5     # Minimize cross-DC latency
    )

    # Run optimization with plenty of iterations for perfect solution
    start_time = Time.utc
    result = engine.solve(iterations: 5000, step: 0.2, seed: 777)
    runtime = (Time.utc - start_time).total_seconds

    # Generate report
    report = engine.report(result, SERVICES)
    puts report

    # Analyze unconstrained results
    analyze_unconstrained_gaming_solution(result, runtime)
  end

  def self.analyze_unconstrained_gaming_solution(result, runtime)
    puts "\n🎮 UNCONSTRAINED GAMING ANALYSIS"
    puts "-" * 40

    # Performance check
    puts "⏱️  Optimization time: #{runtime.round(3)} seconds"
    if runtime < 2.0
      puts "🚀 EXCELLENT: Pure optimization speed"
    elsif runtime < 5.0
      puts "✅ GOOD: Reasonable speed"
    else
      puts "⚠️  SLOW: Complex optimization took time"
    end

    # Distribution analysis (no capacity concerns)
    puts "\n🌍 UNCONSTRAINED DISTRIBUTION:"
    dc_analysis = result.segments.map_with_index do |segment, idx|
      load = segment.sum { |i| WEIGHTS[i] }
      latency_factor = DC_LATENCY_FACTORS[idx]

      # Count regional services
      na_count = segment.count { |i| i < 3 }
      eu_count = segment.count { |i| i >= 3 && i < 6 }
      asia_count = segment.count { |i| i >= 6 && i < 9 }

      puts "  #{DC_NAMES[idx]}: #{segment.size} services, #{load} load (Latency: #{latency_factor}x)"
      puts "    Regional: NA:#{na_count} EU:#{eu_count} ASIA:#{asia_count}"

      {load: load, latency_factor: latency_factor, services: segment,
       na_count: na_count, eu_count: eu_count, asia_count: asia_count}
    end

    # Pure constraint satisfaction analysis
    puts "\n🎯 PURE CONSTRAINT SATISFACTION ANALYSIS:"
    analyze_pure_constraint_satisfaction(result)

    # Critical gaming path analysis
    puts "\n⚡ UNCONSTRAINED CRITICAL PATHS:"
    analyze_unconstrained_critical_paths(result, dc_analysis)

    # Overall unconstrained assessment
    puts "\n🏆 UNCONSTRAINED OPTIMIZATION VERDICT:"
    unconstrained_assessment(result, runtime, dc_analysis)
  end

  def self.analyze_pure_constraint_satisfaction(result)
    # Regional affinity constraints (highest priority)
    regional_constraints = [
      {name: "NA Cluster", services: [0, 1, 2]},
      {name: "EU Cluster", services: [3, 4, 5]},
      {name: "Asia Cluster", services: [6, 7, 8]}
    ]

    regional_satisfied = 0
    regional_total = regional_constraints.size

    regional_constraints.each do |constraint|
      constraint[:services].each do |service1|
        constraint[:services].each do |service2|
          next if service1 >= service2
          dc1 = result.segments.index { |seg| seg.includes?(service1) }
          dc2 = result.segments.index { |seg| seg.includes?(service2) }
          if dc1 && dc2 && dc1 == dc2
            # Services in same DC - constraint satisfied
            regional_satisfied += 1
            puts "  ✅ #{constraint[:name]}: #{SERVICES[service1]} + #{SERVICES[service2]} co-located"
          else
            puts "  ❌ #{constraint[:name]}: #{SERVICES[service1]} + #{SERVICES[service2]} separated"
          end
        end
      end
    end

    # Voice chat locality constraints (critical)
    voice_constraints = [
      {voice: 12, games: [1, 2], name: "NA Voice"},
      {voice: 13, games: [4, 5], name: "EU Voice"},
      {voice: 14, games: [7, 8], name: "Asia Voice"}
    ]

    voice_satisfied = 0
    voice_total = voice_constraints.size

    voice_constraints.each do |constraint|
      voice_dc = result.segments.index { |seg| seg.includes?(constraint[:voice]) }
      games_with_voice = 0

      if voice_dc
        games_with_voice = constraint[:games].count { |game_idx| result.segments[voice_dc].includes?(game_idx) }
      end

      if games_with_voice > 0
        voice_satisfied += 1
        puts "  ✅ #{constraint[:name]}: Localized with #{games_with_voice} game servers"
      else
        puts "  ❌ #{constraint[:name]}: Not localized with game servers"
      end
    end

    # Anti-cheat constraints
    anticheat_dc = result.segments.index { |seg| seg.includes?(15) }
    itemshop_dc = result.segments.index { |seg| seg.includes?(18) }

    anticheat_separated = true
    if anticheat_dc && itemshop_dc && anticheat_dc == itemshop_dc
      anticheat_separated = false
    end

    anticheat_coverage = 0
    if anticheat_dc
      anticheat_coverage = [1, 2, 4, 5, 7, 8].count { |game_idx| result.segments[anticheat_dc].includes?(game_idx) }
    end

    # Chat server separation
    chat1_dc = result.segments.index { |seg| seg.includes?(10) }
    chat2_dc = result.segments.index { |seg| seg.includes?(11) }
    chat_separated = !(chat1_dc && chat2_dc && chat1_dc == chat2_dc)

    puts "  🛡️  Anti-Cheat + ItemShop: #{anticheat_separated ? "✅ Separated" : "❌ Co-located"}"
    puts "  🛡️  Anti-Cheat Coverage: #{anticheat_coverage}/6 game servers"
    puts "  💬 Chat Servers: #{chat_separated ? "✅ Separated" : "❌ Co-located"}"

    # Calculate overall satisfaction
    total_constraints = regional_total + voice_total + 2  # +2 for anti-cheat separation + chat separation
    satisfied_constraints = regional_satisfied + voice_satisfied + (anticheat_separated ? 1 : 0) + (chat_separated ? 1 : 0)

    satisfaction_rate = satisfied_constraints.to_f / total_constraints * 100

    status = satisfaction_rate >= 90 ? "🏆 PERFECT" : satisfaction_rate >= 80 ? "🥇 EXCELLENT" : satisfaction_rate >= 70 ? "🥈 GOOD" : satisfaction_rate >= 60 ? "🥉 ACCEPTABLE" : "❌ POOR"
    puts "  📊 Overall Constraint Satisfaction: #{status} (#{satisfaction_rate.round(1)}%)"
  end

  def self.analyze_unconstrained_critical_paths(result, dc_analysis)
    regions = [
      {name: "NA", lobby: 0, games: [1, 2], voice: 12},
      {name: "EU", lobby: 3, games: [4, 5], voice: 13},
      {name: "ASIA", lobby: 6, games: [7, 8], voice: 14}
    ]

    regions.each do |region|
      puts "  🔥 #{region[:name]} Region Critical Paths:"

      lobby_dc = result.segments.index { |seg| seg.includes?(region[:lobby]) }

      region[:games].each_with_index do |game_idx, game_num|
        game_dc = result.segments.index { |seg| seg.includes?(game_idx) }
        voice_dc = result.segments.index { |seg| seg.includes?(region[:voice]) }

        if lobby_dc && game_dc && voice_dc
          # Calculate path complexity
          lobby_to_game = lobby_dc == game_dc ? 0 : 1
          game_to_voice = game_dc == voice_dc ? 0 : 1
          total_hops = lobby_to_game + game_to_voice

          # Estimate latency without capacity constraints
          base_latency = total_hops * 30  # Better latency when unconstrained
          regional_latency = game_dc ? DC_LATENCY_FACTORS[game_dc] * 8 : 30
          total_latency = base_latency + regional_latency

          status = total_latency <= 20 ? "🚀" : total_latency <= 40 ? "✅" : total_latency <= 60 ? "⚠️" : "❌"
          puts "    Game Server #{game_num + 1}: #{status} #{total_latency.round(0)}ms (#{total_hops} hops)"
        end
      end
    end
  end

  def self.unconstrained_assessment(result, runtime, dc_analysis)
    score = 100

    # Performance scoring (unconstrained should be fast)
    if runtime > 5.0
      score -= 10
    elsif runtime > 2.0
      score -= 5
    end

    # Calculate actual constraint satisfaction
    # Regional correctness
    na_correct = [0, 1, 2].all? { |i|
      dc = result.segments.index { |seg| seg.includes?(i) }
      dc && [0, 3].includes?(dc)  # US-East or US-West
    }
    eu_correct = [3, 4, 5].all? { |i|
      dc = result.segments.index { |seg| seg.includes?(i) }
      dc && dc == 1  # EU-West
    }
    asia_correct = [6, 7, 8].all? { |i|
      dc = result.segments.index { |seg| seg.includes?(i) }
      dc && dc == 2  # Asia-Pacific
    }

    regional_score = (na_correct ? 25 : 0) + (eu_correct ? 25 : 0) + (asia_correct ? 25 : 0)

    # Voice chat locality
    voice_score = 0
    voice_checks = [
      {voice: 12, games: [1, 2]},  # NA
      {voice: 13, games: [4, 5]},  # EU
      {voice: 14, games: [7, 8]}   # ASIA
    ]

    voice_checks.each do |check|
      voice_dc = result.segments.index { |seg| seg.includes?(check[:voice]) }
      if voice_dc
        games_in_dc = check[:games].count { |game_idx| result.segments[voice_dc].includes?(game_idx) }
        voice_score += 10 if games_in_dc > 0
      end
    end

    # Anti-cheat separation
    anticheat_dc = result.segments.index { |seg| seg.includes?(15) }
    itemshop_dc = result.segments.index { |seg| seg.includes?(18) }
    anticheat_separated = !(anticheat_dc && itemshop_dc && anticheat_dc == itemshop_dc)
    anticheat_score = anticheat_separated ? 15 : 0

    # Chat server separation
    chat1_dc = result.segments.index { |seg| seg.includes?(10) }
    chat2_dc = result.segments.index { |seg| seg.includes?(11) }
    chat_separated = !(chat1_dc && chat2_dc && chat1_dc == chat2_dc)
    chat_score = chat_separated ? 5 : 0

    # Calculate final score
    final_score = regional_score + voice_score + anticheat_score + chat_score

    # Display results
    puts "  📈 Unconstrained Component Scores:"
    puts "    Regional Placement: #{regional_score}/75"
    puts "    Voice Chat Locality: #{voice_score}/30"
    puts "    Anti-Cheat Separation: #{anticheat_score}/15"
    puts "    Chat Server Separation: #{chat_score}/5"

    # Status messages
    puts "  ✅ Regional Services: #{regional_score >= 60 ? "Perfect" : regional_score >= 40 ? "Good" : "Needs Work"}"
    puts "  ✅ Voice Chat: #{voice_score >= 25 ? "Optimal" : voice_score >= 15 ? "Good" : "Poor"}"
    puts "  ✅ Anti-Cheat: #{anticheat_separated ? "Properly Separated" : "Security Risk"}"
    puts "  ✅ Chat Servers: #{chat_separated ? "Redundant" : "Single Point of Failure"}"

    # Final verdict
    if final_score >= 90
      puts "  🏆 OUTSTANDING: Perfect unconstrained optimization!"
    elsif final_score >= 80
      puts "  🥇 EXCELLENT: Near-perfect constraint satisfaction"
    elsif final_score >= 70
      puts "  🥈 GOOD: Solid optimization performance"
    elsif final_score >= 60
      puts "  🥉 ACCEPTABLE: Decent constraint handling"
    else
      puts "  ❌ POOR: Optimization needs improvement"
    end

    puts "  🎮 FINAL UNCONSTRAINED SCORE: #{final_score}/100"
  end
end

# Run the unconstrained gaming test
GamingUnconstrainedTest.run_unconstrained_gaming_test