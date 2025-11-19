require "../src/multiplicative_constraint"
require "../src/multiplicative_constraint/sat"

puts "📈 STOCK MARKET PATTERN FINDER (CASIMIR DIAGNOSTIC) 📉"
puts "======================================================"

# 1. Setup
# 20 Stocks
NUM_STOCKS = 20
stocks = (0...NUM_STOCKS).map { |i| "TICKER_#{i}" }

# 2. Simulate Market Conditions
# We will simulate 3 "Days": Normal, Bull Run, CRASH
days = ["Normal Market", "Bull Run", "CRASH EVENT"]

days.each do |market_condition|
  puts "\n📅 Analyzing: #{market_condition}..."
  
  # Generate Correlation Matrix based on condition
  # Normal: Random correlations
  # Bull: High positive correlations
  # Crash: EXTREME correlations (everything moves together) -> System becomes rigid
  
  clauses = Array(Array(Int32)).new
  
  num_clauses = 0
  case market_condition
  when "Normal Market"
    # Sparse, random connections
    num_clauses = 30
  when "Bull Run"
    # More connections, mostly positive
    num_clauses = 60
  when "CRASH EVENT"
    # Dense, rigid connections (Panic selling links everything)
    num_clauses = 200 
  end
  
  num_clauses.times do
    # Create a "Constraint" (Clause) between 3 random stocks
    # In SAT terms: (Stock A OR Stock B OR Stock C)
    # In Market terms: "These 3 stocks are coupled"
    clause = [
      (rand(NUM_STOCKS) + 1) * (rand > 0.5 ? 1 : -1),
      (rand(NUM_STOCKS) + 1) * (rand > 0.5 ? 1 : -1),
      (rand(NUM_STOCKS) + 1) * (rand > 0.5 ? 1 : -1)
    ]
    clauses << clause
  end
  
  # 3. Run Casimir Diagnostic
  # We treat the market as a SAT problem. 
  # If it's "Solvable" (High Variance), the market is healthy (diverse opinions).
  # If it's "Unsolvable" (Low Variance), the market is locked up (Crash imminent).
  
  solver = MultiplicativeConstraint::SATSolver.new(NUM_STOCKS, clauses)
  diag = solver.diagnostic(num_perturbations: 20)
  
  puts "   Spectral Variance: #{diag.variance}"
  puts "   System State: #{diag.recommendation}"
  
  if diag.variance < 1e10
    puts "   🚨 ALERT: PHASE TRANSITION DETECTED (CRASH IMMINENT) 🚨"
  else
    puts "   ✅ Market is Fluid."
  end
end
