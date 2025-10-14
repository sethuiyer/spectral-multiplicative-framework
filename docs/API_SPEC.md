# MultiplicativeConstraint API Specification

## Overview

MultiplicativeConstraint is a Crystal library implementing a sophisticated heat-kernel spectral optimization engine for constraint partitioning problems. It combines spectral methods, sparse linear algebra, and simulated annealing to achieve ρ ≥ 0.99 correlation between spectral and multiplicative functionals.

**Version**: 0.1.0
**License**: Restricted
**Author**: sethuiyer
**Homepage**: https://github.com/sethuiyer/prime-annealer

## Core Concepts

### Spectral-Multiplicative Framework

The library implements a unified optimization framework combining:
- **Heat-kernel spectral action** for global graph structure analysis
- **Multiplicative prime weight constraints** for violation amplification
- **Sparse matrix operations** for enterprise-scale efficiency
- **Simulated annealing** for robust optimization in angular space

### Key Innovations

1. **Angular Parameterization**: Continuous optimization in [0, 2π) space maps to discrete segment assignments
2. **Adaptive Calibration**: Automatic weight tuning via ergodic sampling
3. **Correlation Guard**: Maintains mathematical validity (ρ ≥ 0.99) during optimization
4. **Sparse Memory Efficiency**: O(nnz) memory instead of O(N²) for large graphs

## Main API

### MultiplicativeConstraint::Engine

The primary interface for constraint partitioning optimization.

#### Constructor

```crystal
def initialize(
  @graph : Graph,
  @segments : Int32,
  fairness_weight : Float64 = 1.0,
  weight_fairness_weight : Float64 = 0.5,
  entropy_weight : Float64 = 0.1,
  penalty_weight : Float64 = 1.0,
  cross_conflict_weight : Float64 = 0.0,
  calibrate : Bool = false,
  calibration_samples : Int32 = 128,
  enable_corr_guard : Bool = false,
  corr_min : Float64 = 0.99,
  guard_window : Int32 = 16,
  guard_period : Int32 = 50,
  guard_lambda : Float64 = 1.0,
  sampler_seed : Int32 = 777
)
```

**Parameters**:
- `graph`: Graph structure containing adjacency matrix and weights
- `segments`: Number of desired segments (k) - must be positive
- `fairness_weight`: Weight for size balance penalty (default: 1.0)
- `weight_fairness_weight`: Weight for weight distribution fairness (default: 0.5)
- `entropy_weight`: Weight for Shannon entropy term (default: 0.1)
- `penalty_weight`: Weight for multiplicative prime penalty (default: 1.0)
- `cross_conflict_weight`: Weight for edge cut minimization (default: 0.0)
- `calibrate`: Enable automatic weight calibration (default: false)
- `calibration_samples`: Number of samples for calibration (default: 128)
- `enable_corr_guard`: Enable correlation monitoring (default: false)
- `corr_min`: Minimum acceptable correlation (default: 0.99)
- `guard_window`: Window size for correlation computation (default: 16)
- `guard_period`: Frequency of correlation checks (default: 50)
- `guard_lambda`: Penalty strength for correlation violations (default: 1.0)
- `sampler_seed`: Random seed for reproducible sampling (default: 777)

**Raises**: `ArgumentError` if segments is not positive

#### Methods

##### solve()
```crystal
def solve(iterations = 2000, step = 0.35, seed = 42) : PartitionResult
```

Execute optimization using simulated annealing.

**Parameters**:
- `iterations`: Number of annealing iterations (default: 2000)
- `step`: Initial step size for angular perturbations (default: 0.35)
- `seed`: Random seed for reproducible results (default: 42)

**Returns**: `PartitionResult` containing optimal solution and metrics

##### evaluate()
```crystal
def evaluate(alpha : FloatArray) : Float64
```

Evaluate unified energy for a given angular configuration.

**Parameters**:
- `alpha`: Angular configuration in [0, 2π) space

**Returns**: Unified energy value combining all objective terms

##### report()
```crystal
def report(result : PartitionResult, payload_names : Array(String)) : String
```

Generate formatted report for optimization result.

**Parameters**:
- `result`: Result from solve() method
- `payload_names`: Human-readable names for graph nodes

**Returns**: Formatted string report

---

### MultiplicativeConstraint::Graph

Represents graph structure with support for both dense and sparse representations.

#### Constructors

##### Dense Adjacency Constructor
```crystal
def initialize(
  @weights : Array(Float64),
  dense_adjacency : Array(Array(Float64))
)
```

