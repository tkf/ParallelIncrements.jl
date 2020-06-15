# Based on atomics_base.jl which was copied from base/atomics.jl in julia

for typ in atomictypes
    lt = llvmtypes[typ]
    ilt = llvmtypes[inttype(typ)]
    rt = "$lt, $lt*"
    irt = "$ilt, $ilt*"
    @eval Base.getindex(ref::AtomicRef{$typ}) = let __x = ref.x; GC.@preserve __x begin
        llvmcall($"""
                 %ptr = inttoptr i$WORD_SIZE %0 to $lt*
                 %rv = load atomic $rt %ptr acquire, align $(gc_alignment(typ))
                 ret $lt %rv
                 """, $typ, Tuple{Ptr{$typ}}, ref.pointer)
    end end
    @eval Base.setindex!(ref::AtomicRef{$typ}, v::$typ) = let __x = ref.x; GC.@preserve __x begin
        llvmcall($"""
                 %ptr = inttoptr i$WORD_SIZE %0 to $lt*
                 store atomic $lt %1, $lt* %ptr release, align $(gc_alignment(typ))
                 ret void
                 """, Cvoid, Tuple{Ptr{$typ}, $typ}, ref.pointer, v)
    end end
    # Note: atomic_cas! succeeded (i.e. it stored "new") if and only if the result is "cmp"
    if typ <: Integer
        @eval Threads.atomic_cas!(ref::AtomicRef{$typ}, cmp::$typ, new::$typ) = let __x = ref.x; GC.@preserve __x begin
            llvmcall($"""
                     %ptr = inttoptr i$WORD_SIZE %0 to $lt*
                     %rs = cmpxchg $lt* %ptr, $lt %1, $lt %2 acq_rel acquire
                     %rv = extractvalue { $lt, i1 } %rs, 0
                     ret $lt %rv
                     """, $typ, Tuple{Ptr{$typ},$typ,$typ},
                     ref.pointer, cmp, new)
        end end
    else
        @eval Threads.atomic_cas!(ref::AtomicRef{$typ}, cmp::$typ, new::$typ) = let __x = ref.x; GC.@preserve __x begin
            llvmcall($"""
                     %iptr = inttoptr i$WORD_SIZE %0 to $ilt*
                     %icmp = bitcast $lt %1 to $ilt
                     %inew = bitcast $lt %2 to $ilt
                     %irs = cmpxchg $ilt* %iptr, $ilt %icmp, $ilt %inew acq_rel acquire
                     %irv = extractvalue { $ilt, i1 } %irs, 0
                     %rv = bitcast $ilt %irv to $lt
                     ret $lt %rv
                     """, $typ, Tuple{Ptr{$typ},$typ,$typ},
                     ref.pointer, cmp, new)
        end end
    end

    arithmetic_ops = [:add, :sub]
    for rmwop in [arithmetic_ops..., :xchg, :and, :nand, :or, :xor, :max, :min]
        rmw = string(rmwop)
        fn = Symbol("atomic_", rmw, "!")
        if (rmw == "max" || rmw == "min") && typ <: Unsigned
            # LLVM distinguishes signedness in the operation, not the integer type.
            rmw = "u" * rmw
        end
        if rmwop in arithmetic_ops && !(typ <: ArithmeticTypes) continue end
        if typ <: Integer
            @eval Threads.$fn(ref::AtomicRef{$typ}, v::$typ) = let __x = ref.x; GC.@preserve __x begin
                llvmcall($"""
                         %ptr = inttoptr i$WORD_SIZE %0 to $lt*
                         %rv = atomicrmw $rmw $lt* %ptr, $lt %1 acq_rel
                         ret $lt %rv
                         """, $typ, Tuple{Ptr{$typ}, $typ}, ref.pointer, v)
            end end
        else
            rmwop === :xchg || continue
            @eval Threads.$fn(ref::AtomicRef{$typ}, v::$typ) = let __x = ref.x; GC.@preserve __x begin
                llvmcall($"""
                         %iptr = inttoptr i$WORD_SIZE %0 to $ilt*
                         %ival = bitcast $lt %1 to $ilt
                         %irv = atomicrmw $rmw $ilt* %iptr, $ilt %ival acq_rel
                         %rv = bitcast $ilt %irv to $lt
                         ret $lt %rv
                         """, $typ, Tuple{Ptr{$typ}, $typ}, ref.pointer, v)
            end end
        end
    end
end
