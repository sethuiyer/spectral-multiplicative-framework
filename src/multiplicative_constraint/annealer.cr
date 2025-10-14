#
# Simulated Annealing Optimizer
# Developed by aninokuma at Shunya Bar
#
# This module implements a sophisticated simulated annealing algorithm that
# operates in continuous angular space [0, 2π) and maps to discrete segment
# assignments. The key innovations include:
#
# 1. Angular space parameterization for smooth optimization
# 2. Adaptive temperature scheduling with geometric cooling
# 3. Gaussian perturbations for efficient exploration
# 4. Metropolis acceptance criterion with temperature-dependent probabilities
# 5. Step size adaptation to balance exploration and exploitation
#
# The annealer is the workhorse that finds optimal configurations in the
# complex energy landscape defined by the spectral-multiplicative framework.
#
# @author aninokuma at Shunya Bar
#

module MultiplicativeConstraint
  # Simulated annealing optimizer for continuous angular space
  #
  # This class implements an advanced simulated annealing algorithm that
  # efficiently explores the complex energy landscape of the spectral-
  # multiplicative optimization problem. The angular parameterization
  # enables smooth gradient-free optimization while maintaining the
  # ability to map to discrete segment assignments.
  #
  # Algorithm features:
  # - Adaptive temperature scheduling (linear cooling)
  # - Gaussian perturbations with temperature scaling
  # - Metropolis acceptance with Boltzmann probabilities
  # - Step size adaptation for convergence tuning
  # - Best-solution tracking across all iterations
  #
  # @author aninokuma at Shunya Bar
  class Annealer
    # Energy function to optimize
    @energy : Energy

    # Initialize the annealer with an energy function
    #
    # @param energy Energy function implementing the unified objective
    def initialize(@energy : Energy)
    end

    # Execute simulated annealing optimization
    #
    # The optimization proceeds through temperature-controlled exploration
    # of the angular space, with the Metropolis criterion determining
    # acceptance of uphill moves to escape local minima.
    #
    # @param blocks Number of angular parameters (segments)
    # @param iterations Number of annealing iterations (default 1500)
    # @param step Initial step size for perturbations (default 0.35)
    # @param seed Random seed for reproducible results (default 42)
    # @param bethe_hessian Optional BetheHessian for correlation tracking
    # @return Tuple of [best_alpha, best_energy] found during optimization
    def minimize(blocks : Int32, iterations = 1500, step = 0.35, seed = 42, bethe_hessian : BetheHessian? = nil)
      rng = Random.new(seed)

      # Initialize random configuration in angular space [0, 2π)
      alpha = Array.new(blocks) { rng.rand * 2 * Math::PI }
      energy_val = @energy.unified(alpha)

      # Track best solution found across all iterations
      best_alpha = alpha.dup
      best_energy = energy_val
      step_scale = step

      # For correlation tracking
      spectral_history = [] of Float64
      mult_history = [] of Float64

      iterations.times do |iter|
        # Adaptive temperature: linear cooling from 1.0 to 0.02
        temperature = Math.max(0.02, 1.0 - iter / iterations.to_f64)

        # Generate candidate via Gaussian perturbation
        candidate = alpha.map do |a|
          delta = gaussian(rng, step_scale * temperature)
          (a + delta) % (2 * Math::PI)  # Keep in [0, 2π) range
        end

        candidate_energy = @energy.unified(candidate)

        # Metropolis acceptance criterion
        # Accept if better, or probabilistically accept worse moves
        if candidate_energy < energy_val || rng.rand < Math.exp(-(candidate_energy - energy_val) / temperature)
          alpha = candidate
          energy_val = candidate_energy

          # Update best solution if improvement found
          if candidate_energy < best_energy
            best_energy = candidate_energy
            best_alpha = candidate.dup
          end
        end

        # Adaptive step size: gradually decrease for fine-tuning
        step_scale = Math.max(0.05, step_scale * 0.999)

        # Track correlation every 100 iterations if BetheHessian is available
        if bethe_hessian && (iter % 100 == 0)
          eval_result = @energy.evaluate(alpha)
          labels = eval_result.labels
          spectral_action = eval_result.spectral
          mult_penalty = eval_result.penalty

          spectral_history << spectral_action
          mult_history << mult_penalty

          if spectral_history.size >= 2
            correlation = bethe_hessian.compute_spectral_multiplicative_correlation(
              @energy.graph, labels, spectral_history, mult_history
            )

            puts "Iteration #{iter}: Spectral-Multiplicative ρ: #{correlation.round(3)}"
          end
        end
      end

      {best_alpha, best_energy}
    end

    # Generate Gaussian random perturbation
    #
    # Uses the Box-Muller transform to generate normally distributed
    # random numbers for smooth exploration of the parameter space.
    #
    # @param rng Random number generator
    # @param scale Standard deviation of the Gaussian
    # @return Gaussian-distributed random value
    private def gaussian(rng : Random, scale : Float64)
      u1 = rng.rand.clamp(1e-9, 1.0)  # Avoid log(0)
      u2 = rng.rand
      magnitude = Math.sqrt(-2.0 * Math.log(u1))
      angle = 2.0 * Math::PI * u2
      magnitude * Math.cos(angle) * scale
    end
  end
end
