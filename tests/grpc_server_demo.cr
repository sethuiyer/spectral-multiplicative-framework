require "grpc"
require "protobuf"
require "./multiplicative_constraint"
# Note: These files must be generated using protoc
# protoc -I proto --crystal_out=src/proto proto/optimization_service.proto
require "./proto/optimization_service.pb"
require "./proto/optimization_service_services.pb"

module Spectral
  class OptimizationServiceImpl < OptimizationService::Service
    def solve(request : GraphRequest) : PartitionResponse
      puts "[gRPC] Received Solve request with #{request.node_weights.size} nodes"
      
      # 1. Reconstruct Graph
      weights = request.node_weights.to_a
      
      # Convert proto edges to framework format
      edge_types = Hash(String, MultiplicativeConstraint::SparseMatrix).new
      
      # Group edges by type
      edges_by_type = Hash(String, Array(Tuple(Int32, Int32, Float64))).new
      
      request.edges.each do |edge|
        type = edge.type.empty? ? "default" : edge.type
        edges_by_type[type] ||= Array(Tuple(Int32, Int32, Float64)).new
        edges_by_type[type] << {edge.source, edge.target, edge.weight}
      end
      
      # Build sparse matrices
      num_nodes = weights.size
      edges_by_type.each do |type, edge_list|
        edge_types[type] = MultiplicativeConstraint::SparseMatrix.from_edges(num_nodes, num_nodes, edge_list)
      end
      
      # Create Graph
      graph = MultiplicativeConstraint::Graph.new(weights, edge_types)
      
      # 2. Configure Engine
      segments = request.segments > 0 ? request.segments : 2
      
      engine = MultiplicativeConstraint::Engine.new(
        graph,
        segments: segments,
        fairness_weight: request.fairness_weight > 0 ? request.fairness_weight : 1.0,
        penalty_weight: request.penalty_weight > 0 ? request.penalty_weight : 1.0,
        calibrate: true
      )
      
      # 3. Solve
      puts "[gRPC] Calibrating and solving..."
      engine.calibrate!(samples: 64)
      result = engine.solve(iterations: request.iterations > 0 ? request.iterations : 1000)
      
      # 4. Return Response
      PartitionResponse.new(
        assignments: result.discrete_solution,
        energy: result.energy,
        spectral_energy: result.spectral,
        fairness_score: result.fairness,
        success: true
      )
    rescue ex
      puts "[gRPC] Error: #{ex.message}"
      PartitionResponse.new(success: false)
    end

    def diagnose(request : DiagnosticRequest) : DiagnosticResponse
      puts "[gRPC] Received Diagnostic request for #{request.num_variables} variables"
      
      # Convert proto clauses to framework format
      clauses = request.clauses.map do |c|
        c.literals.to_a
      end
      
      solver = MultiplicativeConstraint::SATSolver.new(request.num_variables, clauses)
      diag = solver.diagnostic
      
      DiagnosticResponse.new(
        solvable: diag.predicted_solvable,
        confidence: diag.confidence,
        variance: diag.variance,
        recommendation: diag.recommendation
      )
    end
  end
end

def main
  port = 50051
  server = GRPC::Server.new
  server.bind_tcp("0.0.0.0", port)
  
  # Register service
  server.register(Spectral::OptimizationServiceImpl.new)
  
  puts "🔮 Spectral Optimization Engine listening on port #{port}"
  server.run
end

main
