# _samplebins!.jl

"""
        mk_binset(bins, d::AbstractRange{<:Integer}, boolean)

Extract the set from which to sample for a bin defined by a degree range, e.g., 1:2.
"""
function mk_binset(bins, d::AbstractRange{<:Integer}, boolean)
    # if it is a range, take the union of the degree bins over the range
    return reduce(vcat, [_getbin(bins, x, boolean) for x in d])
end

"""
        mk_binset(bins, d::Integer, boolean)

Extract the set from which to sample for a bin defined by a single degree, e.g., 2.
"""
function mk_binset(bins, d::Integer, boolean)
    # if a single degree, just take the bin
    return _getbin(bins, d, boolean)
end

function _getbin(bins, d, boolean)
    haskey(bins, (d, boolean)) || throw(ArgumentError(
        "bins has no entry for degree $d (real = $boolean); " *
        "were the bins built with a smaller dₘₐₓ than `dvals` requires?"
    ))
    return bins[d, boolean]
end

# `desired` and `dvals` must pair up, and each element of `dvals` must be a
# nonempty integer or integer range of degrees >= 1; `outer`, if given, is one
# (# real, # counterfactual) tuple
function _checkspec(desired, dvals, outer = nothing)
    length(desired) == length(dvals) || throw(ArgumentError(
        "desired has $(length(desired)) elements but dvals has " *
        "$(length(dvals)); they must match"
    ))
    isempty(dvals) && throw(ArgumentError("dvals must not be empty"))
    for d in dvals
        d isa Integer || (d isa AbstractRange{<:Integer} && !isempty(d)) ||
            throw(ArgumentError(
                "each element of dvals must be an integer or a nonempty " *
                "integer range; got $d"
            ))
        minimum(d) >= 1 || throw(ArgumentError(
            "degrees in dvals must be at least 1; got $d"
        ))
    end
    outer === nothing ||
        (length(outer) == 2 && all(x -> x isa Integer && x >= 0, outer)) ||
        throw(ArgumentError(
            "outer must be nothing or a tuple (# real, # counterfactual) " *
            "of nonnegative integers; got $outer"
        ))
    return nothing
end

#=
Bin labels. A degree bin is labelled by its element of `dvals`. Two labels
mark pairs from outside the degree bins:
- OUTERBIN (0): the outer bin, every eligible pair beyond the last degree bin
  (a member farther than dₘₐₓ from the perceiver, or unreachable);
- FILLBIN (-1): drawn village-wide, by the fill to the target length or for
  an isolate (see `samplevillage`).
=#
const OUTERBIN = 0
const FILLBIN = -1

_binlabel(d) = d == OUTERBIN ? "outer" : d == FILLBIN ? "fill" : string(d)

"""
        _cells(bins, desired, dvals, outer)

The sampling cells in draw order, `(realsets, fakesets, desired, labels)`:
one entry per element of `dvals`, plus a last entry for the outer bin when
`outer` is a tuple. Shared by the sampler and `inclusionprobs`.
"""
function _cells(bins, desired, dvals, outer)
    realsets = [mk_binset(bins, d, true) for d in dvals]
    fakesets = [mk_binset(bins, d, false) for d in dvals]
    labels = Any[d for d in dvals]
    desired = collect(desired)
    if outer !== nothing
        haskey(bins, (OUTERBIN, true)) && haskey(bins, (OUTERBIN, false)) ||
            throw(ArgumentError(
                "bins have no outer bin (keys ($OUTERBIN, true) and " *
                "($OUTERBIN, false)); `samplenetwork` builds it when " *
                "`outer` is given"
            ))
        push!(realsets, bins[OUTERBIN, true])
        push!(fakesets, bins[OUTERBIN, false])
        push!(desired, Tuple(outer))
        push!(labels, OUTERBIN)
    end
    return realsets, fakesets, desired, labels
end

"""
        _quotas(realsizes, fakesizes, desired; carryover = true)

Number to draw from each real and each counterfactual bin, given the bin
sizes: `(nreal, nfake)`, vectors with one entry per element of `desired`.
Depends only on the sizes, so it is shared by the sampler and by
`inclusionprobs`.

With `carryover`, a bin smaller than desired passes its shortfall to the later
bins, and a shortfall left over after the last real bin carries into the
counterfactual bins. Without it, each bin supplies at most its own desired
number, so a short bin gives a short list.
"""
function _quotas(realsizes, fakesizes, desired; carryover = true)
    ws = 0 # number wanted (over the iterations)
    ts = 0 # number actually drawn (over the iterations)
    nr = zeros(Int, length(desired))
    nf = zeros(Int, length(desired))

    # real ties
    for (i, sz) in enumerate(desired)
        # (ws - ts) is the gap: units still wanted from earlier bins
        nr[i] = min(realsizes[i], sz[1] + (carryover ? ws - ts : 0))
        ws += sz[1]
        ts += nr[i]
    end

    # fake ties: any gap left over across the real ties carries over
    for (i, sz) in enumerate(desired)
        nf[i] = min(fakesizes[i], sz[2] + (carryover ? ws - ts : 0))
        ws += sz[2]
        ts += nf[i]
    end
    return nr, nf
end

"""
        _samplebins!(rng, coglist, degrees, realness, bins, desired, dvals, moreinfo, carryover, outer)

See samplebins.
"""
function _samplebins!(
    rng, coglist, degrees, realness, bins, desired, dvals, moreinfo, carryover,
    outer = nothing
)
    # the outer bin, if any, is the last cell: it takes part in the carry-over
    realsets, fakesets, desired, labels = _cells(bins, desired, dvals, outer)
    nr, nf = _quotas(length.(realsets), length.(fakesets), desired; carryover = carryover)

    # real ties first, then counterfactual (the order fixes the rng stream)
    for (sets, ns, rl) in ((realsets, nr, true), (fakesets, nf, false))
        for (set, n, d) in zip(sets, ns, labels)
            append!(coglist, sample(rng, set, n; replace = false))
            if moreinfo
                append!(degrees, fill(d, n))
                append!(realness, fill(rl, n))
            end
        end
    end
    return nothing
end
