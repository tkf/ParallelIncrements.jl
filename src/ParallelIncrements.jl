module ParallelIncrements

export atomicref

using Base: gc_alignment, llvmcall
using Base.Threads: ArithmeticTypes, WORD_SIZE, atomictypes, inttype, llvmtypes
using BenchmarkTools

struct AtomicRef{T,A} <: Ref{T}
    pointer::Ptr{T}
    x::A
end

atomicref(x, args...) = AtomicRef(pointer(x, args...), x)

include("atomics.jl")

function seq_unsafe_incrementat!(dest, indices)
    @inbounds for i in indices
        dest[i] += one(eltype(dest))
    end
    return dest
end

function unsafe_incrementat!(dest, indices)
    for i in indices
        r = atomicref(dest, i)
        Threads.atomic_add!(r, one(eltype(dest)))
    end
    return dest
end

function benchsuite()
    suite = BenchmarkGroup()
    let s1 = suite["single"] = BenchmarkGroup()
        s1["atomic"] = @benchmarkable(
            begin
                fill!(dest, 0)
                for _ in 1:1000
                    r = atomicref(dest, 1)
                    Threads.atomic_add!(r, one(eltype(dest)))
                end
            end,
            setup = (dest = [0]),
        )
        s1["nonatomic"] = @benchmarkable(begin
            fill!(dest, 0)
            for _ in 1:1000
                @inbounds dest[1] += 1
            end
        end, setup = (dest = [0]))
    end
    for n in [1_000]
        s1 = suite["n=$n"] = BenchmarkGroup()
        dest = zeros(Int, n)
        for m in [1_000_000]
            indices = rand(eachindex(dest), m)
            s2 = s1["m=$m"] = BenchmarkGroup()
            s2["nonatomic"] = @benchmarkable(
                seq_unsafe_incrementat!($dest, $indices),
                setup = (fill!($dest, 0))
            )
            s2["atomic"] = @benchmarkable(
                unsafe_incrementat!($dest, $indices),
                setup = (fill!($dest, 0))
            )
        end
    end
    return suite
end

end # module
