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
# nonempty integer or integer range
function _checkspec(desired, dvals)
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
    end
    return nothing
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
        _samplebins!(rng, coglist, degrees, realness, bins, desired, dvals, moreinfo, carryover)

See samplebins.
"""
function _samplebins!(
    rng, coglist, degrees, realness, bins, desired, dvals, moreinfo, carryover
)
    realsets = [mk_binset(bins, d, true) for d in dvals]
    fakesets = [mk_binset(bins, d, false) for d in dvals]
    nr, nf = _quotas(length.(realsets), length.(fakesets), desired; carryover = carryover)

    # real ties first, then counterfactual (the order fixes the rng stream)
    for (sets, ns, rl) in ((realsets, nr, true), (fakesets, nf, false))
        for (set, n, d) in zip(sets, ns, dvals)
            append!(coglist, sample(rng, set, n; replace = false))
            if moreinfo
                append!(degrees, fill(d, n))
                append!(realness, fill(rl, n))
            end
        end
    end
    return nothing
end
