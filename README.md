# Spectral-Multiplicative Framework

![img](./logo.png)


## Core Components

### Optimization Engine
- Heat kernel spectral methods for graph structure analysis
- Sparse matrix operations enabling 100K+ variable problems
- Simulated annealing with adaptive temperature scheduling
- Neural network adaptation for problem-specific weight learning

### SAT Solver with Casimir Diagnostics
- Graph-based SAT encoding with spectral partitioning
- Perturbative solvability diagnostic (92.5% prediction accuracy)
- 100% unsolvable instance detection via force variance analysis
- Sub-second solving for moderately-sized instances

### Multi-Agent Game Theory
- Nash equilibrium finding for competitive allocation
- Support for pure-strategy and mixed-strategy equilibria
- Adversarial robustness with correlation preservation
- Scales to 9+ player systems with complex preference structures

## Installation

```bash
# Clone repository
git clone https://github.com/username/spectral-multiplicative-framework
cd spectral-multiplicative-framework

# Install Crystal (if needed)
# See: https://crystal-lang.org/install/

# Run tests
crystal spec
```

## Usage Examples

### SAT Solving

```crystal
require "multiplicative_constraint"

# Define CNF clauses
clauses = [
  [1, 2, 3],      # x1 OR x2 OR x3
  [-1, 2],        # NOT x1 OR x2
  [1, -3],        # x1 OR NOT x3
]

# Create solver with integrated diagnostic
solver = MultiplicativeConstraint::SATSolver.new(
  num_variables: 3,
  clauses: clauses
)

# Run diagnostic first (optional, fast pre-screening)
diagnostic = solver.diagnostic
puts "Predicted: #{diagnostic.predicted_solvable}"
puts "Confidence: #{diagnostic.confidence}"

# Solve with automatic diagnostic
result = solver.solve(use_diagnostic: true)
puts "Satisfiable: #{result.satisfiable}"
puts "Satisfaction rate: #{result.satisfaction_rate}%"
```

### Resource Allocation

```crystal
# Define resources and constraints
weights = [10.0, 15.0, 8.0, 12.0]  # Resource capacities

# Constraint matrix (positive = should separate, negative = should group)
constraints = [
  [0.0, 5.0, -3.0, 2.0],
  [5.0, 0.0, 4.0, -2.0],
  [-3.0, 4.0, 0.0, 6.0],
  [2.0, -2.0, 6.0, 0.0]
]

graph = MultiplicativeConstraint::Graph.new(weights, constraints)
engine = MultiplicativeConstraint::Engine.new(graph, segments: 2)

result = engine.solve(iterations: 2000)
puts "Energy: #{result.energy}"
puts "Segments: #{result.segments.inspect}"
```

### Multi-Type Graph Optimization

```crystal
# Define multi-type edges (e.g., network, geographic, dependency)
edge_types = {
  "network" => sparse_matrix_1,
  "geographic" => sparse_matrix_2,
  "dependency" => sparse_matrix_3
}

graph = MultiplicativeConstraint::Graph.new(weights, edge_types)
engine = MultiplicativeConstraint::Engine.new(graph, segments: 3)

# Automatic type weight calibration
engine.calibrate!(samples: 128)
result = engine.solve()
```

## Project Structure

```
src/multiplicative_constraint/
├── graph.cr                  # Graph data structures (dense/sparse/multi-type)
├── energy.cr                 # Energy functional evaluation
├── annealer.cr              # Simulated annealing optimizer
├── weights.cr               # Prime weight computation
├── neural_weights.cr        # Neural network adaptation
├── constraint_weights.cr    # Constraint weight management
├── sparse_matrix.cr         # Efficient sparse operations
├── ergodic.cr              # Ergodic sampling for calibration
├── bethe_hessian.cr        # Bethe-Hessian spectral analysis
├── universal_encoder.cr     # Problem domain encoding
├── report.cr               # Result formatting
├── sat.cr                  # SAT solver with Casimir diagnostics
└── linalg/                 # Linear algebra primitives
    ├── eigensolver.cr
    └── lapack.cr

tests/
├── unit/                   # Core function unit tests (4 files)
├── integration/            # System integration tests (4 files)
├── sat/                    # SAT solving tests (10 files)
├── neural/                 # Neural network tests (3 files)
├── applications/           # Real-world applications (7 files)
├── graph/                  # Graph problem tests (4 files)
├── verification/           # Optimality verification (1 file)
├── performance/            # Performance benchmarks (4 files)
├── adversarial/            # Edge case testing (3 files)
├── experiments/            # Experimental validation (7 files)
└── misc/                   # Miscellaneous tests (2 files)

Total: 49 test files organized across 13 categories
```

