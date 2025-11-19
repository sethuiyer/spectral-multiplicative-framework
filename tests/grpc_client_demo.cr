require "grpc"
require "protobuf"
# Note: These files must be generated using protoc
require "./proto/optimization_service.pb"
require "./proto/optimization_service_services.pb"

def run_client
  channel = GRPC::Client.new("localhost", 50051)
  stub = Spectral::OptimizationService::Stub.new(channel)

  puts "🔌 Connecting to Spectral Engine..."

  # 1. Test Solve (Graph Partitioning)
  puts "\n[1] Testing Graph Partitioning..."
  
  # Create a simple triangle graph
  edges = [
    Spectral::Edge.new(source: 0, target: 1, weight: 10.0, type: "love"),
    Spectral::Edge.new(source: 1, target: 2, weight: 10.0, type: "love"),
    Spectral::Edge.new(source: 2, target: 0, weight: -5.0, type: "hate")
  ]
  
  request = Spectral::GraphRequest.new(
    node_weights: [1.0, 1.0, 1.0],
    edges: edges,
    segments: 2,
    fairness_weight: 1.0,
    penalty_weight: 2.0,
    iterations: 500
  )
  
  response = stub.solve(request)
  
  if response.success
    puts "✅ Solve Successful!"
    puts "   Energy: #{response.energy}"
    puts "   Assignments: #{response.assignments}"
  else
    puts "❌ Solve Failed"
  end

  # 2. Test Diagnostic (SAT)
  puts "\n[2] Testing Casimir Diagnostic..."
  
  # Simple SAT problem: (x1 OR x2) AND (NOT x1 OR x2)
  clauses = [
    Spectral::Clause.new(literals: [1, 2]),
    Spectral::Clause.new(literals: [-1, 2])
  ]
  
  diag_req = Spectral::DiagnosticRequest.new(
    num_variables: 2,
    clauses: clauses
  )
  
  diag_res = stub.diagnose(diag_req)
  
  puts "✅ Diagnostic Complete!"
  puts "   Solvable: #{diag_res.solvable}"
  puts "   Confidence: #{diag_res.confidence}"
  puts "   Recommendation: #{diag_res.recommendation}"
end

run_client