**Parameters**:
- `weights`: Array of node weights
- `dense_adjacency`: Square adjacency matrix

##### Sparse Edge Constructor
```crystal
def initialize(
  @weights : Array(Float64),
  @edges : Array(Tuple(Int32, Int32, Float64))
)
```

**Parameters**:
- `weights`: Array of node weights
- `edges`: Array of (source, target, weight) tuples

##### from_edges()
```crystal
def self.from_edges(
  weights : Array(Float64),
  edges : Array(Tuple(Int32, Int32, Float64)),
  symmetric : Bool = true
) : Graph
```

Create graph from edge list with automatic symmetry handling.

**Parameters**:
- `weights`: Array of node weights
- `edges`: Edge list tuples
- `symmetric`: Add reverse edges for undirected graphs (default: true)

**Returns**: New Graph instance

#### Methods

##### size()
```crystal
def size : Int32
```
Returns number of nodes in the graph.

##### adjacency_value()
```crystal
def adjacency_value(i : Int32, j : Int32) : Float64
```
Get adjacency value between nodes i and j.

##### degree()
```crystal
def degree(i : Int32) : Float64
```
Get degree of node i.

##### to_sparse!()
```crystal
def to_sparse! : Nil
```
Convert graph to sparse representation.

##### to_dense!()
```crystal
def to_dense! : Nil
```
Convert graph to dense representation (memory intensive).

##### memory_usage()
```crystal
def memory_usage : String
```
Get memory usage statistics.

---

### MultiplicativeConstraint::PartitionResult

Immutable result structure containing optimization metrics.

#### Properties

```crystal
getter alpha : FloatArray                    # Continuous angular parameters
getter energy : Float64                     # Unified energy objective
getter spectral : Float64                   # Heat-kernel spectral action
getter fairness : Float64                   # Size fairness penalty
getter weight_fairness : Float64            # Weight fairness penalty
getter entropy : Float64                    # Shannon entropy
getter penalty : Float64                    # Multiplicative penalty
getter cross_conflict : Float64             # Edge cut weight
getter segments : Array(Array(Int32))       # Discrete segment assignments
```

---

### MultiplicativeConstraint::Energy

Core energy function implementing the spectral-multiplicative framework.

#### Methods

##### unified()
```crystal
def unified(alpha : Array(Float64)) : Float64
```
Compute unified energy objective.

##### spectral()
```crystal
def spectral(alpha : Array(Float64)) : Float64
```
Compute heat-kernel spectral action term.

##### count_fairness()
```crystal
def count_fairness(alpha : Array(Float64)) : Float64
```
Compute size fairness penalty.

##### weight_fairness()
```crystal
def weight_fairness(alpha : Array(Float64)) : Float64
```
Compute weight distribution fairness penalty.

##### entropy()
```crystal
def entropy(alpha : Array(Float64)) : Float64
```
Compute Shannon entropy of segment distribution.

##### penalty()
```crystal
def penalty(alpha : Array(Float64)) : Float64
```
Compute multiplicative prime penalty term.

##### cross_conflict()
```crystal
def cross_conflict(alpha : Array(Float64)) : Float64
```
Compute cross-segment edge cut weight.

##### segments()
```crystal
def segments(alpha : Array(Float64)) : Array(Array(Int32))
```
Extract discrete segment assignments.

##### correlation()
```crystal
def correlation(samples : Int32 = 64) : Float64
```
Compute Pearson correlation between spectral and multiplicative functionals.

##### calibrate!()
```crystal
def calibrate!(samples : Int32 = 128) : Nil
```
Calibrate weights via ergodic sampling to maximize correlation.

##### enable_correlation_guard!()
```crystal
def enable_correlation_guard!(
  rho_min : Float64 = 0.99,
  window : Int32 = 16,
  period : Int32 = 50,
  sampler_seed : Int32 = 777,
  lambda : Float64 = 1.0
) : Nil
```
Enable correlation monitoring during optimization.

---

### MultiplicativeConstraint::Annealer

Simulated annealing optimizer for continuous angular space.

#### Constructor
```crystal
def initialize(@energy : Energy)
```

#### Methods

##### minimize()
```crystal
def minimize(
  blocks : Int32,
  iterations = 1500,
  step = 0.35,
  seed = 42
) : Tuple(Array(Float64), Float64)
```

Execute simulated annealing optimization.

