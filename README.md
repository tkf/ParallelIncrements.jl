# ParallelIncrements

ParallelIncrements.jl contains some code for benchmarking and
demonstrating the overhead of atomic operation on arrays.

Usage:

```julia
using ParallelIncrements
suite = ParallelIncrements.benchsuite()  # BenchmarkTools.BenchmarkGroup
result = run(suite; verbose = true)
```

prints something like

```
2-element BenchmarkTools.BenchmarkGroup:
  tags: []
  "n=1000" => 1-element BenchmarkTools.BenchmarkGroup:
          tags: []
          "m=1000000" => 2-element BenchmarkTools.BenchmarkGroup:
                  tags: []
                  "nonatomic" => Trial(570.088 μs)
                  "atomic" => Trial(5.701 ms)
  "single" => 2-element BenchmarkTools.BenchmarkGroup:
          tags: []
          "nonatomic" => Trial(35.000 ns)
          "atomic" => Trial(4.888 μs)
```

`atomic` uses atomic instructions; `nonatomic` uses standard
instructions.

`n=1000`/`m=1000000` benchmark increments random `m` indices in a
vector of length `n`.  Atomic operation is 10x slower.

`single` benchmark increments a single location in an array 1000
times.  The difference is much more drastic (~140x) presumably because
the compiler elides the loads and stores for the nonatomic case.
