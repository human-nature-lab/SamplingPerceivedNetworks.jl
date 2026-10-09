# samplebins.jl

"""
        samplebins(
            [rng],
            bins;
            desired = deployed_design.desired, dvals = deployed_design.dvals,
            moreinfo = false, carryover = true, outer = nothing
        )

Sample from `bins` to generate the CSS list for one perceiver, as a vector of
pairs. With `moreinfo = true`, also return the degree bin and the reality of
each pair. `dvals` must be in increasing order.

If `rng` is given, every draw uses it. `samplenetwork` passes each perceiver's
own seeded generator.

When a bin, given as (degree, reality), is smaller than the desired number, other bins are oversampled so that the total desired number (or the maximum possible number) is reached for that survey.

With `carryover = true` (the default), shortfalls are carried forward. A real bin that cannot supply the desired number is topped up from the real bin at the next degree. A real shortfall remaining after the last degree is made up from the counterfactual bins.

With `outer = (r, f)`, an outer bin of all remaining eligible pairs (a member
beyond dₘₐₓ, or unreachable) supplies `r` real and `f` counterfactual pairs.
It is the last bin in the carry-over order. `bins` must then contain the keys
`(0, true)` and `(0, false)`, which `samplenetwork` builds; its degree label
is `0`.

Arguments
≡≡≡≡≡≡≡≡≡≡≡
- [rng] : random number generator, e.g., `MersenneTwister(2)`
- bins: full sampling bins from which to sample
- desired: tuple of (# real, # counterfactual) for each degree bin in `dvals`
- dvals: degree bins, in increasing order; each is an integer or a range of integers (combining degrees into one bin). Must be the same length as `desired`
- moreinfo: if true, also return the degree bin and the reality of each pair
- carryover: if false, a bin smaller than desired is not made up from other bins, so the list is shorter; this is the procedure as described in Feltham et al. (2025)
- outer: `nothing` (the default, as deployed) or (# real, # counterfactual) for the outer bin
"""
function samplebins(
    rng,
    bins;
    desired = deployed_design.desired, dvals = deployed_design.dvals,
    moreinfo = false, carryover = true, outer = nothing
)

    _checkspec(desired, dvals, outer)

    # if moreinfo, initialize objects for storage
    degrees = Vector{Union{Int, UnitRange{Int}}}()
    realness = Vector{Bool}()

    # initialize object for list storage
    coglist = Vector{Tuple{String, String}}()

    _samplebins!(
        rng, coglist, degrees, realness, bins, desired, dvals, moreinfo, carryover,
        outer
    )

    if moreinfo
        return coglist, degrees, realness
    else
        return coglist
    end
end

function samplebins(
    bins;
    desired = deployed_design.desired, dvals = deployed_design.dvals,
    moreinfo = false, carryover = true, outer = nothing
)
    return samplebins(
        Random.default_rng(), bins;
        desired = desired, dvals = dvals, moreinfo = moreinfo,
        carryover = carryover, outer = outer
    )
end
