"""
Spectral-Multiplicative Optimization Library

A Python implementation of the spectral-multiplicative framework for graph partitioning.
This library combines heat-kernel spectral theory with multiplicative prime-weight constraints
to achieve scalable, mathematically rigorous optimization.

Based on the Crystal implementation at: https://codeberg.org/aninokuma/malloc

Author: [Author Name]
License: MIT
"""

import numpy as np
import scipy.sparse as sp
from scipy.sparse.linalg import LinearOperator, eigsh
from typing import List, Tuple, Optional, Dict, Any
import random
import math
from dataclasses import dataclass
from collections import defaultdict


@dataclass
class PartitionResult:
    """Result of spectral-multiplicative optimization"""
    alpha: np.ndarray  # Angular parameters
    energy: float      # Unified energy
    spectral: float    # Spectral action
    fairness: float    # Size fairness penalty
    weight_fairness: float  # Weight fairness penalty
    entropy: float     # Shannon entropy
    penalty: float     # Multiplicative penalty
    cross_conflict: float  # Edge cut weight
    segments: List[List[int]]  # Discrete segment assignments


class Graph:
    """Graph structure supporting both dense and sparse representations"""

    def __init__(self, weights: np.ndarray, adjacency: Optional[np.ndarray] = None,
                 edges: Optional[List[Tuple[int, int, float]]] = None):
        """
        Initialize graph structure

        Args:
            weights: Node weights
            adjacency: Dense adjacency matrix (alternative to edges)
            edges: List of (i, j, weight) tuples
        """
        self.weights = np.array(weights, dtype=np.float64)
        self.n_nodes = len(weights)

        if adjacency is not None:
            self.adjacency = sp.csr_matrix(adjacency)
            self.use_sparse = False
        elif edges is not None:
            self._build_sparse_from_edges(edges)
            self.use_sparse = True
        else:
            raise ValueError("Must provide either adjacency or edges")

        self.edges = self._extract_edges()

    def _build_sparse_from_edges(self, edges: List[Tuple[int, int, float]]):
        """Build sparse adjacency matrix from edge list"""
        rows, cols, data = [], [], []
        for i, j, weight in edges:
            rows.append(i)
            cols.append(j)
            data.append(weight)

        self.adjacency = sp.csr_matrix((data, (rows, cols)),
                                      shape=(self.n_nodes, self.n_nodes))

    def _extract_edges(self) -> List[Tuple[int, int, float]]:
        """Extract edge list from adjacency matrix"""
        edges = []
        if sp.issparse(self.adjacency):
            adj = self.adjacency.tocoo()
            for i, j, w in zip(adj.row, adj.col, adj.data):
                if i <= j:  # Avoid duplicates for undirected graphs
                    edges.append((int(i), int(j), float(w)))
        else:
            for i in range(self.n_nodes):
                for j in range(i, self.n_nodes):
                    w = self.adjacency[i, j]
                    if w != 0:
                        edges.append((i, j, float(w)))
        return edges

    @property
    def degrees(self) -> np.ndarray:
        """Get node degrees"""
        return np.array(self.adjacency.sum(axis=1)).flatten()

    def memory_usage(self) -> str:
        """Get memory usage statistics"""
        if sp.issparse(self.adjacency):
            nnz = self.adjacency.nnz
            memory_mb = nnz * 8 / (1024 * 1024)  # Approximate
            density = nnz / (self.n_nodes ** 2) * 100
            return f"SparseGraph({self.n_nodes} nodes, nnz={nnz}, density={density:.2f}%, memory={memory_mb:.1f}MB)"
        else:
            memory_mb = self.n_nodes ** 2 * 8 / (1024 * 1024)
            return f"DenseGraph({self.n_nodes} nodes, memory={memory_mb:.1f}MB)"


