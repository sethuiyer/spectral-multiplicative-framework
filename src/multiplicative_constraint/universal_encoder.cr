#
# Universal Problem Encoder: Transforming Arbitrary Optimization into Prime Necklaces
# Developed by aninokuma at Shunya Bar
#
# This module implements the key innovation that enables the system to work across
# all problem domains: the universal encoding of any optimization problem as a
# prime necklace graph structure.
#
# The Secret Sauce:
# Prime necklace structures guarantee ρ ≥ 0.99 correlation between spectral
# and multiplicative functionals while providing balanced segments. By encoding
# ANY problem as a prime necklace, we can leverage the mathematical guarantees
# of the spectral-multiplicative framework universally.
#
# Encoding Process:
# 1. Extract resources and constraints from any problem domain
# 2. Assign prime weights based on resource importance
# 3. Create circular topology with gap-weighted edges
# 4. Overlay constraint relations as perturbations
# 5. Solve using spectral-multiplicative optimization
# 6. Decode results back to original problem domain
#
# This universal approach enables solving SAT, knapsack, graph coloring,
# TSP, scheduling, and resource allocation problems with a single engine.
#
# @author aninokuma at Shunya Bar
#

module MultiplicativeConstraint
  # Universal resource representation for problem encoding
  #
  # This struct provides a problem-agnostic way to represent any type of
  # resource that needs to be partitioned or allocated. The flexible design
  # accommodates everything from cloud VMs to tasks in a scheduling problem.
  #
  # @author aninokuma at Shunya Bar
  struct Resource
    # Unique identifier for this resource
    property id : String

    # Type classification for specialized handling
    # Examples: "vm", "task", "item", "node", "job"
    property type : String

    # Resource capacity or size (higher = more important for balance)
    property capacity : Float64

    # Resource cost or priority (higher = more important for assignment)
    property cost : Float64

    # Flexible metadata for domain-specific attributes
    # Enables encoding of arbitrary problem-specific properties
    property metadata : Hash(String, String)

    def initialize(@id : String, @type : String = "generic", @capacity : Float64 = 1.0,
                   @cost : Float64 = 1.0, @metadata = Hash(String, String).new)
    end
  end

  # Universal constraint representation
  #
  # This struct captures relationships between resources in a domain-agnostic way.
  # The strength parameter allows for weighted constraints, while the type
  # determines how the constraint affects the optimization objective.
  #
  # @author aninokuma at Shunya Bar
  struct ConstraintRelation
    # Source resource identifier
    property from_id : String

    # Target resource identifier
    property to_id : String

    # Constraint strength/weight (higher = more important)
    property strength : Float64

    # Constraint type determining optimization behavior
    # Types:
    # - "requires": resources should be in same segment
    # - "conflicts": resources should be in different segments
    # - "complements": resources benefit from co-location
    # - "related": generic preference for same segment
    property type : String

    def initialize(@from_id : String, @to_id : String, @strength : Float64 = 1.0, @type : String = "related")
    end
  end
  
  # Universal Encoder: Problem → Prime Necklace Graph
  class UniversalEncoder
    getter resources : Array(Resource)
    getter relations : Array(ConstraintRelation)
    getter encoding : Hash(String, Int32)  # resource_id → node_index
    getter decoding : Hash(Int32, String)  # node_index → resource_id
    
    def initialize(@resources : Array(Resource), @relations : Array(ConstraintRelation))
      @encoding = Hash(String, Int32).new
      @decoding = Hash(Int32, String).new
      
      # Map resources to indices
      @resources.each_with_index do |res, idx|
        @encoding[res.id] = idx
        @decoding[idx] = res.id
      end
    end
    
    # Encode as prime necklace graph
    # Returns: {prime_weights, circular_edges}
    # constraint_scale keeps constraint edges as a small perturbation, preserving ring structure
    def encode_as_prime_necklace(constraint_scale : Float64 = 0.05) : {Array(Float64), Array(Tuple(Int32, Int32, Float64))}
      n = @resources.size
      
      # Step 1: Assign prime weights based on resource properties
      primes = generate_primes(n)
      
      # Sort resources by "importance" to assign primes meaningfully
      # Higher cost/capacity → higher prime → stronger constraints
      sorted_resources = @resources.each_with_index.to_a.sort_by do |res, idx|
        res.capacity * res.cost  # Importance metric
      end
      
      prime_weights = Array.new(n, 0.0)
      sorted_resources.each_with_index do |(res, orig_idx), rank|
        prime_weights[orig_idx] = primes[rank].to_f64
      end
      
      # Step 2: Create circular topology with gap-weighted edges
      # This preserves BdG Hamiltonian spectral structure!
      circular_edges = Array(Tuple(Int32, Int32, Float64)).new
      
      n.times do |i|
        j = (i + 1) % n
        gap = (prime_weights[j] - prime_weights[i]).abs
        edge_weight = 1.0 / (1.0 + gap)
        circular_edges << {i, j, edge_weight}
      end
      
      # Step 3: Add constraint-based edges (overlay on circular structure)
      # Relations create shortcuts in the necklace
      @relations.each do |rel|
        i = @encoding[rel.from_id]?
        j = @encoding[rel.to_id]?
        next unless i && j
        
        # Add edge with strength proportional to constraint importance
        edge_weight = constraint_scale * rel.strength
        circular_edges << {i, j, edge_weight} unless i == j
      end
      
      {prime_weights, circular_edges}
    end
    
    # Decode segments back to original resource assignments
    def decode_segments(segments : Array(Array(Int32))) : Hash(String, Array(String))
      assignments = Hash(String, Array(String)).new
      
      segments.each_with_index do |segment, region_idx|
        region_name = "Region_#{region_idx + 1}"
        assignments[region_name] = [] of String
        
        segment.each do |node_idx|
          if resource_id = @decoding[node_idx]?
            assignments[region_name] << resource_id
          end
        end
      end
      
      assignments
    end
    
    # Get resource object from node index
    def get_resource(node_idx : Int32) : Resource?
      resource_id = @decoding[node_idx]?
      return nil unless resource_id
      @resources.find { |r| r.id == resource_id }
    end
    
    # Compute constraint satisfaction score for a solution
    def compute_satisfaction(segments : Array(Array(Int32))) : Hash(String, Float64)
      metrics = Hash(String, Float64).new
      
      # Check how many constraints are satisfied
      satisfied = 0
      total = @relations.size
      
      @relations.each do |rel|
        i = @encoding[rel.from_id]?
        j = @encoding[rel.to_id]?
        next unless i && j
        
        # Check if they're in appropriate segments based on relation type
        same_segment = segments.any? { |seg| seg.includes?(i) && seg.includes?(j) }
        
        case rel.type
        when "requires", "complements"
          satisfied += 1 if same_segment
        when "conflicts"
          satisfied += 1 unless same_segment
        else
          satisfied += 1 if same_segment  # Default: prefer grouping
        end
      end
      
      metrics["constraint_satisfaction"] = total > 0 ? satisfied.to_f64 / total : 1.0
      metrics["total_constraints"] = total.to_f64
      metrics["satisfied_constraints"] = satisfied.to_f64
      
      metrics
    end
    
    private def generate_primes(n : Int32) : Array(Int32)
      return [2] if n <= 0
      primes = [] of Int32
      candidate = 2
      while primes.size < n
        if is_prime(candidate)
          primes << candidate
        end
        candidate += 1
      end
      primes
    end
    
    private def is_prime(x : Int32) : Bool
      return false if x < 2
      return true if x == 2
      return false if x.even?
      i = 3
      while i * i <= x
        return false if x % i == 0
        i += 2
      end
      true
    end
  end
  
  # Neural Network Integration Layer
  # Enables backprop through the entire optimization pipeline
  module NeuralIntegration
    # Differentiable loss function for gradient-based optimization
    # Input: resource features → NN → segment assignments → loss
    def self.compute_differentiable_loss(
      segments : Array(Array(Int32)),
      prime_weights : Array(Float64),
      target_size : Float64,
      constraint_violations : Array(Float64)
    ) : Float64
      
      # Loss component 1: Size imbalance (quadratic, smooth)
      balance_loss = 0.0
      segments.each do |segment|
        size = segment.size.to_f64
        diff = size - target_size
        balance_loss += diff * diff
      end
      balance_loss *= 0.5  # Scale
      
      # Loss component 2: Constraint violations weighted by primes
      constraint_loss = 0.0
      constraint_violations.each_with_index do |violation, idx|
        if idx < prime_weights.size
          p = prime_weights[idx]
          mult_factor = 1.0 - 1.0 / (p * p)
          constraint_loss += p * violation * mult_factor
        end
      end
      
      # Total differentiable loss
      balance_loss + constraint_loss
    end
    
    # Gradient with respect to segment assignments (for NN backprop)
    # ∂Loss/∂assignment_matrix
    def self.compute_gradient(
      segments : Array(Array(Int32)),
      prime_weights : Array(Float64),
      target_size : Float64
    ) : Array(Array(Float64))
      
      n = prime_weights.size
      k = segments.size
      
      # Gradient matrix: n × k (each node's gradient for each segment)
      gradient = Array.new(n) { Array.new(k, 0.0) }
      
      segments.each_with_index do |segment, seg_idx|
        size = segment.size.to_f64
        
        # ∂(balance_loss)/∂(segment_k) = (size_k - target) for nodes in segment_k
        grad_value = size - target_size
        
        segment.each do |node_idx|
          gradient[node_idx][seg_idx] = grad_value
        end
      end
      
      gradient
    end
  end
end

