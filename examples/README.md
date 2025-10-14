# Examples

Demonstrations of the spectral-multiplicative framework across various problem domains.

## Example Categories

### basic/ - Getting Started
- `demo.cr` - Basic framework demonstration
- `general_test.cr` - General optimization example
- `stress_test.cr` - Simple stress testing

### np_hard/ - NP-Hard Problem Solvers
- `3sat_test.cr` - 3-SAT satisfaction (87-90% at phase transition)
- `graph_coloring_test.cr` - Graph chromatic number optimization
- `max_clique_test.cr` - Maximum clique detection
- `tsp_test.cr` - Traveling salesman problem
- `hamiltonian_cycle_test.cr` - Hamiltonian cycle finding
- `vertex_cover_test.cr` - Minimum vertex cover
- `knapsack_test.cr` - Knapsack optimization
- `set_partitioning_test.cr` - Set partitioning problem
- `subset_sum_test.cr` - Subset sum optimization
- `factorization_test.cr` - Integer factorization
- `scaled_factorization_test.cr` - Large-scale factorization
- `large_factorization_test.cr` - Enterprise factorization
- `bin_packing_test.cr` - Bin packing optimization

### advanced/ - Complex Applications
- `challenging_graph.cr` - Difficult graph structures
- `prime_necklace.cr` - Prime distribution optimization
- `prime_necklace_10000.cr` - Large-scale prime necklace
- `social_network.cr` - Social network analysis

## Running Examples

```bash
# Basic demonstration
crystal run examples/basic/demo.cr

# 3-SAT optimization
crystal run examples/np_hard/3sat_test.cr

# Graph coloring
crystal run examples/np_hard/graph_coloring_test.cr

# Advanced prime necklace
crystal run examples/advanced/prime_necklace.cr
```

## Performance Expectations

| Problem Type | Scale | Satisfaction | Runtime |
|--------------|-------|-------------|---------|
| 3-SAT | 50 variables | 87-90% | 10-100ms |
| Graph Coloring | 30 nodes | 70-85% | 50-150ms |
| Max Clique | 50 nodes | 75-90% | 100-300ms |
| TSP | 20 cities | 85% | 150-500ms |

## Key Features Demonstrated

- **Spectral-Multiplicative Bridge**: Heat kernel ↔ Prime factorization
- **Phase Transition Optimization**: N=50-73 critical scaling
- **Neural Adaptive Weights**: Learned prime assignments
- **Sparse Matrix Operations**: Efficient large-scale optimization
- **Multi-Objective Optimization**: Simultaneous constraint satisfaction

## Usage Tips

1. **Start with basic examples** to understand the framework
2. **Experiment with different parameters** to see phase transitions
3. **Scale gradually** from small to large problem instances
4. **Monitor satisfaction rates** at critical scales (N≈50-73)
5. **Use advanced examples** for real-world applications