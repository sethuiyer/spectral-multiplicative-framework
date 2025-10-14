require "./src/multiplicative_constraint"

module CustomTest
  include MultiplicativeConstraint

  # Cloud Resource Allocation Scenario
  # 20 services with varying importance and constraints

  SERVICES = [
    "Auth-API", "User-DB", "Cache-1", "Payment-GW", "Analytics",
    "Search-API", "Recommendations", "File-Storage", "Email-SVC", "Monitoring",
    "Logging", "Backup-SVC", "Load-Balancer", "Web-Frontend", "API-Gateway",
    "Queue-SVC", "Session-Store", "Metrics", "Alerting", "Config-SVC"
  ]

  # Service importance weights (higher = more important)
  # Prime numbers for the multiplicative constraint effect
  WEIGHTS = [
    47.0,  43.0,  37.0,  61.0,  29.0,   # Critical services
    31.0,  23.0,  19.0,  41.0,  53.0,   # High importance
    17.0,  13.0,  59.0,  67.0,  71.0,   # Medium-high
    11.0,   7.0,   5.0,   3.0,   2.0    # Lower priority
  ]

  # Create a realistic constraint matrix
  # Higher values = stronger preference for co-location
  # Negative values = anti-affinity (should be separated)
  def self.create_adjacency_matrix
    n = SERVICES.size
    matrix = Array.new(n) { Array(Float64).new(n, 0.0) }

    # Define realistic constraints:

    # 1. Service dependencies (positive adjacency)
    dependencies = [
      # Web stack dependencies
      {13, 14, 8.0},    # Web-Frontend <-> API-Gateway
      {14, 0, 7.0},     # API-Gateway <-> Auth-API
      {14, 3, 9.0},     # API-Gateway <-> Payment-GW
      {14, 5, 6.0},     # API-Gateway <-> Search-API

      # Database dependencies
      {1, 2, 5.0},      # User-DB <-> Cache-1
      {1, 16, 4.0},     # User-DB <-> Session-Store
      {7, 8, 3.0},      # File-Storage <-> Email-SVC

      # Monitoring stack
      {9, 17, 7.0},     # Monitoring <-> Metrics
      {9, 18, 8.0},     # Monitoring <-> Alerting
      {17, 18, 6.0},    # Metrics <-> Alerting
      {10, 11, 5.0},    # Logging <-> Backup-SVC
      {9, 10, 4.0},     # Monitoring <-> Logging

      # Infrastructure services
      {12, 13, 9.0},    # Load-Balancer <-> Web-Frontend
      {15, 2, 3.0},     # Queue-SVC <-> Cache-1
      {19, 0, 4.0},     # Config-SVC <-> Auth-API
    ]

    # Apply dependencies (symmetrically)
    dependencies.each do |i, j, weight|
      matrix[i][j] = weight
      matrix[j][i] = weight
    end

    # 2. Anti-affinity constraints (negative adjacency)
    anti_affinity = [
      # High-load services should be separated
      {3, 1, -6.0},     # Payment-GW away from User-DB
      {3, 7, -5.0},     # Payment-GW away from File-Storage
      {5, 4, -4.0},     # Search-API away from Analytics
      {1, 9, -3.0},     # User-DB away from Monitoring

      # Critical redundancy
      {0, 14, -2.0},    # Auth-API separate from API-Gateway (redundancy)
      {12, 13, -3.0},   # Load-Balancer separate from Web-Frontend
    ]

    # Apply anti-affinity constraints
    anti_affinity.each do |i, j, weight|
      matrix[i][j] = weight
      matrix[j][i] = weight
    end

    matrix
  end

  def self.run_test
    puts "🏗️  Cloud Resource Allocation Test"
    puts "=" * 50
    puts "Services: #{SERVICES.size}"
    puts "Target: 4 regions/cloud zones"
    puts "Constraints: #{count_constraints} co-location/anti-affinity rules"
    puts

    # Create adjacency matrix
    adj = create_adjacency_matrix

    # Initialize the engine
    graph = MultiplicativeConstraint::Graph.new(WEIGHTS, adj)
    engine = MultiplicativeConstraint::Engine.new(graph, 4,
      fairness_weight: 2.0,
      weight_fairness_weight: 1.0,
      entropy_weight: 0.2,
      penalty_weight: 1.5,
      cross_conflict_weight: 0.5
    )

    puts "Running optimization..."
    puts

    # Solve the partitioning problem
    result = engine.solve(iterations: 2000, step: 0.3, seed: 12345)

    # Generate and display results
    report = engine.report(result, SERVICES)
    puts report

    # Analyze specific business metrics
    analyze_solution(result)
  end

  def self.count_constraints
    adj = create_adjacency_matrix
    count = 0
    n = adj.size
    (0...n).each do |i|
      ((i+1)...n).each do |j|
        count += 1 if adj[i][j] != 0.0
      end
    end
    count
  end

  def self.analyze_solution(result)
    puts "\n📊 Business Analysis:"
    puts "-" * 30

    # Region sizes (should be balanced)
    region_sizes = result.segments.map(&.size)
    puts "Region distribution: #{region_sizes}"
    target_size = SERVICES.size / 4.0
    balance_score = region_sizes.reduce(0.0) { |sum, size| sum + (size - target_size)**2 }
    puts "Balance score (lower better): #{balance_score.round(2)}"

    # Total importance weight per region
    puts "\n🎯 Critical service distribution:"
    result.segments.each_with_index do |segment, idx|
      total_weight = segment.sum { |i| WEIGHTS[i] }
      critical_count = segment.count { |i| WEIGHTS[i] >= 40.0 }
      puts "  Region #{idx + 1}: #{total_weight.round(0)} total weight, #{critical_count} critical services"
    end

    # Cross-region dependencies (should be minimized)
    puts "\n🔗 Cross-region dependencies: #{result.cross_conflict.round(1)}"

    # Energy breakdown
    puts "\n⚡ Energy Components:"
    puts "  Spectral action: #{result.spectral.round(1)}"
    puts "  Fairness penalty: #{result.fairness.round(2)}"
    puts "  Entropy bonus: #{result.entropy.round(3)}"
    puts "  Multiplicative penalty: #{result.penalty.round(3)}"
    puts "  Total energy: #{result.energy.round(1)}"
  end
end

# Run the test
CustomTest.run_test