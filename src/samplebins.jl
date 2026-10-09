# samplebins.jl

"""
        samplebins(
            [rng],
            bins;
            desired = deployed_design.desired, dvals = deployed_design.dvals,
            moreinfo = false
        )

Sample from `bins` to generate the CSS list for one perceiver, as a vector of
pairs. With `moreinfo = true`, also return the degree bin and the reality of
each pair. `dvals` must be in increasing order.

If `rng` is given, every draw uses it. `samplenetwork` passes each perceiver's
own seeded generator.

When a bin, given as (degree, reality), is smaller than the desired number, other bins are oversampled so that the total desired number (or the maximum possible number) is reached for that survey.

Shortfalls are carried forward. A real bin that cannot supply the desired number is topped up from the real bin at the next degree. A real shortfall remaining after the last degree is made up from the counterfactual bins.

Arguments
≡≡≡≡≡≡≡≡≡≡≡
- [rng] : random number generator, e.g., `MersenneTwister(2)`
- bins: full sampling bins from which to sample
- desired: tuple of (# real, # counterfactual) for each degree bin in `dvals`
- dvals: degree bins, in increasing order; each is an integer or a range of integers (combining degrees into one bin). Must be the same length as `desired`
- moreinfo: if true, also return the degree bin and the reality of each pair
"""
function samplebins(
    rng,
    bins;
    desired = deployed_design.desired, dvals = deployed_design.dvals,
    moreinfo = false
)

    _checkspec(desired, dvals)

    # if moreinfo, initialize objects for storage
    degrees = Vector{Union{Int, UnitRange{Int}}}()
    realness = Vector{Bool}()

    # initialize object for list storage
    coglist = Vector{Tuple{String, String}}()
    
    _samplebins!(rng, coglist, degrees, realness, bins, desired, dvals, moreinfo)

    if moreinfo
        return coglist, degrees, realness
    else
        return coglist
    end
end

function samplebins(
    bins;
    desired = deployed_design.desired, dvals = deployed_design.dvals,
    moreinfo = false
)
    return samplebins(
        Random.default_rng(), bins;
        desired = desired, dvals = dvals, moreinfo = moreinfo
    )
end