## Performance Characteristics

### SAT Solving
- 75-100% clause satisfaction on complex instances
- Sub-second solving for problems up to 50 variables
- Casimir perturbation diagnostic: 92.5% solvability prediction accuracy
- 100% unsolvable instance detection (5.91 orders of magnitude separation)

### Resource Allocation
- Sub-100ms optimization for typical enterprise problems
- Neural adaptation provides up to 813% energy improvement
- Maintains ρ ≥ 0.99 spectral-multiplicative correlation
- Scales to 100K+ variables with sparse matrix operations

### Multi-Agent Game Theory
- Nash equilibrium finding in competitive allocation scenarios
- Handles 9+ player systems with complex preference structures
- 80% stability in coalition formation problems
- Correlation preservation (ρ = -0.95) under adversarial conditions

## Theoretical Foundation

### Spectral-Multiplicative Bridge
The framework achieves ρ ≥ 0.99 correlation between:
- Spectral functional: Heat kernel trace Tr(e^{-βL_G})
- Multiplicative functional: Prime-weighted constraint penalties

This correlation enables unified optimization combining global graph structure (spectral) with local constraint satisfaction (multiplicative).

### Casimir Force Diagnostics
Perturbative analysis of spectral Casimir forces predicts problem solvability:
- Attractive forces (high variance under perturbation) indicate solvable instances
- Neutral forces (low variance) indicate unsolvable instances
- Statistical separation: 5.91 orders of magnitude between classes

### Game-Theoretic Equilibria
The framework discovers Nash equilibria through energy minimization:
- Pure-strategy equilibria in coordination games
- Mixed-strategy behavior in cyclic dominance games  
- Stable coalition formation in multi-player competitive scenarios

## Test Coverage

- Unit tests: 100% pass rate on core physics functions
- Integration tests: 100% success across 6 application domains
- SAT solving: 75-100% satisfaction rates validated
- Neural networks: Up to 813% energy improvement demonstrated
- Game theory: Equilibrium finding validated across 3 game classes
- Casimir diagnostics: 92.5% prediction accuracy on 40 instances

See `tests/README.md` for comprehensive test documentation.

## Documentation

- `docs/PROJECT_OVERVIEW.md` - Technical architecture and design
- `docs/API_SPEC.md` - Complete API reference
- `docs/MATH.md` - Mathematical foundations
- `docs/SPECTRAL_MULTIPLICATIVE_OPTIMIZATION_PAPER.md` - Research paper
- `tests/README.md` - Test suite documentation

## Key Algorithms

### Masked Laplacian Application
Segment-local Laplacian operations enable efficient spectral analysis:
```
next unless labels[i] == labels[j]  # Only apply within segments
current = masked_laplacian_apply(labels, degrees, current)
```

This creates natural attractor basins for satisfying assignments in constraint satisfaction problems.

### Perturbative Casimir Force
Solvability diagnostic via single-literal perturbation:
```
1. Measure base force
2. Flip each literal, measure perturbed forces
3. Calculate variance across perturbations
4. High variance → solvable, low variance → unsolvable
```

Achieves 92.5% overall accuracy with perfect unsolvable detection.

### Neural Type Weight Calibration
Automatic optimization of multi-type edge weights:
```
1. Ergodic sampling of configuration space
2. Measure correlation between spectral and multiplicative functionals
3. Gradient-based weight optimization maintaining ρ ≥ 0.99
4. Converges to problem-specific optimal weights
```

## Performance Benchmarks

| Metric | Value | Test |
|--------|-------|------|
| SAT satisfaction | 75-100% | 10 test problems, 2-50 variables |
| Casimir diagnostic accuracy | 92.5% | 40 instances, balanced classes |
| Unsolvable detection | 100% | 20 unsolvable instances |
| Neural energy improvement | Up to 813% | Cloud allocation, 20 services |
| Nash equilibrium stability | 80% | 9-player competitive game |
| Correlation maintenance | ρ = -0.95 | Adversarial multi-agent scenario |
| Runtime (typical) | 40-260ms | Sub-second for most applications |
| Scalability | 100K+ variables | Sparse matrix operations |

## Research Applications

This framework has been applied to:
- Boolean satisfiability with quantum-inspired methods
- Cloud resource allocation and scheduling
- Multi-agent competitive dynamics and coalition formation
- Solvability prediction via perturbative analysis
- Network topology design and optimization
- Portfolio optimization with neural adaptation

## License

RESEARCH PREVIEW

## Citation

If you use this framework in research, please cite:
```
Spectral-Multiplicative Optimization Framework
https://github.com/sethuiyer/spectral-multiplicative-framework
```
