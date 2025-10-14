"""
Spectral-Multiplicative Optimization Library (Julia Implementation)

A Julia implementation of the spectral-multiplicative framework for graph partitioning.
This library combines heat-kernel spectral theory with multiplicative prime-weight constraints
to achieve scalable, mathematically rigorous optimization.

Based on the Crystal implementation at: https://codeberg.org/aninokuma/malloc

Author: [Author Name]
License: MIT
"""

using LinearAlgebra
using SparseArrays
using Random
using Statistics
using DataStructures

"""
Result structure for spectral-multiplicative optimization
"""
struct PartitionResult
    alpha::Vector{Float64}           # Angular parameters
    energy::Float64                  # Unified energy
    spectral::Float64                # Spectral action
    fairness::Float64                # Size fairness penalty
    weight_fairness::Float64         # Weight fairness penalty
    entropy::Float64                 # Shannon entropy
    penalty::Float64                 # Multiplicative penalty
    cross_conflict::Float64          # Edge cut weight
    segments::Vector{Vector{Int}}    # Discrete segment assignments
end

"""
Graph structure supporting both dense and sparse representations
"""
struct Graph
    weights::Vector{Float64}
    adjacency::Union{Matrix{Float64}, SparseMatrixCSC{Float64, Int}}
    use_sparse::Bool
    edges::Vector{Tuple{Int, Int, Float64}}
    n_nodes::Int

    function Graph(weights::Vector{Float64}, adjacency::Matrix{Float64})
        n = length(weights)
        @assert size(adjacency) == (n, n) "Adjacency matrix must be square"
        edges = _extract_edges_from_dense(adjacency)
        new(weights, adjacency, false, edges, n)
    end

    function Graph(weights::Vector{Float64}, edges::Vector{Tuple{Int, Int, Float64}})
        n = length(weights)
        adjacency = _build_sparse_from_edges(edges, n)
        new(weights, adjacency, true, edges, n)
    end
end

"""
Build sparse adjacency matrix from edge list
"""
function _build_sparse_from_edges(edges::Vector{Tuple{Int, Int, Float64}}, n::Int)
    I, J, V = Int[], Int[], Float64[]
    for (i, j, weight) in edges
        push!(I, i + 1)  # Convert to 1-based indexing
        push!(J, j + 1)
        push!(V, weight)
    end
    sparse(I, J, V, n, n)
end

"""
Extract edge list from dense adjacency matrix
"""
function _extract_edges_from_dense(adjacency::Matrix{Float64})
    n = size(adjacency, 1)
    edges = Tuple{Int, Int, Float64}[]
    for i in 1:n
        for j in i:n  # Only upper triangle to avoid duplicates
            weight = adjacency[i, j]
            if abs(weight) > 1e-12
                push!(edges, (i - 1, j - 1, weight))  # Convert to 0-based indexing
            end
        end
    end
    edges
end

"""
Get node degrees
"""
function degrees(graph::Graph)
    if graph.use_sparse
        vec(sum(graph.adjacency, dims=2))
    else
        vec(sum(graph.adjacency, dims=2))
    end
end

"""
Get memory usage statistics
"""
function memory_usage(graph::Graph)
    if graph.use_sparse
        nnz = length(graph.adjacency.nzval)
        memory_mb = nnz * 8 / (1024^2)
        density = nnz / (graph.n_nodes^2) * 100
        return "SparseGraph($(graph.n_nodes) nodes, nnz=$nnz, density=$(round(density, digits=2))%, memory=$(round(memory_mb, digits=1))MB)"
    else
        memory_mb = graph.n_nodes^2 * 8 / (1024^2)
        return "DenseGraph($(graph.n_nodes) nodes, memory=$(round(memory_mb, digits=1))MB)"
    end
end

