# samplebins.jl

function samplebins(
    bins;
    desired = ((10, 10), (5, 5), (5, 5)), dvals = (1:2, 3, 4),
    moreinfo = false
)

    if moreinfo
        degrees = Vector{Union{Int, UnitRange{Int}}}()
        realness = Vector{Bool}()
    end

    coglist = Vector{Tuple{String, String}}()
    
    _samplebins!(rng, coglist, bins, desired, dvals, moreinfo)

    if moreinfo
        return coglist, degrees, realness
    else
        return coglist
    end
end

"""
        samplebins(
            [rng],
            bins;
            desired = ((10, 10), (5, 5), (5, 5)), dvals = (1:2, 3, 4),
            moreinfo = false
        )

Assumes that `dvals` is monotonically ordered.

Sample from `bins` to generate the CSS list for a perceiver (surveyee), as a series of pairs. Optionally, output `moreinfo`: the degree distance and reality of the tie.

If `rng` is specified, use the same rng value for each call to sample. This will
be the perceiver's rng value assigned earlier in the procedure.
N.B. that sample is not called on the same list twice, so it is fine to specify one number in the argument to sample.

When a bin, given as (reality, degree), is smaller than the desired number, other bins are oversampled so that 40 (or the maximum possible number) is reached for that survey.

Compensation procedure:
- try to get as many as possible from the real bin, then try to fill that gap with oversampling for the fake bin for that same degree. If there is a gap, roll that over and try to oversample real ties at the next degree.

Arguments
≡≡≡≡≡≡≡≡≡≡≡
- [rng]
- bins: full sampling bins from which to sample
- desired
- dvals
- moreinfo
"""
function samplebins(
    rng,
    bins;
    desired = ((10, 10), (5, 5), (5, 5)), dvals = (1:2, 3, 4),
    moreinfo = false
)

    # if moreinfo, initialize objects for storage
    if moreinfo
        degrees = Vector{Union{Int, UnitRange{Int}}}()
        realness = Vector{Bool}()
    end

    # initialize object for list storage
    coglist = Vector{Tuple{String, String}}()
    
    _samplebins!(rng, coglist, bins, desired, dvals, moreinfo)

    if moreinfo
        return coglist, degrees, realness
    else
        return coglist
    end
end