**Parameters**:
- `blocks`: Number of angular parameters (segments)
- `iterations`: Number of annealing iterations (default: 1500)
- `step`: Initial step size for perturbations (default: 0.35)
- `seed`: Random seed (default: 42)

**Returns**: Tuple of [best_alpha, best_energy]

---

### MultiplicativeConstraint::SparseMatrix

Compressed Sparse Row (CSR) format matrix for large-scale optimization.

#### Constructor
```crystal
def initialize(@rows : Int32, @cols : Int32)
```

#### Class Methods

##### from_edges()
```crystal
def self.from_edges(
  rows : Int32,
  cols : Int32,
  edges : Array(Tuple(Int32, Int32, Float64))
) : SparseMatrix
```
Build sparse matrix from edge list.

##### from_dense()
```crystal
def self.from_dense(dense : Array(Array(Float64))) : SparseMatrix
```
Build sparse matrix from dense matrix.

#### Methods

##### []()
```crystal
def [](i : Int32, j : Int32) : Float64
```
Get value at position (i, j).

##### multiply()
```crystal
def multiply(x : Array(Float64)) : Array(Float64)
```
Sparse matrix-vector multiplication: y = A * x.

##### get_row()
```crystal
def get_row(i : Int32) : Array(Tuple(Int32, Float64))
```
Get row i as sparse representation.

##### degree()
```crystal
def degree(i : Int32) : Float64
```
Get degree (row sum) of row i.

##### nnz()
```crystal
def nnz : Int32
```
Number of non-zero elements.

##### to_dense()
```crystal
def to_dense : Array(Array(Float64))
```
Convert to dense matrix (memory intensive).

##### memory_usage()
```crystal
def memory_usage : Int64
```
Memory usage in bytes.

##### stats()
```crystal
def stats : String
```
Print matrix statistics.

---

### MultiplicativeConstraint::SparseVector

Vector operations module for sparse computations.

#### Methods

##### dot()
```crystal
def self.dot(a : Array(Float64), b : Array(Float64)) : Float64
```
Dot product of two vectors.

##### norm()
```crystal
def self.norm(v : Array(Float64)) : Float64
```
L2 norm of vector.

##### normalize()
```crystal
def self.normalize(v : Array(Float64)) : Array(Float64)
```
Normalize vector to unit length.

##### add()
```crystal
def self.add(a : Array(Float64), b : Array(Float64)) : Array(Float64)
```
Vector addition: a + b.

##### subtract()
```crystal
def self.subtract(a : Array(Float64), b : Array(Float64)) : Array(Float64)
```
Vector subtraction: a - b.

##### scale()
```crystal
def self.scale(v : Array(Float64), scalar : Float64) : Array(Float64)
```
Scalar multiplication: scalar * v.

##### axpy()
```crystal
def self.axpy(
  a : Float64,
  x : Array(Float64),
  b : Float64,
  y : Array(Float64)
) : Array(Float64)
```
Linear combination: a * x + b * y.

---

### MultiplicativeConstraint::ErgodicSampler

Quasi-periodic sampler on k-torus for alpha proposals.

#### Constructor
```crystal
def initialize(@k : Int32, @seed : Int32 = 777)
```

#### Methods

##### next_alpha()
```crystal
def next_alpha : Array(Float64)
```
Generate next alpha configuration in [0, 2π) space.

---

### MultiplicativeConstraint::Weights

Prime number weight utilities for constraint optimization.

#### Methods

##### sieve()
```crystal
def sieve(limit : Int32) : Array(Float64)
```
Generate prime numbers up to limit using Sieve of Eratosthenes.

##### assign()
```crystal
def assign(count : Int32, scale : Array(Float64) = Array(Float64).new) : Array(Float64)
```
Assign prime weights with optional scaling factors.

---

### MultiplicativeConstraint::Report

Report generation module for optimization results.

#### Methods

##### generate()
```crystal
def generate(result : PartitionResult, labels : Array(String)) : String
```
Generate human-readable report showing segment assignments and energy metrics.

## Usage Examples

### Basic Graph Partitioning

