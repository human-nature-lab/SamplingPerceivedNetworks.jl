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
    
    ws = 0; ts = 0;

    for (sz, d) in zip(desired, dvals)
        rw, fw = sz
        if typeof(d) == UnitRange{Int}
            fakeset = reduce(vcat, [bins[x, false] for x in d]);
            realset = reduce(vcat, [bins[x, true] for x in d]);
        else
            fakeset = bins[d, false];
            realset = bins[d, true];
        end

        gap = ws - ts # num. units still wanted, try to pick these up

        rnum = min(length(realset), rw + gap)
        append!(coglist, sample(realset, rnum; replace = false))
        
        if moreinfo
            append!(degrees, fill(d, rnum))
            append!(realness, fill(true, rnum))
        end
        
        ws += rw # total wanted up to this point
        ts += rnum # add number actually sampled
        
        gap = ws - ts # num. units still wanted, try to pick these up
        fnum = min(length(fakeset), fw + gap)
        append!(coglist, sample(fakeset, fnum; replace = false))

        if moreinfo
            append!(degrees, fill(d, fnum))
            append!(realness, fill(false, fnum))
        end

        ws += fw # total wanted up to this point
        ts += fnum # add number actually sampled (including possibly extra for gap)
    end

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
    
    #=
    tie sample counting
    - used to account for smaller-than-desired bins and consequent
      oversampling of other bins to fill the gap.
    
    ws: total wanted up to that point
    ts: number actually sampled up to that point
    (ws - ts) gives the sampling gap
    =#
    ws = 0; ts = 0;

    for (sz, d) in zip(desired, dvals)
        rw, fw = sz # real wanted, fake wanted

        # setup: get the relevant object from which to sample

        if typeof(d) == UnitRange{Int}
            # if it is a range, take the union of the degree bins over the range
            fakeset = reduce(vcat, [bins[x, false] for x in d]);
            realset = reduce(vcat, [bins[x, true] for x in d]);
        else
            # if a single degree, just take the bin
            fakeset = bins[d, false];
            realset = bins[d, true];
        end

        # execution: perform sampling, adjusting for ws and ts

        # real ties

        gap = ws - ts # num. units still wanted (try to pick these up)

        rnum = min(length(realset), rw + gap) # this is the number that will actually be sampled at this step
        append!(coglist, sample(rng, realset, rnum; replace = false))
        
        if moreinfo
            append!(degrees, fill(d, rnum))
            append!(realness, fill(true, rnum))
        end
        
        # total wanted up to this point (wholly determined by dvals)
        ws += rw

        #=
        add number actually sampled
        including possibly extra for gap -> rnum will include the portion of the gap that has been filled 
        We simply want to add the number sampled, to know whether we have closed the gap, and need to continue
        to overample)
        =#
        ts += rnum
        
        # fake ties

        gap = ws - ts # num. units still wanted (try to pick these up)
        fnum = min(length(fakeset), fw + gap)
        append!(coglist, sample(rng, fakeset, fnum; replace = false))

        if moreinfo
            append!(degrees, fill(d, fnum))
            append!(realness, fill(false, fnum))
        end

        ws += fw # total wanted up to this point
        ts += fnum # add number actually sampled
    end

    if moreinfo
        return coglist, degrees, realness
    else
        return coglist
    end
end