class ErgodicSampler:
    """Quasi-periodic sampler for alpha proposals"""

    def __init__(self, k: int, seed: int = 777):
        """
        Initialize ergodic sampler

        Args:
            k: Number of angular parameters
            seed: Random seed
        """
        self.k = k
        self.seed = seed
        self.t = 0
        self._setup_parameters()

    def _setup_parameters(self):
        """Setup initial parameters"""
        np.random.seed(self.seed)
        self.alpha0 = np.random.uniform(0, 2*np.pi, self.k)

        # Generate incommensurate omega using square roots of primes
        primes = self._generate_primes(self.k)
        self.omega = np.array([np.sqrt(p) % 1.0 * 2 * np.pi for p in primes])

        # Add small jitter to avoid rational coincidences
        self.omega += np.random.uniform(-1e-6, 1e-6, self.k)

    def _generate_primes(self, n: int) -> List[int]:
        """Generate first n prime numbers"""
        primes = []
        candidate = 2
        while len(primes) < n:
            if self._is_prime(candidate):
                primes.append(candidate)
            candidate += 1
        return primes

    def _is_prime(self, x: int) -> bool:
        """Check if number is prime"""
        if x < 2:
            return False
        for i in range(2, int(np.sqrt(x)) + 1):
            if x % i == 0:
                return False
        return True

    def next_alpha(self) -> np.ndarray:
        """Generate next alpha configuration"""
        alpha = np.array([
            (self.alpha0[i] + self.t * self.omega[i]) % (2 * np.pi)
            for i in range(self.k)
        ])
        self.t += 1
        return alpha