```crystal
require "multiplicative_constraint"

# Define graph structure
weights = [12.0, 15.0, 17.0, 10.0, 8.0, 22.0]
adjacency = [
  [0.0, 2.0, 1.0, 0.0, 0.0, 4.0],
  [2.0, 0.0, 3.5, 1.0, 0.0, 2.0],
  [1.0, 3.5, 0.0, 0.0, 1.0, 0.5],
  [0.0, 1.0, 0.0, 0.0, 2.3, 0.0],
  [0.0, 0.0, 1.0, 2.3, 0.0, 1.2],
  [4.0, 2.0, 0.5, 0.0, 1.2, 0.0],
]
labels = ["TaskA", "TaskB", "TaskC", "TaskD", "TaskE", "TaskF"]

# Create graph and engine
graph = MultiplicativeConstraint::Graph.new(weights, adjacency)
engine = MultiplicativeConstraint::Engine.new(graph, 3)

# Solve optimization
result = engine.solve(iterations: 1500, step: 0.35, seed: 2025)

# Generate report
puts MultiplicativeConstraint::Report.generate(result, labels)
```

### Sparse Graph for Large-Scale Problems

```crystal
# Define sparse graph using edge list
weights = Array.new(100000) { |i| (i + 1).to_f64 }
edges = Array(Tuple(Int32, Int32, Float64)).new

# Add edges (example: random sparse graph)
1000.times do
  i = rand(100000)
  j = rand(100000)
  weight = rand(1.0..10.0)
  edges << {i, j, weight} if i != j
end

# Create sparse graph
graph = MultiplicativeConstraint::Graph.from_edges(weights, edges, symmetric: true)
engine = MultiplicativeConstraint::Engine.new(graph, 10, calibrate: true)

# Solve with correlation guard enabled
result = engine.solve(iterations: 5000, enable_corr_guard: true)
```

### Advanced Configuration with Calibration

```crystal
# Create engine with custom weights and calibration
engine = MultiplicativeConstraint::Engine.new(
  graph,
  segments = 5,
  fairness_weight: 2.0,
  entropy_weight: 0.2,
  penalty_weight: 1.5,
  calibrate: true,
  calibration_samples: 256,
  enable_corr_guard: true,
  corr_min: 0.995
)

# Solve with custom parameters
result = engine.solve(
  iterations: 3000,
  step: 0.25,
  seed: 12345
)

# Evaluate different configurations
energy = engine.evaluate(result.alpha)
puts "Unified energy: #{energy}"
```

## Mathematical Framework

### Unified Energy Function

The optimization objective combines multiple energy components:

```
E_unified = E_spectral + w_fairness*E_fairness + w_weight*E_weight_fairness
          - w_entropy*E_entropy - w_penalty*E_multiplicative + w_cross*E_cross
```

Where:
- `E_spectral`: Heat-kernel spectral action via trace(exp(-tL))
- `E_fairness`: Size balance penalty (quadratic variance)
- `E_weight_fairness`: Weight distribution fairness
- `E_entropy`: Shannon entropy for diversity
- `E_multiplicative`: Prime weight constraint penalty
- `E_cross`: Cross-segment edge cut weight

### Angular Parameterization

Optimization occurs in continuous angular space α ∈ [0, 2π)^k:

1. Angular cuts map to discrete segment boundaries
2. Smooth gradient-free exploration via Gaussian perturbations
3. 2π periodicity enables wraparound optimization

### Correlation Guard

Maintains mathematical validity by ensuring ρ ≥ 0.99 correlation between:
- Composite energy (spectral + balance + entropy + penalty)
- Multiplicative functional (base × multiplicative_factor)

## Performance Characteristics

### Memory Efficiency

- **Dense matrices**: O(N²) memory (suitable for N < 10K)
- **Sparse matrices**: O(nnz) memory (suitable for N > 10K)
- **Typical reduction**: 3,478x memory savings for 100K nodes

### Time Complexity

- **Energy evaluation**: O(nnz) for sparse graphs
- **Annealing iteration**: O(nnz × iterations)
- **Calibration**: O(samples × nnz)

### Scalability Limits

- **Recommended nodes**: ≤ 100K for production use
- **Optimal segments**: 2-10 for most problems
- **Annealing iterations**: 1,500-5,000 for convergence

## Error Handling

### Common Exceptions

- `ArgumentError`: Invalid parameters (negative segments, dimension mismatches)
- `IndexError`: Out-of-bounds access in sparse operations
- Memory errors for extremely large dense matrices

### Validation

- All constructors validate input dimensions
- Sparse matrices handle out-of-bounds gracefully (return 0.0)
- Engine initialization validates segment count positivity

## Dependencies

- **Crystal**: >= 1.8, < 2.0
- **Standard library**: Array, Math, Random, Set
- **No external dependencies**: Pure Crystal implementation

## License

Restricted License - see LICENSE file for details.

## Contributing

Please refer to the project repository for contribution guidelines.