"""
Quasi-periodic sampler for alpha proposals
"""
mutable struct ErgodicSampler
    k::Int
    seed::Int
    t::Int
    alpha0::Vector{Float64}
    omega::Vector{Float64}

    function ErgodicSampler(k::Int, seed::Int=777)
        Random.seed!(seed)
        alpha0 = rand(Float64, k) .* 2π

        # Generate incommensurate omega using square roots of primes
        primes = _generate_primes(k)
        omega = [sqrt(p) % 1.0 * 2π for p in primes]

        # Add small jitter to avoid rational coincidences
        omega .+= rand(Float64, k) .* 1e-6 .- 5e-7

        new(k, seed, 0, alpha0, omega)
    end
end

"""
Generate first n prime numbers
"""
function _generate_primes(n::Int)
    primes = Int[]
    candidate = 2
    while length(primes) < n
        if _is_prime(candidate)
            push!(primes, candidate)
        end
        candidate += 1
    end
    primes
end

"""
Check if number is prime
"""
function _is_prime(x::Int)
    if x < 2
        return false
    end
    for i in 2:floor(Int, sqrt(x))
        if x % i == 0
            return false
        end
    end
    true
end

"""
Generate next alpha configuration
"""
function next_alpha(sampler::ErgodicSampler)
    alpha = Vector{Float64}(undef, sampler.k)
    for i in 1:sampler.k
        val = (sampler.alpha0[i] + sampler.t * sampler.omega[i]) % (2π)
        alpha[i] = val < 0 ? val + 2π : val
    end
    sampler.t += 1
    alpha
end

"""
Main optimizer implementing the spectral-multiplicative framework
"""
mutable struct SpectralMultiplicativeOptimizer
    graph::Graph
    n_segments::Int
    beta::Float64
    heat_order::Int
    heat_samples::Int

    # Energy function weights
    fairness_weight::Float64
    weight_fairness_weight::Float64
    entropy_weight::Float64
    penalty_weight::Float64
    cross_conflict_weight::Float64

    # Prime weights for multiplicative constraints
    prime_weights::Vector{Float64}

    # Precomputed Laplacian
    laplacian::Union{Matrix{Float64}, SparseMatrixCSC{Float64, Int}}

    function SpectralMultiplicativeOptimizer(
        graph::Graph, n_segments::Int;
        fairness_weight::Float64=1.0,
        weight_fairness_weight::Float64=0.5,
        entropy_weight::Float64=0.1,
        penalty_weight::Float64=1.0,
        cross_conflict_weight::Float64=0.0,
        beta::Float64=0.1,
        heat_order::Int=6,
        heat_samples::Int=4
    )
        # Generate prime weights
        prime_weights = _generate_prime_weights(graph.n_nodes)

        # Compute Laplacian
        D = Diagonal(degrees(graph))
        laplacian = D - graph.adjacency

        new(
            graph, n_segments, beta, heat_order, heat_samples,
            fairness_weight, weight_fairness_weight, entropy_weight,
            penalty_weight, cross_conflict_weight, prime_weights, laplacian
        )
    end
end

"""
Generate prime weights for nodes
"""
function _generate_prime_weights(n::Int)
    primes = Int[]
    candidate = 2
    while length(primes) < n
        if _is_prime(candidate)
            push!(primes, candidate)
        end
        candidate += 1
    end
    Float64.(primes[1:n])
end

"""
Compute heat kernel trace using Hutchinson's method
"""
function _heat_kernel_trace(optimizer::SpectralMultiplicativeOptimizer, alpha::Vector{Float64})
    segments = _alpha_to_segments(optimizer, alpha)
    total_trace = 0.0

    for _ in 1:optimizer.heat_samples
        # Random vector with +/- 1 entries
        v = rand([-1.0, 1.0], optimizer.graph.n_nodes)
        current = copy(v)
        accum = 0.0

        for k in 0:optimizer.heat_order
            coefficient = k % 2 == 0 ? 1.0 : -1.0
            factorial_val = factorial(k)
            accum += coefficient / factorial_val * dot(v, current)

            if k < optimizer.heat_order
                current = _apply_masked_laplacian(optimizer, current, segments)
            end
        end

        total_trace += accum
    end

    total_trace / optimizer.heat_samples
end

