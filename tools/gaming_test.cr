require "./src/multiplicative_constraint"

module GamingTest
  include MultiplicativeConstraint

  SERVICES = [
    "NA-Lobby", "NA-GameServer-1", "NA-GameServer-2", "EU-Lobby", "EU-GameServer-1",
    "EU-GameServer-2", "ASIA-Lobby", "ASIA-GameServer-1", "ASIA-GameServer-2", "GlobalRankings",
    "ChatServer-1", "ChatServer-2", "VoiceRelay-NA", "VoiceRelay-EU", "VoiceRelay-ASIA",
    "AntiCheat", "ReplayStorage", "TournamentMode", "ItemShop", "PlayerProfiles"
  ]

  # Player load weights (concurrent players)
  WEIGHTS = [
    85.0, 70.0, 65.0, 90.0, 75.0, 80.0, 95.0, 85.0, 90.0, 40.0,
    30.0, 30.0, 45.0, 50.0, 55.0, 60.0, 70.0, 35.0, 25.0, 45.0
  ]

  # Data center capacities and latency factors
  DC_CAPACITIES = [250.0, 240.0, 260.0, 220.0]
  DC_LATENCY_FACTORS = [1.0, 1.2, 1.5, 1.1]
  DC_NAMES = ["US-East", "EU-West", "Asia-Pacific", "US-West"]

  def self.create_gaming_adjacency
    n = SERVICES.size
    adj = Array.new(n) { Array(Float64).new(n, 0.0) }

    puts "🎮 Creating 25 gaming infrastructure constraints..."
    puts "  Target: Optimize player experience across global data centers"

    # === REGIONAL AFFINITY (negative = strong attraction) ===
    puts "  Adding 6 regional affinity constraints..."

    # North America cluster
    adj[0][1] = adj[1][0] = -12.0    # NA-Lobby + NA-GameServer-1
    adj[0][2] = adj[2][0] = -12.0    # NA-Lobby + NA-GameServer-2
    adj[1][2] = adj[2][1] = -8.0     # NA Game servers together

    # Europe cluster
    adj[3][4] = adj[4][3] = -12.0    # EU-Lobby + EU-GameServer-1
    adj[3][5] = adj[5][3] = -12.0    # EU-Lobby + EU-GameServer-2
    adj[4][5] = adj[5][4] = -8.0     # EU Game servers together

    # Asia cluster
    adj[6][7] = adj[7][6] = -12.0    # ASIA-Lobby + ASIA-GameServer-1
    adj[6][8] = adj[8][6] = -12.0    # ASIA-Lobby + ASIA-GameServer-2
    adj[7][8] = adj[8][7] = -8.0     # Asia Game servers together

    # === VOICE CHAT LOCALITY (CRITICAL for player experience) ===
    puts "  Adding 3 voice chat locality constraints..."

    adj[12][1] = adj[1][12] = -15.0   # VoiceRelay-NA + NA-GameServer-1
    adj[12][2] = adj[2][12] = -15.0   # VoiceRelay-NA + NA-GameServer-2
    adj[13][4] = adj[4][13] = -15.0   # VoiceRelay-EU + EU-GameServer-1
    adj[13][5] = adj[5][13] = -15.0   # VoiceRelay-EU + EU-GameServer-2
    adj[14][7] = adj[7][14] = -15.0   # VoiceRelay-ASIA + ASIA-GameServer-1
    adj[14][8] = adj[8][14] = -15.0   # VoiceRelay-ASIA + ASIA-GameServer-2

    # === ANTI-CHEAT SECURITY REQUIREMENTS ===
    puts "  Adding 4 anti-cheat constraints..."

    # AntiCheat needs access to all game servers (moderate attraction)
    [1, 2, 4, 5, 7, 8].each do |game_idx|
      adj[15][game_idx] = adj[game_idx][15] = -6.0  # AntiCheat to game servers
    end

    # AntiCheat cannot be with ItemShop (security separation)
    adj[15][18] = adj[18][15] = 8.0   # AntiCheat away from ItemShop

    # AntiCheat needs redundant connection to GlobalRankings
    adj[15][9] = adj[9][15] = -7.0    # AntiCheat + GlobalRankings

    # === LOAD BALANCING & REDUNDANCY ===
    puts "  Adding 4 load balancing constraints..."

    # Chat servers must be in different DCs (anti-affinity)
    adj[10][11] = adj[11][10] = 10.0  # ChatServer-1 ≠ ChatServer-2

    # PlayerProfiles replication (moderate attraction)
    adj[19][9] = adj[9][19] = -5.0    # PlayerProfiles + GlobalRankings
    adj[19][0] = adj[0][19] = -3.0    # PlayerProfiles + NA-Lobby
    adj[19][3] = adj[3][19] = -3.0    # PlayerProfiles + EU-Lobby
    adj[19][6] = adj[6][19] = -3.0    # PlayerProfiles + ASIA-Lobby

    # TournamentMode + GlobalRankings (competitive play)
    adj[17][9] = adj[9][17] = -10.0   # TournamentMode + GlobalRankings

    # === BUSINESS LOGIC CONSTRAINTS ===
    puts "  Adding 5 business logic constraints..."

    # ReplayStorage needs high bandwidth to game servers
    [1, 2, 4, 5, 7, 8].each do |game_idx|
      adj[16][game_idx] = adj[game_idx][16] = -4.0  # ReplayStorage to game servers
    end

    # ItemShop payment processing (NA/EU regions preferred)
    adj[18][0] = adj[0][18] = -3.0    # ItemShop + NA-Lobby
    adj[18][3] = adj[3][18] = -3.0    # ItemShop + EU-Lobby

    # Cross-region play connectivity
    adj[9][0] = adj[0][9] = -2.0      # GlobalRankings to NA-Lobby
    adj[9][3] = adj[3][9] = -2.0      # GlobalRankings to EU-Lobby
    adj[9][6] = adj[6][9] = -2.0      # GlobalRankings to ASIA-Lobby

    # === PERFORMANCE & BANDWIDTH CONSTRAINTS ===
    puts "  Adding 3 performance constraints..."

    # Voice relays cannot share DC with ReplayStorage (bandwidth competition)
    adj[12][16] = adj[16][12] = 6.0   # VoiceRelay-NA away from ReplayStorage
    adj[13][16] = adj[16][13] = 6.0   # VoiceRelay-EU away from ReplayStorage
    adj[14][16] = adj[16][14] = 6.0   # VoiceRelay-ASIA away from ReplayStorage

    # Chat servers away from high-bandwidth game servers
    [1, 2, 4, 5, 7, 8].each do |game_idx|
      [10, 11].each do |chat_idx|
        adj[chat_idx][game_idx] = adj[game_idx][chat_idx] = 2.0
      end
    end

    puts "  ✅ Gaming constraints created: #{count_constraints(adj)}"
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

  def self.run_gaming_test
    puts "🎮 MALLOC GAMING INFRASTRUCTURE TEST"
    puts "=" * 60
    puts "Game Services: #{SERVICES.size}"
    puts "Data Centers: #{DC_NAMES.join(", ")}"
    puts "Total Player Load: #{WEIGHTS.sum}"
    puts "Total DC Capacity: #{DC_CAPACITIES.sum}"
    puts "Utilization: #{(WEIGHTS.sum.to_f / DC_CAPACITIES.sum * 100).round(1)}%"
    puts

    # Create gaming-specific adjacency matrix
    adj = create_gaming_adjacency

    puts "\n🚀 Optimizing global gaming infrastructure..."
    puts "⚡ Player experience optimization in progress..."
    puts

    # Initialize engine with gaming-optimized weights
    graph = MultiplicativeConstraint::Graph.new(WEIGHTS, adj)
    engine = MultiplicativeConstraint::Engine.new(graph, 4,
      fairness_weight: 1.5,           # Balance player load across DCs
      weight_fairness_weight: 2.0,   # Respect DC capacity limits
      entropy_weight: 0.2,           # Some diversity in placement
      penalty_weight: 2.0,           # Enforce critical gaming constraints
      cross_conflict_weight: 1.5     # Minimize cross-DC latency for gaming
    )

    # Run optimization with gaming-appropriate settings
    start_time = Time.utc
    result = engine.solve(iterations: 3000, step: 0.3, seed: 1337)
    runtime = (Time.utc - start_time).total_seconds

    # Generate report
    report = engine.report(result, SERVICES)
    puts report

    # Analyze gaming-specific metrics
    analyze_gaming_solution(result, runtime)
  end

  def self.analyze_gaming_solution(result, runtime)
    puts "\n🎮 GAMING INFRASTRUCTURE ANALYSIS"
    puts "-" * 40

    # Performance check
    puts "⏱️  Optimization time: #{runtime.round(3)} seconds"
    if runtime < 2.0
      puts "✅ EXCELLENT: Real-time gaming optimization speed"
    elsif runtime < 5.0
      puts "✅ GOOD: Fast enough for gaming infrastructure"
    else
      puts "⚠️  SLOW: May impact rapid redeployment"
    end

    # Data center utilization analysis
    puts "\n🌍 REGIONAL DISTRIBUTION:"
    dc_analysis = result.segments.map_with_index do |segment, idx|
      load = segment.sum { |i| WEIGHTS[i] }
      capacity = DC_CAPACITIES[idx]
      utilization = load / capacity * 100
      latency_factor = DC_LATENCY_FACTORS[idx]

      # Count regional services
      na_count = segment.count { |i| i < 3 }      # Services 0-2 are NA
      eu_count = segment.count { |i| i >= 3 && i < 6 }  # Services 3-5 are EU
      asia_count = segment.count { |i| i >= 6 && i < 9 } # Services 6-8 are Asia

      puts "  #{DC_NAMES[idx]}: #{segment.size} services, #{load} load, #{utilization.round(1)}% capacity"
      puts "    Regional: NA:#{na_count} EU:#{eu_count} ASIA:#{asia_count} (Latency factor: #{latency_factor}x)"

      {load: load, capacity: capacity, utilization: utilization,
       latency_factor: latency_factor, services: segment,
       na_count: na_count, eu_count: eu_count, asia_count: asia_count}
    end

    # Check capacity violations
    over_capacity = dc_analysis.count { |dc| dc[:utilization] > 100 }
    if over_capacity > 0
      puts "❌ CRITICAL: #{over_capacity} data centers over capacity!"
    else
      puts "✅ All data centers within capacity limits"
    end

    # Player experience analysis
    puts "\n🎯 PLAYER EXPERIENCE ANALYSIS:"
    analyze_player_experience(result, dc_analysis)

    # Critical path analysis
    puts "\n⚡ CRITICAL GAMING PATHS:"
    analyze_critical_paths(result, dc_analysis)

    # Overall gaming assessment
    puts "\n🏆 GAMING INFRASTRUCTURE VERDICT:"
    gaming_assessment(result, runtime, dc_analysis)
  end

  def self.analyze_player_experience(result, dc_analysis)
    # Check regional correctness
    regional_score = 0
    total_checks = 0

    # NA services in US DCs
    na_dc_indices = [0, 3]  # US-East, US-West
    na_correct = result.segments.each_with_index.sum do |segment, dc_idx|
      segment.count { |i| i < 3 && na_dc_indices.includes?(dc_idx) }
    end
    na_total = 3  # NA-Lobby + 2 game servers
    regional_score += na_correct
    total_checks += na_total
    puts "  🇺🇸 NA Services: #{na_correct}/#{na_total} in North American DCs"

    # EU services in EU DC
    eu_correct = result.segments.each_with_index.sum do |segment, dc_idx|
      segment.count { |i| i >= 3 && i < 6 && dc_idx == 1 }  # DC-1 is EU-West
    end
    eu_total = 3
    regional_score += eu_correct
    total_checks += eu_total
    puts "  🇪🇺 EU Services: #{eu_correct}/#{eu_total} in European DC"

    # Asia services in Asia DC
    asia_correct = result.segments.each_with_index.sum do |segment, dc_idx|
      segment.count { |i| i >= 6 && i < 9 && dc_idx == 2 }  # DC-2 is Asia-Pacific
    end
    asia_total = 3
    regional_score += asia_correct
    total_checks += asia_total
    puts "  🌏 Asia Services: #{asia_correct}/#{asia_total} in Asia-Pacific DC"

    # Voice chat locality
    voice_correct = 0
    voice_total = 3

    # NA Voice Relay with NA game servers
    [12].each do |voice_idx|
      result.segments.each_with_index do |segment, dc_idx|
        if segment.includes?(voice_idx)
          na_games = segment.count { |i| i >= 1 && i <= 2 }
          voice_correct += 1 if na_games > 0
        end
      end
    end

    # EU Voice Relay with EU game servers
    [13].each do |voice_idx|
      result.segments.each_with_index do |segment, dc_idx|
        if segment.includes?(voice_idx)
          eu_games = segment.count { |i| i >= 4 && i <= 5 }
          voice_correct += 1 if eu_games > 0
        end
      end
    end

    # Asia Voice Relay with Asia game servers
    [14].each do |voice_idx|
      result.segments.each_with_index do |segment, dc_idx|
        if segment.includes?(voice_idx)
          asia_games = segment.count { |i| i >= 7 && i <= 8 }
          voice_correct += 1 if asia_games > 0
        end
      end
    end

    puts "  🎤 Voice Chat Locality: #{voice_correct}/#{voice_total} optimal"

    overall_experience = (regional_score + voice_correct).to_f / (total_checks + voice_total) * 100
    puts "  📊 Overall Player Experience: #{overall_experience.round(1)}%"
  end

  def self.analyze_critical_paths(result, dc_analysis)
    # Lobby → GameServer → VoiceRelay path
    puts "  🔥 Matchmaking Path (Lobby → Game → Voice):"

    # Check each region's critical path
    [
      {name: "NA", lobby: 0, games: [1, 2], voice: 12},
      {name: "EU", lobby: 3, games: [4, 5], voice: 13},
      {name: "ASIA", lobby: 6, games: [7, 8], voice: 14}
    ].each do |region|
      lobby_dc = result.segments.index { |seg| seg.includes?(region[:lobby]) }

      region[:games].each do |game_idx|
        game_dc = result.segments.index { |seg| seg.includes?(game_idx) }
        voice_dc = result.segments.index { |seg| seg.includes?(region[:voice]) }

        if lobby_dc && game_dc && voice_dc
          hops = [lobby_dc != game_dc ? 1 : 0, game_dc != voice_dc ? 1 : 0].sum
          latency = hops * 50  # Assume 50ms per DC hop
          status = latency <= 50 ? "✅" : latency <= 100 ? "⚠️" : "❌"
          puts "    #{region[:name]}: #{status} #{latency}ms (#{hops} hops)"
        end
      end
    end

    # AntiCheat connectivity
    puts "  🛡️  AntiCheat Coverage:"
    anticheat_dc = result.segments.index { |seg| seg.includes?(15) }
    if anticheat_dc
      game_coverage = [1, 2, 4, 5, 7, 8].count do |game_idx|
        game_dc = result.segments.index { |seg| seg.includes?(game_idx) }
        game_dc == anticheat_dc
      end
      puts "    Direct coverage: #{game_coverage}/6 game servers"

      if game_coverage >= 4
        puts "    ✅ GOOD: Most games have direct anti-cheat"
      else
        puts "    ⚠️  CONCERN: Limited anti-cheat coverage"
      end
    end
  end

  def self.gaming_assessment(result, runtime, dc_analysis)
    score = 100

    # Penalize slow performance
    score -= 10 if runtime > 5.0
    score -= 5 if runtime > 2.0

    # Penalize capacity issues
    over_capacity = dc_analysis.count { |dc| dc[:utilization] > 100 }
    score -= 20 * over_capacity

    # Check critical gaming requirements
    na_lobby_dc = result.segments.index { |seg| seg.includes?(0) }
    eu_lobby_dc = result.segments.index { |seg| seg.includes?(3) }
    asia_lobby_dc = result.segments.index { |seg| seg.includes?(6) }

    # Regional placement checks
    if na_lobby_dc && [0, 3].includes?(na_lobby_dc)
      puts "  ✅ NA-Lobby correctly placed in North America"
    else
      score -= 15
      puts "  ❌ NA-Lobby not in North American DC"
    end

    if eu_lobby_dc && eu_lobby_dc == 1
      puts "  ✅ EU-Lobby correctly placed in Europe"
    else
      score -= 15
      puts "  ❌ EU-Lobby not in European DC"
    end

    if asia_lobby_dc && asia_lobby_dc == 2
      puts "  ✅ ASIA-Lobby correctly placed in Asia-Pacific"
    else
      score -= 15
      puts "  ❌ ASIA-Lobby not in Asia-Pacific DC"
    end

    # Voice chat locality check
    voice_score = 0
    voice_checks = 0

    # NA voice with NA games
    na_voice_dc = result.segments.index { |seg| seg.includes?(12) }
    if na_voice_dc
      na_games_in_dc = result.segments[na_voice_dc].count { |i| [1, 2].includes?(i) }
      voice_score += 1 if na_games_in_dc > 0
    end
    voice_checks += 1

    # EU voice with EU games
    eu_voice_dc = result.segments.index { |seg| seg.includes?(13) }
    if eu_voice_dc
      eu_games_in_dc = result.segments[eu_voice_dc].count { |i| [4, 5].includes?(i) }
      voice_score += 1 if eu_games_in_dc > 0
    end
    voice_checks += 1

    # Asia voice with Asia games
    asia_voice_dc = result.segments.index { |seg| seg.includes?(14) }
    if asia_voice_dc
      asia_games_in_dc = result.segments[asia_voice_dc].count { |i| [7, 8].includes?(i) }
      voice_score += 1 if asia_games_in_dc > 0
    end
    voice_checks += 1

    voice_percentage = voice_score.to_f / voice_checks * 100
    if voice_percentage >= 80
      puts "  ✅ Voice chat locality optimized (#{voice_percentage.round(0)}%)"
    elsif voice_percentage >= 60
      puts "  ⚠️  Voice chat partially optimized (#{voice_percentage.round(0)}%)"
      score -= 10
    else
      puts "  ❌ Voice chat locality poor (#{voice_percentage.round(0)}%)"
      score -= 20
    end

    # Final verdict
    if score >= 85
      puts "  🏆 OUTSTANDING: AAA gaming infrastructure optimization"
    elsif score >= 70
      puts "  🎯 EXCELLENT: Professional gaming deployment ready"
    elsif score >= 55
      puts "  ✅ GOOD: Acceptable gaming performance"
    elsif score >= 40
      puts "  ⚠️  MARGINAL: Needs optimization before production"
    else
      puts "  ❌ POOR: Not suitable for gaming deployment"
    end

    puts "  🎮 FINAL GAMING SCORE: #{score}/100"
  end
end

# Run the gaming infrastructure test
GamingTest.run_gaming_test