class SpectralMultiplicativeOptimizer:
    """Main optimizer implementing the spectral-multiplicative framework"""

    def __init__(self, graph: Graph, n_segments: int,
                 fairness_weight: float = 1.0,
                 weight_fairness_weight: float = 0.5,
                 entropy_weight: float = 0.1,
                 penalty_weight: float = 1.0,
                 cross_conflict_weight: float = 0.0,
                 beta: float = 0.1,
                 heat_order: int = 6,
                 heat_samples: int = 4):
        """
        Initialize optimizer

        Args:
            graph: Graph structure to optimize
            n_segments: Number of segments to partition into
            fairness_weight: Weight for size balance penalty
            weight_fairness_weight: Weight for weight balance penalty
            entropy_weight: Weight for entropy term
            penalty_weight: Weight for multiplicative penalty
            cross_conflict_weight: Weight for edge cut minimization
            beta: Heat kernel time parameter
            heat_order: Taylor series order for heat kernel approximation
            heat_samples: Number of Hutchinson samples
        """
        self.graph = graph
        self.n_segments = n_segments
        self.beta = beta
        self.heat_order = heat_order
        self.heat_samples = heat_samples

        # Energy function weights
        self.fairness_weight = fairness_weight
        self.weight_fairness_weight = weight_fairness_weight
        self.entropy_weight = entropy_weight
        self.penalty_weight = penalty_weight
        self.cross_conflict_weight = cross_conflict_weight

        # Generate prime weights
        self.prime_weights = self._generate_prime_weights()

        # Precompute Laplacian
        self.laplacian = self._compute_laplacian()

    def _generate_prime_weights(self) -> np.ndarray:
        """Generate prime weights for nodes"""
        # Simple prime generation
        def is_prime(n):
            if n < 2:
                return False
            for i in range(2, int(np.sqrt(n)) + 1):
                if n % i == 0:
                    return False
            return True

        primes = []
        candidate = 2
        while len(primes) < self.graph.n_nodes:
            if is_prime(candidate):
                primes.append(candidate)
            candidate += 1

        return np.array(primes[:self.graph.n_nodes], dtype=np.float64)

    def _compute_laplacian(self) -> sp.csr_matrix:
        """Compute graph Laplacian L = D - A"""
        degrees = sp.diags(self.graph.degrees, format='csr')
        return degrees - self.graph.adjacency

    def _heat_kernel_trace(self, alpha: np.ndarray) -> float:
        """Compute heat kernel trace using Hutchinson's method"""
        segments = self._alpha_to_segments(alpha)

        total_trace = 0.0

        for _ in range(self.heat_samples):
            # Random vector with +/- 1 entries
            v = np.random.choice([-1, 1], size=self.graph.n_nodes).astype(np.float64)
            current = v.copy()
            accum = 0.0

            for k in range(self.heat_order + 1):
                coefficient = 1.0 if k % 2 == 0 else -1.0
                factorial = math.factorial(k)
                accum += coefficient / factorial * np.dot(v, current)

                if k < self.heat_order:
                    current = self._apply_masked_laplacian(current, segments)

            total_trace += accum

        return total_trace / self.heat_samples

    def _apply_masked_laplacian(self, vector: np.ndarray, segments: List[List[int]]) -> np.ndarray:
        """Apply masked Laplacian operator"""
        # Create labels from segments
        labels = np.zeros(self.graph.n_nodes, dtype=int)
        for seg_idx, segment in enumerate(segments):
            for node in segment:
                labels[node] = seg_idx

        # Apply Laplacian within segments only
        result = self.graph.degrees * vector

        if sp.issparse(self.graph.adjacency):
            adj = self.graph.adjacency.tocsr()
            for i in range(self.graph.n_nodes):
                # Get neighbors in same segment
                start_idx = adj.indptr[i]
                end_idx = adj.indptr[i + 1]
                for j in range(start_idx, end_idx):
                    neighbor = adj.indices[j]
                    weight = adj.data[j]
                    if labels[i] == labels[neighbor]:
                        result[i] -= weight * vector[neighbor]
        else:
            for i in range(self.graph.n_nodes):
                for j in range(self.graph.n_nodes):
                    weight = self.graph.adjacency[i, j]
                    if weight != 0 and labels[i] == labels[j]:
                        result[i] -= weight * vector[j]

        return result

    def _alpha_to_segments(self, alpha: np.ndarray) -> List[List[int]]:
        """Convert angular parameters to discrete segments"""
        # Normalize angles to [0, 2π)
        normalized = alpha % (2 * np.pi)

        # Scale to graph size
        scaled = (normalized / (2 * np.pi) * self.graph.n_nodes).astype(int)
        scaled = np.clip(scaled, 0, self.graph.n_nodes - 1)

        # Adjust indices to avoid duplicates
        adjusted = self._adjust_indices(scaled)

        # Create segments from cuts
        return self._segments_from_cuts(adjusted)

    def _adjust_indices(self, indices: np.ndarray) -> np.ndarray:
        """Adjust indices to avoid duplicates"""
        used = set()
        adjusted = []

        for idx in sorted(indices):
            candidate = idx % self.graph.n_nodes
            while candidate in used and len(used) < self.graph.n_nodes:
                candidate = (candidate + 1) % self.graph.n_nodes
            used.add(candidate)
            adjusted.append(candidate)
            if len(used) == self.graph.n_nodes:
                break

        return np.array(adjusted)

    def _segments_from_cuts(self, cuts: np.ndarray) -> List[List[int]]:
        """Create segments from cut points"""
        if len(cuts) == 0:
            return [list(range(self.graph.n_nodes))]

        segments = []
        for i, cut_start in enumerate(cuts):
            cut_end = cuts[(i + 1) % len(cuts)]

            if cut_start == cut_end:
                segment = []
            elif cut_start < cut_end:
                segment = list(range(cut_start, cut_end))
            else:
                segment = list(range(cut_start, self.graph.n_nodes)) + list(range(0, cut_end))

            segments.append(segment)

        return segments

    def _compute_fairness(self, segments: List[List[int]]) -> float:
        """Compute size fairness penalty"""
        target_size = self.graph.n_nodes / self.n_segments
        penalty = 0.0
        for segment in segments:
            diff = len(segment) - target_size
            penalty += diff * diff
        return penalty / 2.0

    def _compute_weight_fairness(self, segments: List[List[int]]) -> float:
        """Compute weight fairness penalty"""
        total_weight = self.graph.weights.sum()
        target_weight = total_weight / self.n_segments
        penalty = 0.0

        for segment in segments:
            if segment:
                segment_weight = self.graph.weights[segment].sum()
                diff = segment_weight - target_weight
                penalty += diff * diff

        return penalty / 2.0

    def _compute_entropy(self, segments: List[List[int]]) -> float:
        """Compute Shannon entropy of segment sizes"""
        total_size = self.graph.n_nodes
        if total_size == 0:
            return 0.0

        entropy = 0.0
        for segment in segments:
            size = len(segment)
            if size > 0:
                p = size / total_size
                entropy -= p * np.log(p)

        return entropy

    def _compute_multiplicative_penalty(self, segments: List[List[int]]) -> float:
        """Compute multiplicative penalty using prime weights"""
        penalty = 1.0

        for segment in segments:
            segment_penalty = 1.0
            for node in segment:
                weight = self.prime_weights[node]
                segment_penalty *= (1.0 - 1.0 / (weight * weight))
            penalty *= segment_penalty

        return penalty

    def _compute_cross_conflict(self, segments: List[List[int]]) -> float:
        """Compute cross-segment edge cut weight"""
        # Create labels from segments
        labels = np.zeros(self.graph.n_nodes, dtype=int)
        for seg_idx, segment in enumerate(segments):
            for node in segment:
                labels[node] = seg_idx

        conflict_weight = 0.0

        for i, j, weight in self.graph.edges:
            if labels[i] != labels[j]:
                conflict_weight += weight

        return conflict_weight

    def evaluate_energy(self, alpha: np.ndarray) -> PartitionResult:
        """Evaluate unified energy for given angular configuration"""
        segments = self._alpha_to_segments(alpha)

        # Compute individual energy components
        spectral = -self._heat_kernel_trace(alpha)
        fairness = self._compute_fairness(segments)
        weight_fairness = self._compute_weight_fairness(segments)
        entropy = self._compute_entropy(segments)
        penalty = self._compute_multiplicative_penalty(segments)
        cross_conflict = self._compute_cross_conflict(segments)

        # Combine into unified energy
        unified = (spectral +
                  self.fairness_weight * fairness +
                  self.weight_fairness_weight * weight_fairness -
                  self.entropy_weight * entropy -
                  self.penalty_weight * penalty +
                  self.cross_conflict_weight * cross_conflict)

        return PartitionResult(
            alpha=alpha,
            energy=unified,
            spectral=spectral,
            fairness=fairness,
            weight_fairness=weight_fairness,
            entropy=entropy,
            penalty=penalty,
            cross_conflict=cross_conflict,
            segments=segments
        )

    def calibrate_weights(self, n_samples: int = 128) -> Dict[str, float]:
        """Calibrate energy weights via ergodic sampling"""
        sampler = ErgodicSampler(self.n_segments)

        # Collect samples
        spectral_vals = []
        fairness_vals = []
        weight_fairness_vals = []
        entropy_vals = []
        penalty_vals = []
        cross_conflict_vals = []

        for _ in range(n_samples):
            alpha = sampler.next_alpha()
            result = self.evaluate_energy(alpha)

            spectral_vals.append(result.spectral)
            fairness_vals.append(result.fairness)
            weight_fairness_vals.append(result.weight_fairness)
            entropy_vals.append(result.entropy)
            penalty_vals.append(result.penalty)
            cross_conflict_vals.append(result.cross_conflict)

        # Build feature matrix and target
        features = np.column_stack([
            fairness_vals,
            weight_fairness_vals,
            [-e for e in entropy_vals],  # Negative as in unified formula
            [-p for p in penalty_vals],  # Negative as in unified formula
            cross_conflict_vals
        ])

        target = np.array(spectral_vals)

        # Solve least squares: features @ weights = target
        weights, _, _, _ = np.linalg.lstsq(features, target, rcond=None)

        # Update internal weights
        self.fairness_weight = max(0, weights[0])
        self.weight_fairness_weight = max(0, weights[1])
        self.entropy_weight = max(0, -weights[2])  # Negative to flip sign
        self.penalty_weight = max(0, -weights[3])  # Negative to flip sign
        self.cross_conflict_weight = max(0, weights[4])

        return {
            'fairness_weight': self.fairness_weight,
            'weight_fairness_weight': self.weight_fairness_weight,
            'entropy_weight': self.entropy_weight,
            'penalty_weight': self.penalty_weight,
            'cross_conflict_weight': self.cross_conflict_weight
        }

    def optimize(self, iterations: int = 2000, step_size: float = 0.35,
                 seed: int = 42) -> PartitionResult:
        """Optimize using simulated annealing in angular space"""
        np.random.seed(seed)

        # Initialize random angular configuration
        alpha = np.random.uniform(0, 2*np.pi, self.n_segments)
        current_result = self.evaluate_energy(alpha)

        best_alpha = alpha.copy()
        best_result = current_result

        current_step = step_size

        for iteration in range(iterations):
            # Adaptive temperature schedule
            temperature = max(0.02, 1.0 - iteration / iterations)

            # Generate candidate via Gaussian perturbation
            perturbation = np.random.normal(0, current_step * temperature, self.n_segments)
            candidate_alpha = (alpha + perturbation) % (2 * np.pi)
            candidate_result = self.evaluate_energy(candidate_alpha)

            # Metropolis acceptance criterion
            if (candidate_result.energy < current_result.energy or
                np.random.rand() < np.exp(-(candidate_result.energy - current_result.energy) / temperature)):
                alpha = candidate_alpha
                current_result = candidate_result

                # Update best solution
                if candidate_result.energy < best_result.energy:
                    best_alpha = alpha.copy()
                    best_result = candidate_result

            # Adaptive step size
            current_step = max(0.05, current_step * 0.999)

        return best_result

    def compute_correlation(self, n_samples: int = 64) -> float:
        """Compute correlation between spectral and multiplicative functionals"""
        sampler = ErgodicSampler(self.n_segments)

        composite_vals = []
        multiplicative_vals = []

        for _ in range(n_samples):
            alpha = sampler.next_alpha()
            result = self.evaluate_energy(alpha)

            # Composite energy (without multiplicative term)
            composite = (result.spectral +
                        self.fairness_weight * result.fairness +
                        self.weight_fairness_weight * result.weight_fairness -
                        self.entropy_weight * result.entropy +
                        self.cross_conflict_weight * result.cross_conflict)

            composite_vals.append(composite)
            multiplicative_vals.append(result.penalty)

        # Compute Pearson correlation
        composite_vals = np.array(composite_vals)
        multiplicative_vals = np.array(multiplicative_vals)

        correlation = np.corrcoef(composite_vals, multiplicative_vals)[0, 1]
        return correlation if not np.isnan(correlation) else 0.0