"""
Apply masked Laplacian operator
"""
function _apply_masked_laplacian(optimizer::SpectralMultiplicativeOptimizer,
                                vector::Vector{Float64},
                                segments::Vector{Vector{Int}})
    # Create labels from segments
    labels = zeros(Int, optimizer.graph.n_nodes)
    for (seg_idx, segment) in enumerate(segments)
        for node in segment
            labels[node + 1] = seg_idx  # +1 for 1-based indexing
        end
    end

    # Apply Laplacian within segments only
    deg = degrees(optimizer.graph)
    result = deg .* vector

    if optimizer.graph.use_sparse
        adj = optimizer.graph.adjacency
        for i in 1:optimizer.graph.n_nodes
            # Get neighbors in same segment
            for j in nzrange(adj, i)
                neighbor = adj.rowval[j]
                weight = adj.nzval[j]
                if labels[i] == labels[neighbor]
                    result[i] -= weight * vector[neighbor]
                end
            end
        end
    else
        adj = optimizer.graph.adjacency
        for i in 1:optimizer.graph.n_nodes
            for j in 1:optimizer.graph.n_nodes
                weight = adj[i, j]
                if abs(weight) > 1e-12 && labels[i] == labels[j]
                    result[i] -= weight * vector[j]
                end
            end
        end
    end

    result
end

"""
Convert angular parameters to discrete segments
"""
function _alpha_to_segments(optimizer::SpectralMultiplicativeOptimizer, alpha::Vector{Float64})
    # Normalize angles to [0, 2π)
    normalized = alpha .% (2π)

    # Scale to graph size
    scaled = Int.(floor.((normalized ./ (2π)) .* optimizer.graph.n_nodes))
    scaled = clamp.(scaled, 0, optimizer.graph.n_nodes - 1)

    # Adjust indices to avoid duplicates
    adjusted = _adjust_indices(scaled, optimizer.graph.n_nodes)

    # Create segments from cuts
    _segments_from_cuts(adjusted, optimizer.graph.n_nodes)
end

"""
Adjust indices to avoid duplicates
"""
function _adjust_indices(indices::Vector{Int}, n::Int)
    used = Set{Int}()
    adjusted = Int[]

    for idx in sort(indices)
        candidate = idx % n
        while candidate in used && length(used) < n
            candidate = (candidate + 1) % n
        end
        push!(used, candidate)
        push!(adjusted, candidate)
        if length(used) == n
            break
        end
    end

    adjusted
end

"""
Create segments from cut points
"""
function _segments_from_cuts(cuts::Vector{Int}, n::Int)
    if length(cuts) == 0
        return [collect(0:n-1)]
    end

    segments = Vector{Vector{Int}}()
    for (i, cut_start) in enumerate(cuts)
        cut_end = cuts[(i % length(cuts)) + 1]

        if cut_start == cut_end
            segment = Int[]
        elseif cut_start < cut_end
            segment = collect(cut_start:cut_end-1)
        else
            segment = vcat(collect(cut_start:n-1), collect(0:cut_end-1))
        end

        push!(segments, segment)
    end

    segments
end

"""
Compute size fairness penalty
"""
function _compute_fairness(segments::Vector{Vector{Int}}, n_nodes::Int, n_segments::Int)
    target_size = n_nodes / n_segments
    penalty = 0.0
    for segment in segments
        diff = length(segment) - target_size
        penalty += diff^2
    end
    penalty / 2.0
end

"""
Compute weight fairness penalty
"""
function _compute_weight_fairness(segments::Vector{Vector{Int}},
                                 weights::Vector{Float64},
                                 n_segments::Int)
    total_weight = sum(weights)
    target_weight = total_weight / n_segments
    penalty = 0.0

    for segment in segments
        if !isempty(segment)
            segment_weight = sum(weights[segment .+ 1])  # +1 for 1-based indexing
            diff = segment_weight - target_weight
            penalty += diff^2
        end
    end

    penalty / 2.0
end

