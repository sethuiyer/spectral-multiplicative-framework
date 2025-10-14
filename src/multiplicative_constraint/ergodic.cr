module MultiplicativeConstraint
  # Simple ergodic/quasi-periodic sampler on T^k for alpha proposals
  # alpha_t = (alpha_0 + t * omega) mod 2π, with incommensurate omega
  class ErgodicSampler
    getter k : Int32
    getter seed : Int32

    @t : Int64
    @alpha0 : Array(Float64)
    @omega : Array(Float64)

    def initialize(@k : Int32, @seed : Int32 = 777)
      rng = Random.new(@seed)
      # random initial alpha in [0, 2π)
      @alpha0 = Array.new(@k) { rng.rand * 2.0 * Math::PI }
      # incommensurate omega using square roots of primes mapped to [0, 2π)
      primes = generate_primes(@k)
      @omega = primes.map { |p| (Math.sqrt(p.to_f64) % 1.0) * 2.0 * Math::PI }
      # small random jitter to avoid rational coincidences
      @omega = @omega.map { |w| w + (rng.rand - 0.5) * 1e-6 }
      @t = 0_i64
    end

    def next_alpha : Array(Float64)
      alpha = Array(Float64).new(@k)
      @k.times do |i|
        val = (@alpha0[i] + @t.to_f64 * @omega[i]) % (2.0 * Math::PI)
        alpha << (val < 0 ? val + 2.0 * Math::PI : val)
      end
      @t += 1
      alpha
    end

    private def generate_primes(n : Int32) : Array(Int32)
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
      i = 2
      while i * i <= x
        return false if x % i == 0
        i += 1
      end
      true
    end
  end
end


