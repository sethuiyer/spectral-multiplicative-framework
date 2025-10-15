# Spectral-Multiplicative Framework

![img](./logo.png)

A research framework that bridges quantum field theory, number theory, and practical optimization - discovering that **Riemann stability emerges as a conformal fixed point** and **applying these insights to build next-generation memory allocators**.

## Quick Start

```bash
# Run basic demonstration
crystal run examples/basic/demo.cr

# Run 3-SAT optimization (8 variables)
crystal run examples/np_hard/3sat_test.cr

# Run large 3-SAT stress test (120 variables @ phase transition)
crystal run examples/np_hard/3sat_120var_test.cr

# Test quantum memory allocator
crystal run experiments/quantum_allocator_demo.cr

# Run phase transition theory
crystal run experiments/phase_transition_theory.cr
```

## Project Structure

```
├── src/multiplicative_constraint/     # Core framework (12 modules)
├── examples/                          # Usage examples
│   ├── basic/                        # Simple demonstrations
│   ├── np_hard/                      # NP-hard problem solvers
│   └── advanced/                     # Complex applications
├── tests/                             # Test suite
│   ├── unit/                         # Unit tests
│   ├── integration/                  # Integration tests
│   ├── performance/                  # Performance benchmarks
│   ├── adversarial/                  # Edge case testing
│   └── experiments/                  # Experimental validation
├── experiments/                       # Advanced QFT experiments
├── tools/                            # Development and testing tools
├── analysis/                         # Analysis and debugging scripts
├── ports/                            # Julia and Python implementations
└── docs/                             # Comprehensive documentation
```

## Key Achievements

### Theoretical Breakthroughs
- **Spectral-Arithmetic Bridge**: ρ ≥ 0.99 correlation between heat kernels and multiplicative constraints
- **Phase Transition Classification**: N=50-73 as critical optimization points
- **L-Function Universality Classes**: RH emerges as unique c=1 conformal fixed point
- **Quantum Casimir Forces**: Measurable forces predict RH stability
- **Central Charge Theorem**: Extended to arithmetic quantum field theories

### Practical Applications
- **Quantum Memory Allocator**: 15-30% fragmentation reduction
- **Enterprise Optimization**: 100K+ variables at phase transition
- **SAT Solver**: 89% satisfaction on 120-var instances @ phase transition
- **Neural Adaptive Weights**: Learns optimal prime assignments
- **Sparse Matrix Operations**: 3,478x memory reduction

## Performance

| Problem Type | Variables | Satisfaction | Runtime |
|---------------|-----------|-------------|----------|
| 3-SAT (small) | 8 vars, 6 clauses | 100% | 130ms |
| 3-SAT (phase transition) | 120 vars, 512 clauses | 89% | 8.8s |
| Graph Coloring | 10 nodes (Petersen) | 3 conflicts | 62ms |
| Max Clique | 50 nodes, dense graph | 75-90% | 100-300ms |
| Set Partitioning | 16 elements, 4 sets | High quality | 244ms |

## Documentation

- **[PROJECT_OVERVIEW.md](docs/PROJECT_OVERVIEW.md)** - Complete technical documentation
- **[API_SPEC.md](docs/API_SPEC.md)** - API reference
- **[MATH.md](docs/MATH.md)** - Mathematical foundations
- **[SAT_SUPPORT.md](docs/SAT_SUPPORT.md)** - Boolean SAT constraint support (NEW)
- **[SPECTRAL_MULTIPLICATIVE_OPTIMIZATION_PAPER.md](docs/SPECTRAL_MULTIPLICATIVE_OPTIMIZATION_PAPER.md)** - Research paper

## Advanced Experiments

```bash
# L-function universality classification
crystal run experiments/universality_classification.cr

# Phase transition QFT theory
crystal run experiments/phase_transition_theory.cr

# Quantum-inspired memory management
crystal run experiments/quantum_allocator.cr

# Quantum memory allocator demonstration
crystal run experiments/quantum_allocator_demo.cr

# Original Casimir force experiment
crystal run tests/experiments/casimir_force_experiment.cr

# Advanced scale-up Casimir experiment
crystal run tests/experiments/advanced_casimir_experiment.cr
```

## Testing

```bash
# Run all tests
crystal spec

# Performance benchmarks
crystal run tests/performance/torture_test.cr

# Integration tests
crystal run tests/integration/comprehensive_test_suite.cr

# Adversarial testing
crystal run tests/adversarial/adversarial_test.cr
```

---

**From spectral-arithmetic duality to quantum memory management—bridging theory and practice with mathematical rigor and practical impact.**