"""
Compute Shannon entropy of segment sizes
"""
function _compute_entropy(segments::Vector{Vector{Int}}, n_nodes::Int)
    total_size = n_nodes
    if total_size == 0
        return 0.0
    end

    entropy = 0.0
    for segment in segments
        size = length(segment)
        if size > 0
            p = size / total_size
            entropy -= p * log(p)
        end
    end

    entropy
end

"""
Compute multiplicative penalty using prime weights
"""
function _compute_multiplicative_penalty(segments::Vector{Vector{Int}},
                                       prime_weights::Vector{Float64})
    penalty = 1.0

    for segment in segments
        segment_penalty = 1.0
        for node in segment
            weight = prime_weights[node + 1]  # +1 for 1-based indexing
            segment_penalty *= (1.0 - 1.0 / (weight^2))
        end
        penalty *= segment_penalty
    end

    penalty
end

"""
Compute cross-segment edge cut weight
"""
function _compute_cross_conflict(segments::Vector{Vector{Int}}, edges::Vector{Tuple{Int, Int, Float64}})
    # Create labels from segments
    labels = zeros(Int, maximum(maximum.(segments, init=0)) + 1)
    for (seg_idx, segment) in enumerate(segments)
        for node in segment
            labels[node + 1] = seg_idx
        end
    end

    conflict_weight = 0.0
    for (i, j, weight) in edges
        if labels[i + 1] != labels[j + 1]
            conflict_weight += weight
        end
    end

    conflict_weight
end

"""
Evaluate unified energy for given angular configuration
"""
function evaluate_energy(optimizer::SpectralMultiplicativeOptimizer, alpha::Vector{Float64})
    segments = _alpha_to_segments(optimizer, alpha)

    # Compute individual energy components
    spectral = -_heat_kernel_trace(optimizer, alpha)
    fairness = _compute_fairness(segments, optimizer.graph.n_nodes, optimizer.n_segments)
    weight_fairness = _compute_weight_fairness(segments, optimizer.graph.weights, optimizer.n_segments)
    entropy = _compute_entropy(segments, optimizer.graph.n_nodes)
    penalty = _compute_multiplicative_penalty(segments, optimizer.prime_weights)
    cross_conflict = _compute_cross_conflict(segments, optimizer.graph.edges)

    # Combine into unified energy
    unified = (spectral +
              optimizer.fairness_weight * fairness +
              optimizer.weight_fairness_weight * weight_fairness -
              optimizer.entropy_weight * entropy -
              optimizer.penalty_weight * penalty +
              optimizer.cross_conflict_weight * cross_conflict)

    PartitionResult(
        alpha, unified, spectral, fairness, weight_fairness,
        entropy, penalty, cross_conflict, segments
    )
end

"""
Calibrate energy weights via ergodic sampling
"""
function calibrate_weights(optimizer::SpectralMultiplicativeOptimizer, n_samples::Int=64)
    sampler = ErgodicSampler(optimizer.n_segments)

    # Collect samples
    spectral_vals = Float64[]
    fairness_vals = Float64[]
    weight_fairness_vals = Float64[]
    entropy_vals = Float64[]
    penalty_vals = Float64[]
    cross_conflict_vals = Float64[]

    for _ in 1:n_samples
        alpha = next_alpha(sampler)
        result = evaluate_energy(optimizer, alpha)

        push!(spectral_vals, result.spectral)
        push!(fairness_vals, result.fairness)
        push!(weight_fairness_vals, result.weight_fairness)
        push!(entropy_vals, result.entropy)
        push!(penalty_vals, result.penalty)
        push!(cross_conflict_vals, result.cross_conflict)
    end

    # Build feature matrix and target
    features = hcat(
        fairness_vals,
        weight_fairness_vals,
        -entropy_vals,  # Negative as in unified formula
        -penalty_vals,  # Negative as in unified formula
        cross_conflict_vals
    )

    target = spectral_vals

    # Solve least squares: features * weights = target
    weights = features \ target

    # Update internal weights
    optimizer.fairness_weight = max(0, weights[1])
    optimizer.weight_fairness_weight = max(0, weights[2])
    optimizer.entropy_weight = max(0, -weights[3])  # Negative to flip sign
    optimizer.penalty_weight = max(0, -weights[4])  # Negative to flip sign
    optimizer.cross_conflict_weight = max(0, weights[5])

    Dict(
        :fairness_weight => optimizer.fairness_weight,
        :weight_fairness_weight => optimizer.weight_fairness_weight,
        :entropy_weight => optimizer.entropy_weight,
        :penalty_weight => optimizer.penalty_weight,
        :cross_conflict_weight => optimizer.cross_conflict_weight
    )
