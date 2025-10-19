# Spectral Multiplicative Framework - Quick Reference

## Installation
```bash
git clone https://github.com/sethuiyer/spectral-multiplicative-framework.git
cd spectral-multiplicative-framework
shards install
crystal build src/multiplicative_constraint.cr
```

## Basic Usage Pattern
```crystal
require "./src/multiplicative_constraint"

# 1. Define graph
weights = [12.0, 15.0, 17.0, 10.0, 8.0, 22.0]
adjacency = [[0.0, 2.0, 1.0], [2.0, 0.0, 3.5], [1.0, 3.5, 0.0]]

# 2. Create engine
graph = MultiplicativeConstraint::Graph.new(weights, adjacency)
engine = MultiplicativeConstraint::Engine.new(graph, segments: 3)

# 3. Solve
result = engine.solve(iterations: 1500)

# 4. Analyze
puts "Energy: #{result.energy}"
puts "Segments: #{result.segments.size}"
```

## Core Classes Summary

### Engine
- **Purpose**: Main optimization interface
- **Key Methods**: `solve()`, `evaluate()`, `report()`, `calibrate!()`
- **Usage**: `Engine.new(graph, segments)`

### Graph
- **Purpose**: Graph data structure
- **Types**: Dense, Sparse, Multi-type
- **Usage**: `Graph.new(weights, adjacency)` or `Graph.from_edges(weights, edges)`

### PartitionResult
- **Purpose**: Optimization result container
- **Key Properties**: `energy`, `segments`, `spectral`, `fairness`
- **Usage**: `result.energy`, `result.segments`

### Energy
- **Purpose**: Unified energy function
- **Key Methods**: `unified()`, `spectral()`, `correlation()`
- **Usage**: `engine.evaluate(alpha)`

## Common Workflows

### Enterprise Optimization
```crystal
# Large-scale sparse graph
edges = [{0, 1, 2.0}, {1, 2, 3.0}, ...]
graph = Graph.from_edges(weights, edges)
engine = Engine.new(graph, segments: 10, calibrate: true)
result = engine.solve(iterations: 5000)
```

### SAT Solving
```crystal
clauses = [[1, 2, 3], [-1, 2], [1, -3]]
solver = SATSolver.new(3, clauses)
result = solver.solve(use_diagnostic: true)
puts "Satisfiable: #{result.satisfiable}"
```

### Multi-Type Graphs
```crystal
edge_types = {
  "network" => SparseMatrix.from_edges(...),
  "geographic" => SparseMatrix.from_edges(...)
}
graph = Graph.new(weights, edge_types, {"network" => 1.5, "geographic" => 0.8})
engine = Engine.new(graph, segments: 5)
engine.train_type_weights(iterations: 100)
result = engine.solve
```

## Key Parameters

### Engine Configuration
- `segments`: Number of partitions (2-10 optimal)
- `fairness_weight`: Balance importance (default: 1.0)
- `penalty_weight`: Constraint strength (default: 1.0)
- `calibrate`: Auto-tune weights (default: false)
- `enable_corr_guard`: Maintain mathematical validity (default: false)

### Solver Parameters
- `iterations`: Optimization steps (1500-5000)
- `step`: Perturbation size (0.25-0.5)
- `seed`: Random seed for reproducibility

## Performance Tips

### Memory Optimization
```crystal
# Use sparse for >10K nodes
graph = Graph.from_edges(weights, edges)  # Sparse
# vs
graph = Graph.new(weights, dense_adjacency)  # Dense
```

### Speed Optimization
```crystal
# Enable correlation guard only if needed
engine = Engine.new(graph, segments, enable_corr_guard: false)

# Use fewer iterations for testing
result = engine.solve(iterations: 500)
```

### Quality Optimization
```crystal
# Calibrate weights for best results
engine.calibrate!(samples: 256)
engine.train_type_weights(iterations: 200)

# Use correlation guard for validity
engine.energy.enable_correlation_guard!(rho_min: 0.995)
```

## Error Handling

```crystal
begin
  engine = Engine.new(graph, segments)
  result = engine.solve
rescue ArgumentError => e
  puts "Invalid parameters: #{e.message}"
rescue MemoryError
  puts "Memory exceeded - try sparse representation"
end
```

## Results Analysis

```crystal
result = engine.solve

# Energy components
puts "Spectral: #{result.spectral}"
puts "Fairness: #{result.fairness}"
puts "Entropy: #{result.entropy}"
puts "Cross-conflict: #{result.cross_conflict}"

# Segment analysis
result.segments.each_with_index do |segment, i|
  puts "Segment #{i+1}: #{segment.size} nodes"
end

# Quality metrics
correlation = engine.energy.correlation
puts "Correlation: #{correlation} (should be ≥ 0.99)"
```

## Quick Troubleshooting

| Problem | Solution |
|---------|----------|
| Low correlation (<0.99) | Enable `calibrate: true` and `corr_guard` |
| Memory error | Use sparse graph representation |
| Slow convergence | Increase `iterations` or adjust `step` |
| Poor balance | Increase `fairness_weight` |
| High energy | Check constraints and increase `penalty_weight` |

## Example Results Output

```
Unified energy: -2.4827397226768824
Spectral action: -2.9147335111111095
Fairness energy: 0.0
Weight fairness: 3.0
Entropy: 1.0986122886681096
Multiplicative penalty: -0.10526298523187728
Cross-conflict weight: 15.3

Segments:
  Segment 1: TaskA, TaskB
  Segment 2: TaskC, TaskD
  Segment 3: TaskE, TaskF
```

## Resources

- **Full API Docs**: `docs/COMPREHENSIVE_API_SPEC.md`
- **Examples**: `examples/` directory
- **Tests**: `tests/` directory
- **Mathematical Foundation**: `docs/MATH.md`
- **Performance Guide**: `docs/PROJECT_OVERVIEW.md`