# Dynamic Prime Weight Assignment for Constraints
# Key insight: Violated constraints get higher primes → multiplicative penalty amplification
# Enables neural network backprop on differentiable loss

module MultiplicativeConstraint
  # Constraint violation tracking and prime weight assignment
  class ConstraintWeights
    getter constraints : Array(Constraint)
    getter primes : Array(Int32)
    
    def initialize(num_constraints : Int32)
      @constraints = Array.new(num_constraints) { Constraint.new }
      @primes = generate_primes(num_constraints)
    end
    
    # Update violations and reassign prime weights
    # More violated → higher prime index → stronger multiplicative penalty
    def update_violations!(violations : Array(Float64))
      raise "Size mismatch" unless violations.size == @constraints.size
      
      # Update each constraint's violation score
      violations.each_with_index do |v, i|
        @constraints[i].violation = v
      end
      
      # Sort constraints by violation (ascending)
      sorted_indices = @constraints.each_with_index.to_a.sort_by { |c, i| c.violation }.map { |_, i| i }
      
      # Assign primes: most violated gets largest prime
      sorted_indices.each_with_index do |orig_idx, rank|
        prime_idx = @primes.size - 1 - rank  # Reverse: largest violation → largest prime
        @constraints[orig_idx].prime_weight = @primes[prime_idx].to_f64
      end
    end
    
    # Get current weight vector for optimization
    def weight_vector : Array(Float64)
      @constraints.map(&.prime_weight)
    end
    
    # Compute differentiable loss (for neural network backprop)
    # Loss = Σ_i prime_i × violation_i × multiplicative_factor_i
    def differentiable_loss(violations : Array(Float64)) : Float64
      total_loss = 0.0
      
      violations.each_with_index do |v, i|
        prime_weight = @constraints[i].prime_weight
        # Multiplicative amplification: (1 - 1/p²) ≈ 1 for large p
        mult_factor = 1.0 - 1.0 / (prime_weight * prime_weight)
        total_loss += prime_weight * v * mult_factor
      end
      
      total_loss
    end
    
    # Neural network compatible gradient (∂Loss/∂violation_i)
    def gradient : Array(Float64)
      @constraints.map do |c|
        p = c.prime_weight
        mult_factor = 1.0 - 1.0 / (p * p)
        p * mult_factor
      end
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
  
  # Single constraint with violation tracking
  class Constraint
    property violation : Float64
    property prime_weight : Float64
    property name : String
    property type : String
    
    def initialize(@name : String = "", @type : String = "generic")
      @violation = 0.0
      @prime_weight = 2.0  # Start with smallest prime
    end
    
    # Satisfaction score (0 = fully violated, 1 = fully satisfied)
    def satisfaction : Float64
      1.0 / (1.0 + @violation)
    end
    
    # Penalty contribution to objective
    def penalty : Float64
      mult_factor = 1.0 - 1.0 / (@prime_weight * @prime_weight)
      @violation * mult_factor
    end
  end
  
  # Example constraint types for malloc
  module ConstraintTypes
    # Graph constraint: connectivity/topology requirements
    class GraphConstraint < Constraint
      property required_edges : Array(Tuple(Int32, Int32))
      property max_diameter : Float64
      
      def initialize(@required_edges = [] of Tuple(Int32, Int32), @max_diameter = Float64::INFINITY)
        super(name: "graph", type: "connectivity")
      end
      
      # Compute violation based on missing edges + diameter
      def compute_violation(segments : Array(Array(Int32)), adjacency) : Float64
        missing = 0.0
        @required_edges.each do |i, j|
          # Check if i and j are in same segment
          same_segment = segments.any? { |seg| seg.includes?(i) && seg.includes?(j) }
          missing += 1.0 unless same_segment
        end
        missing
      end
    end
    
    # Logical constraint: boolean rules (SAT-style)
    class LogicalConstraint < Constraint
      property clauses : Array(Array(Int32))
      
      def initialize(@clauses = [] of Array(Int32))
        super(name: "logical", type: "boolean")
      end
      
      def compute_violation(assignment : Array(Bool)) : Float64
        unsatisfied = 0.0
        @clauses.each do |clause|
          satisfied = clause.any? { |lit| assignment[lit.abs] == (lit > 0) }
          unsatisfied += 1.0 unless satisfied
        end
        unsatisfied
      end
    end
    
    # Arithmetic constraint: budget/capacity limits
    class ArithmeticConstraint < Constraint
      property max_value : Float64
      property min_value : Float64
      
      def initialize(@max_value = Float64::INFINITY, @min_value = -Float64::INFINITY)
        super(name: "arithmetic", type: "capacity")
      end
      
      def compute_violation(actual_value : Float64) : Float64
        if actual_value > @max_value
          actual_value - @max_value
        elsif actual_value < @min_value
          @min_value - actual_value
        else
          0.0
        end
      end
    end
    
    # Balance constraint: segment size fairness
    class BalanceConstraint < Constraint
      property target_size : Float64
      property tolerance : Float64
      
      def initialize(@target_size : Float64, @tolerance : Float64 = 0.2)
        super(name: "balance", type: "fairness")
      end
      
      def compute_violation(actual_size : Float64) : Float64
        diff = (actual_size - @target_size).abs
        threshold = @target_size * @tolerance
        diff > threshold ? (diff - threshold) : 0.0
      end
    end
  end
end