end

"""
Optimize using simulated annealing in angular space
"""
function optimize(optimizer::SpectralMultiplicativeOptimizer;
                 iterations::Int=2000,
                 step_size::Float64=0.35,
                 seed::Int=42)
    Random.seed!(seed)

    # Initialize random angular configuration
    alpha = rand(Float64, optimizer.n_segments) .* 2π
    current_result = evaluate_energy(optimizer, alpha)

    best_alpha = copy(alpha)
    best_result = current_result

    current_step = step_size

    for iteration in 1:iterations
        # Adaptive temperature schedule
        temperature = max(0.02, 1.0 - iteration / iterations)

        # Generate candidate via Gaussian perturbation
        perturbation = randn(Float64, optimizer.n_segments) .* current_step .* temperature
        candidate_alpha = (alpha .+ perturbation) .% (2π)
        candidate_result = evaluate_energy(optimizer, candidate_alpha)

        # Metropolis acceptance criterion
        if (candidate_result.energy < current_result.energy ||
            rand() < exp(-(candidate_result.energy - current_result.energy) / temperature))
            alpha = candidate_alpha
            current_result = candidate_result

            # Update best solution
            if candidate_result.energy < best_result.energy
                best_alpha = copy(alpha)
                best_result = candidate_result
            end
        end

        # Adaptive step size
        current_step = max(0.05, current_step * 0.999)
    end

    best_result
end

"""
Compute correlation between spectral and multiplicative functionals
"""
function compute_correlation(optimizer::SpectralMultiplicativeOptimizer, n_samples::Int=64)
    sampler = ErgodicSampler(optimizer.n_segments)

    composite_vals = Float64[]
    multiplicative_vals = Float64[]

    for _ in 1:n_samples
        alpha = next_alpha(sampler)
        result = evaluate_energy(optimizer, alpha)

        # Composite energy (without multiplicative term)
        composite = (result.spectral +
                    optimizer.fairness_weight * result.fairness +
                    optimizer.weight_fairness_weight * result.weight_fairness -
                    optimizer.entropy_weight * result.entropy +
                    optimizer.cross_conflict_weight * result.cross_conflict)

        push!(composite_vals, composite)
        push!(multiplicative_vals, result.penalty)
    end

    # Compute Pearson correlation
    cor(composite_vals, multiplicative_vals)
end

# Utility functions for creating common graph types

"""
Create a complete graph with random weights
"""
function create_complete_graph(n_nodes::Int, weight_range::Tuple{Float64, Float64}=(1.0, 10.0))
    weights = rand(Uniform(weight_range...), n_nodes)
    adjacency = ones(n_nodes, n_nodes) - I
    adjacency .*= rand(Uniform(weight_range...), n_nodes, n_nodes)
    Graph(weights, adjacency)
end

"""
Create a ring/circular graph
"""
function create_ring_graph(n_nodes::Int, weight_range::Tuple{Float64, Float64}=(1.0, 10.0))
    weights = rand(Uniform(weight_range...), n_nodes)
    edges = Tuple{Int, Int, Float64}[]

    for i in 0:n_nodes-1
        j = (i + 1) % n_nodes
        weight = rand(Uniform(weight_range...))
        push!(edges, (i, j, weight))
        push!(edges, (j, i, weight))  # Undirected
    end

    Graph(weights, edges)
end