# Utility functions for creating common graph types

def create_complete_graph(n_nodes: int, weight_range: Tuple[float, float] = (1.0, 10.0)) -> Graph:
    """Create a complete graph with random weights"""
    weights = np.random.uniform(*weight_range, n_nodes)
    adjacency = np.ones((n_nodes, n_nodes)) - np.eye(n_nodes)
    adjacency *= np.random.uniform(*weight_range, (n_nodes, n_nodes))

    return Graph(weights, adjacency=adjacency)


def create_ring_graph(n_nodes: int, weight_range: Tuple[float, float] = (1.0, 10.0)) -> Graph:
    """Create a ring/circular graph"""
    weights = np.random.uniform(*weight_range, n_nodes)
    edges = []

    for i in range(n_nodes):
        j = (i + 1) % n_nodes
        weight = np.random.uniform(*weight_range)
        edges.append((i, j, weight))
        edges.append((j, i, weight))  # Undirected

    return Graph(weights, edges=edges)


def create_random_graph(n_nodes: int, edge_probability: float = 0.1,
                       weight_range: Tuple[float, float] = (1.0, 10.0)) -> Graph:
    """Create an Erdős–Rényi random graph"""
    weights = np.random.uniform(*weight_range, n_nodes)
    edges = []

    for i in range(n_nodes):
        for j in range(i + 1, n_nodes):
            if np.random.rand() < edge_probability:
                weight = np.random.uniform(*weight_range)
                edges.append((i, j, weight))

    return Graph(weights, edges=edges)


