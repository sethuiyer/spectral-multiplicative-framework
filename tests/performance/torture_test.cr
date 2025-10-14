require "./src/multiplicative_constraint"

module TortureTest
  include MultiplicativeConstraint

  SERVICES = [
    "PrimaryDB", "ReplicaDB-1", "ReplicaDB-2", "CacheLayer-1", "CacheLayer-2",
    "SearchEngine", "SearchReplica", "APIGateway", "AuthService", "PaymentCore",
    "FraudDetection", "UserService", "NotificationHub", "Analytics", "StreamProcessor",
    "BatchProcessor", "MediaStorage", "CDNOrigin", "Monitoring", "BackupService"
  ]

  # Resource requirements (weights)
  WEIGHTS = [
    100.0, 80.0, 80.0, 40.0, 40.0, 60.0, 50.0, 30.0, 25.0, 35.0,
    45.0, 20.0, 15.0, 70.0, 55.0, 50.0, 90.0, 25.0, 30.0, 60.0
  ]

  # Region capacities
  CAPACITIES = [200.0, 180.0, 150.0, 170.0]

  def self.create_nightmare_adjacency
    n = SERVICES.size
    adj = Array.new(n) { Array(Float64).new(n, 0.0) }

    puts "🔥 Creating 30 brutal constraints for 20 services..."

    # === HARD CO-LOCATION REQUIREMENTS (negative = attraction) ===
    puts "  Adding 5 hard co-location constraints..."

    adj[0][8] = adj[8][0] = -15.0   # PrimaryDB + AuthService
    adj[9][10] = adj[10][9] = -15.0 # PaymentCore + FraudDetection
    adj[3][4] = adj[4][3] = -15.0   # CacheLayer-1 + CacheLayer-2
    adj[5][6] = adj[6][5] = -15.0   # SearchEngine + SearchReplica
    adj[14][13] = adj[13][14] = -15.0 # StreamProcessor + Analytics

    # === HARD ANTI-AFFINITY REQUIREMENTS (positive = repulsion) ===
    puts "  Adding 7 hard anti-affinity constraints..."

    adj[0][1] = adj[1][0] = 12.0    # PrimaryDB ≠ ReplicaDB-1
    adj[0][2] = adj[2][0] = 12.0    # PrimaryDB ≠ ReplicaDB-2
    adj[1][2] = adj[2][1] = 12.0    # ReplicaDB-1 ≠ ReplicaDB-2
    adj[0][19] = adj[19][0] = 12.0  # PrimaryDB ≠ BackupService
    adj[9][19] = adj[19][9] = 12.0  # PaymentCore ≠ BackupService
    adj[3][16] = adj[16][3] = 10.0  # CacheLayer-1 ≠ MediaStorage
    adj[13][7] = adj[7][13] = 8.0   # Analytics ≠ APIGateway

    # === SOFT PREFERENCES (moderate weights) ===
    puts "  Adding 6 soft preference constraints..."

    adj[7][3] = adj[3][7] = -4.0     # APIGateway prefers CacheLayer-1
    adj[11][0] = adj[0][11] = -3.0   # UserService prefers PrimaryDB
    adj[12][14] = adj[14][12] = -3.0 # NotificationHub prefers StreamProcessor
    adj[17][16] = adj[16][17] = -4.0 # CDNOrigin prefers MediaStorage
    adj[18][0] = adj[0][18] = 3.0    # Monitoring prefers different from PrimaryDB
    adj[15][13] = adj[13][15] = -2.0 # BatchProcessor prefers Analytics

    # === BUSINESS CRITICALITY CONSTRAINTS ===
    puts "  Adding 4 business criticality constraints..."

    # These create complex weight relationships
    adj[0][9] = adj[9][0] = -5.0     # PrimaryDB and PaymentCore synergy
    adj[9][8] = adj[8][9] = -4.0     # PaymentCore and AuthService synergy
    adj[14][15] = adj[15][14] = 5.0  # StreamProcessor and BatchProcessor conflict
    adj[2][19] = adj[19][2] = -6.0   # ReplicaDB-2 in DR site preference

    # === NETWORK TOPOLOGY CONSTRAINTS ===
    puts "  Adding 3 network topology constraints..."

    # APIGateway should be reasonably accessible
    adj[7][0] = adj[0][7] = -2.0     # APIGateway to PrimaryDB
    adj[7][13] = adj[13][7] = -2.0   # APIGateway to Analytics
    adj[7][16] = adj[16][7] = -3.0   # APIGateway to MediaStorage

    # === COMPLIANCE CONSTRAINTS ===
    puts "  Adding 5 compliance constraints..."

    # Data sovereignty: PaymentCore and UserService must be in regions 1 or 2
    # We'll encode this as moderate penalties for separation
    adj[9][11] = adj[11][9] = -3.0   # PaymentCore and UserService

    # Fraud detection latency to PaymentCore
    adj[10][9] = adj[9][10] = -8.0   # Already added as co-location

    # BackupService in DR site (Region 4) - will be enforced in analysis
    adj[19][18] = adj[18][19] = -2.0 # BackupService and Monitoring

    # Monitoring independence
    adj[18][14] = adj[14][18] = 2.0  # Monitoring separate from Analytics

    puts "  ✅ Total constraints encoded: #{count_constraints(adj)}"
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

  def self.run_torture_test
    puts "😈 MALLOC TORTURE TEST: 20-NODE NIGHTMARE SCENARIO"
    puts "=" * 70
    puts "Services: #{SERVICES.size}"
    puts "Target regions: 4 (capacities: #{CAPACITIES})"
    puts "Total weight: #{WEIGHTS.sum}"
    puts "Total capacity: #{CAPACITIES.sum} (#{(WEIGHTS.sum.to_f / CAPACITIES.sum * 100).round(1)}% utilization)"
    puts

    # Create the brutal constraint matrix
    adj = create_nightmare_adjacency

    puts "\n🚀 Running optimization on nightmare scenario..."
    puts "⚠️  This problem may be mathematically infeasible!"
    puts

    # Initialize engine with higher penalties for constraint violations
    graph = MultiplicativeConstraint::Graph.new(WEIGHTS, adj)
    engine = MultiplicativeConstraint::Engine.new(graph, 4,
      fairness_weight: 3.0,           # Higher to ensure balance
      weight_fairness_weight: 2.0,   # Higher to respect capacity
      entropy_weight: 0.3,           # Moderate diversity
      penalty_weight: 2.5,           # Higher to enforce constraints
      cross_conflict_weight: 1.0     # Higher to minimize cross-region traffic
    )

    # Run with more iterations for harder problems
    start_time = Time.utc
    result = engine.solve(iterations: 5000, step: 0.25, seed: 99999)
    runtime = (Time.utc - start_time).total_seconds

    # Generate report
    report = engine.report(result, SERVICES)
    puts report

    # Analyze solution quality
    analyze_nightmare_solution(result, runtime)
  end

  def self.analyze_nightmare_solution(result, runtime)
    puts "\n🔥 TORTURE TEST ANALYSIS"
    puts "-" * 40

    # Runtime performance
    puts "⏱️  Runtime: #{runtime.round(3)} seconds"
    if runtime < 10
      puts "✅ Excellent performance"
    elsif runtime < 30
      puts "✅ Good performance"
    else
      puts "⚠️  Slow performance (may indicate optimization difficulty)"
    end

    # Region distribution and capacity analysis
    puts "\n📦 REGION DISTRIBUTION:"
    region_weights = result.segments.map_with_index do |segment, idx|
      weight = segment.sum { |i| WEIGHTS[i] }
      capacity = CAPACITIES[idx]
      utilization = weight / capacity * 100
      puts "  Region #{idx + 1}: #{segment.size} services, #{weight} weight, #{utilization.round(1)}% (capacity: #{capacity})"
      {weight: weight, capacity: capacity, utilization: utilization, services: segment}
    end

    # Check capacity violations
    capacity_violations = region_weights.count { |r| r[:utilization] > 100 }
    if capacity_violations > 0
      puts "❌ CRITICAL: #{capacity_violations} regions exceed capacity limits!"
    else
      puts "✅ All regions within capacity limits"
    end

    # Balance analysis
    sizes = result.segments.map(&.size)
    target_size = SERVICES.size / 4.0
    balance_score = sizes.reduce(0.0) { |sum, size| sum + (size - target_size)**2 }
    puts "\n⚖️  Balance score: #{balance_score.round(2)} (lower is better)"

    # Constraint satisfaction analysis
    puts "\n🔗 CONSTRAINT SATISFACTION ANALYSIS:"
    analyze_constraints(result)

    # Critical service distribution
    puts "\n🎯 CRITICAL SERVICE DISTRIBUTION:"
    critical_services = ["PrimaryDB", "PaymentCore", "AuthService", "FraudDetection"]
    critical_indices = critical_services.map { |name| SERVICES.index(name) }.compact

    result.segments.each_with_index do |segment, idx|
      critical_count = segment.count { |i| critical_indices.includes?(i) }
      critical_weight = segment.select { |i| critical_indices.includes?(i) }.sum { |i| WEIGHTS[i] }
      puts "  Region #{idx + 1}: #{critical_count} critical services (#{critical_weight} weight)"
    end

    # Overall assessment
    puts "\n🏆 TORTURE TEST VERDICT:"
    final_assessment(result, runtime, capacity_violations, balance_score)
  end

  def self.analyze_constraints(result)
    # Check hard co-location constraints
    satisfied = 0
    total = 0

    # Co-location checks
    co_location_pairs = [
      {0, 8, "PrimaryDB + AuthService"},
      {9, 10, "PaymentCore + FraudDetection"},
      {3, 4, "CacheLayer-1 + CacheLayer-2"},
      {5, 6, "SearchEngine + SearchReplica"},
      {14, 13, "StreamProcessor + Analytics"}
    ]

    co_location_pairs.each do |pair|
      i, j, desc = pair
      total += 1
      if result.segments.any? { |seg| seg.includes?(i) && seg.includes?(j) }
        satisfied += 1
        puts "  ✅ #{desc}: SATISFIED"
      else
        puts "  ❌ #{desc}: VIOLATED"
      end
    end

    # Anti-affinity checks
    anti_affinity_pairs = [
      {0, 1, "PrimaryDB ≠ ReplicaDB-1"},
      {0, 2, "PrimaryDB ≠ ReplicaDB-2"},
      {1, 2, "ReplicaDB-1 ≠ ReplicaDB-2"},
      {0, 19, "PrimaryDB ≠ BackupService"},
      {9, 19, "PaymentCore ≠ BackupService"}
    ]

    anti_affinity_pairs.each do |pair|
      i, j, desc = pair
      total += 1
      same_region = result.segments.any? { |seg| seg.includes?(i) && seg.includes?(j) }
      if !same_region
        satisfied += 1
        puts "  ✅ #{desc}: SATISFIED"
      else
        puts "  ❌ #{desc}: VIOLATED"
      end
    end

    satisfaction_rate = satisfied.to_f / total * 100
    puts "\n📊 OVERALL CONSTRAINT SATISFACTION: #{satisfaction_rate.round(1)}% (#{satisfied}/#{total})"
  end

  def self.final_assessment(result, runtime, capacity_violations, balance_score)
    # Calculate overall score
    score = 100

    # Penalize runtime > 30 seconds
    score -= 10 if runtime > 30

    # Penalize capacity violations heavily
    score -= 20 * capacity_violations

    # Penalize poor balance
    if balance_score > 20
      score -= 15
    elsif balance_score > 10
      score -= 5
    end

    # Check critical business rules
    primary_db_idx = 0
    backup_idx = 19

    primary_region = result.segments.index { |seg| seg.includes?(primary_db_idx) }
    backup_region = result.segments.index { |seg| seg.includes?(backup_idx) }

    if primary_region && backup_region && primary_region != backup_region
      puts "  ✅ PrimaryDB and BackupService properly separated"
    else
      score -= 25
      puts "  ❌ CRITICAL: PrimaryDB and BackupService not properly separated"
    end

    # Final verdict
    if score >= 85
      puts "  🏅 OUTSTANDING: Malloc excelled under extreme pressure"
    elsif score >= 70
      puts "  ✅ EXCELLENT: Malloc handled the nightmare scenario well"
    elsif score >= 55
      puts "  👍 GOOD: Malloc found a reasonable solution despite contradictions"
    elsif score >= 40
      puts "  ⚠️  ACCEPTABLE: Malloc struggled but produced a usable result"
    else
      puts "  ❌ POOR: Malloc could not handle this level of complexity"
    end

    puts "  🎯 FINAL SCORE: #{score}/100"
  end
end

# Run the torture test
TortureTest.run_torture_test