"""
Create an Erdős–Rényi random graph
"""
function create_random_graph(n_nodes::Int, edge_probability::Float64=0.1,
                            weight_range::Tuple{Float64, Float64}=(1.0, 10.0))
    weights = rand(Uniform(weight_range...), n_nodes)
    edges = Tuple{Int, Int, Float64}[]

    for i in 0:n_nodes-1
        for j in i+1:n_nodes-1
            if rand() < edge_probability
                weight = rand(Uniform(weight_range...))
                push!(edges, (i, j, weight))
            end
        end
    end

    Graph(weights, edges)
end

"""
Create a 2D grid graph
"""
function create_grid_graph(rows::Int, cols::Int, weight_range::Tuple{Float64, Float64}=(1.0, 10.0))
    n_nodes = rows * cols
    weights = rand(Uniform(weight_range...), n_nodes)
    edges = Tuple{Int, Int, Float64}[]

    for r in 0:rows-1
        for c in 0:cols-1
            i = r * cols + c

            # Right neighbor
            if c < cols - 1
                j = r * cols + (c + 1)
                weight = rand(Uniform(weight_range...))
                push!(edges, (i, j, weight))
                push!(edges, (j, i, weight))
            end

            # Bottom neighbor
            if r < rows - 1
                j = (r + 1) * cols + c
                weight = rand(Uniform(weight_range...))
                push!(edges, (i, j, weight))
                push!(edges, (j, i, weight))
            end
        end
    end

    Graph(weights, edges)
end

# Example usage and demonstration

"""
Demonstrate optimization on a ring graph
"""
function demo_ring_graph()
    println("=== Ring Graph Demo ===")

    # Create ring graph
    graph = create_ring_graph(20, (2.0, 5.0))
    println("Graph: $(memory_usage(graph))")

    # Create optimizer
    optimizer = SpectralMultiplicativeOptimizer(graph, 4)

    # Calibrate weights
    calibrated = calibrate_weights(optimizer, 64)
    println("Calibrated weights: $calibrated")

    # Compute correlation
    correlation = compute_correlation(optimizer, 64)
    println("Spectral-multiplicative correlation: $(round(correlation, digits=3))")

    # Optimize
    result = optimize(optimizer, iterations=1000, seed=42)

    println("\nOptimization Results:")
    println("Unified energy: $(round(result.energy, digits=4))")
    println("Spectral action: $(round(result.spectral, digits=4))")
    println("Fairness penalty: $(round(result.fairness, digits=4))")
    println("Entropy: $(round(result.entropy, digits=4))")
    println("Multiplicative penalty: $(round(result.penalty, digits=4))")
    println("Cross-conflict: $(round(result.cross_conflict, digits=4))")

    println("\nSegments:")
    for (i, segment) in enumerate(result.segments)
        println("  Segment $(i): $(length(segment)) nodes - $segment")
    end
end

"""
Demonstrate enterprise-scale optimization
"""
function demo_enterprise_scale()
    println("\n=== Enterprise Scale Demo ===")

    # Create large sparse graph
    graph = create_random_graph(5000, 0.02, (1.0, 100.0))
    println("Graph: $(memory_usage(graph))")

    # Create optimizer
    optimizer = SpectralMultiplicativeOptimizer(graph, 8)

    # Optimize
    result = optimize(optimizer, iterations=500, seed=42)

    println("\nOptimization Results:")
    println("Unified energy: $(round(result.energy, digits=4))")
    segment_sizes = [length(s) for s in result.segments]
    println("Segments sizes: $segment_sizes")
    println("Average segment size: $(round(mean(segment_sizes), digits=1))")
    println("Balance variance: $(round(var(segment_sizes), digits=2))")
end

"""
Main demonstration function
"""
function main()
    # Run demonstrations
    demo_ring_graph()
    demo_enterprise_scale()

    println("\n=== Library Ready ===")
    println("Use SpectralMultiplicativeOptimizer for your optimization problems!")
    println("See https://codeberg.org/aninokuma/malloc for the original Crystal implementation.")
end

# Run demo if script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end