def create_grid_graph(rows: int, cols: int, weight_range: Tuple[float, float] = (1.0, 10.0)) -> Graph:
    """Create a 2D grid graph"""
    n_nodes = rows * cols
    weights = np.random.uniform(*weight_range, n_nodes)
    edges = []

    for r in range(rows):
        for c in range(cols):
            i = r * cols + c

            # Right neighbor
            if c < cols - 1:
                j = r * cols + (c + 1)
                weight = np.random.uniform(*weight_range)
                edges.append((i, j, weight))
                edges.append((j, i, weight))

            # Bottom neighbor
            if r < rows - 1:
                j = (r + 1) * cols + c
                weight = np.random.uniform(*weight_range)
                edges.append((i, j, weight))
                edges.append((j, i, weight))

    return Graph(weights, edges=edges)


# Example usage and demonstration

def demo_ring_graph():
    """Demonstrate optimization on a ring graph"""
    print("=== Ring Graph Demo ===")

    # Create ring graph
    graph = create_ring_graph(n_nodes=20, weight_range=(2.0, 5.0))
    print(f"Graph: {graph.memory_usage()}")

    # Create optimizer
    optimizer = SpectralMultiplicativeOptimizer(graph, n_segments=4)

    # Calibrate weights
    calibrated = optimizer.calibrate_weights(n_samples=64)
    print(f"Calibrated weights: {calibrated}")

    # Compute correlation
    correlation = optimizer.compute_correlation(n_samples=64)
    print(f"Spectral-multiplicative correlation: {correlation:.3f}")

    # Optimize
    result = optimizer.optimize(iterations=1000, seed=42)

    print(f"\nOptimization Results:")
    print(f"Unified energy: {result.energy:.4f}")
    print(f"Spectral action: {result.spectral:.4f}")
    print(f"Fairness penalty: {result.fairness:.4f}")
    print(f"Entropy: {result.entropy:.4f}")
    print(f"Multiplicative penalty: {result.penalty:.4f}")
    print(f"Cross-conflict: {result.cross_conflict:.4f}")

    print(f"\nSegments:")
    for i, segment in enumerate(result.segments):
        print(f"  Segment {i+1}: {len(segment)} nodes - {segment}")


def demo_enterprise_scale():
    """Demonstrate enterprise-scale optimization"""
    print("\n=== Enterprise Scale Demo ===")

    # Create large sparse graph
    graph = create_random_graph(n_nodes=5000, edge_probability=0.02, weight_range=(1.0, 100.0))
    print(f"Graph: {graph.memory_usage()}")

    # Create optimizer
    optimizer = SpectralMultiplicativeOptimizer(graph, n_segments=8)

    # Optimize
    result = optimizer.optimize(iterations=500, seed=42)

    print(f"\nOptimization Results:")
    print(f"Unified energy: {result.energy:.4f}")
    print(f"Segments sizes: {[len(s) for s in result.segments]}")
    print(f"Average segment size: {np.mean([len(s) for s in result.segments]):.1f}")
    print(f"Balance variance: {np.var([len(s) for s in result.segments]):.2f}")


if __name__ == "__main__":
    # Run demonstrations
    demo_ring_graph()
    demo_enterprise_scale()

    print("\n=== Library Ready ===")
    print("Use SpectralMultiplicativeOptimizer for your optimization problems!")
    print("See https://codeberg.org/aninokuma/malloc for the original Crystal implementation.")