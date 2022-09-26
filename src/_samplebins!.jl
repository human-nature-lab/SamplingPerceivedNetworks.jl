# _samplebins!.jl

"""
        mk_binset(bins, d::UnitRange{Int}, boolean)

Extract the set from which to sample for a bin defined by a degree range, e.g., 1:2.
"""
function mk_binset(bins, d::UnitRange{Int}, boolean)
    # if it is a range, take the union of the degree bins over the range
    set = reduce(vcat, [bins[x, boolean] for x in d]);

    return set
end

"""
        mk_binset(bins, d::Int, boolean)

Extract the set from which to sample for a bin defined by a single degree, e.g., 2.
"""
function mk_binset(bins, d::Int, boolean)
    # if a single degree, just take the bin
    return bins[d, boolean]
end

"""
        _samplebins!(coglist, bins, desired, dvals, moreinfo)

See samplebins.
"""
function _samplebins!(coglist, bins, desired, dvals, moreinfo)

    #=
    tie sample counting
    - used to account for smaller-than-desired bins and consequent
      oversampling of other bins to fill the gap.
    
    ws: total wanted up to that point
    ts: number actually sampled up to that point
    (ws - ts) gives the sampling gap
    =#

    ws = 0; # tracks the number wanted (over the iterations)
    ts = 0; # tracks the number actually sampled (over the iterations)

    # real ties
    for (sz, d) in zip(desired, dvals)
        rw = sz[1] # real wanted

        # setup: get the relevant object from which to sample

        realset = mk_binset(bins, d, true)

        # execution: perform sampling, adjusting for ws and ts

        gap = ws - ts # num. units still wanted (try to pick these up)

        rnum = min(length(realset), rw + gap) # this is the number that will actually be sampled at this step
        append!(coglist, sample(realset, rnum; replace = false))
        
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
    end

    #=
    the gap (if any left over across all of the true ties) carries over to
    the fake tie sampling.
    =#

    # fake ties
    for (sz, d) in zip(desired, dvals)
        fw = sz[2] # fake wanted

        # setup: get the relevant object from which to sample

        fakeset = mk_binset(bins, d, false)

        # execution: perform sampling, adjusting for ws and ts

        gap = ws - ts # num. units still wanted (try to pick these up)
        
        fnum = min(length(fakeset), fw + gap)
        append!(coglist, sample(fakeset, fnum; replace = false))

        if moreinfo
            append!(degrees, fill(d, fnum))
            append!(realness, fill(false, fnum))
        end

        ws += fw # total wanted up to this point
        ts += fnum # add number actually sampled
    end
end

function _samplebins!(rng, coglist, bins, desired, dvals, moreinfo)

    #=
    tie sample counting
    - used to account for smaller-than-desired bins and consequent
      oversampling of other bins to fill the gap.
    
    ws: total wanted up to that point
    ts: number actually sampled up to that point
    (ws - ts) gives the sampling gap
    =#

    ws = 0; # tracks the number wanted (over the iterations)
    ts = 0; # tracks the number actually sampled (over the iterations)

    # real ties
    for (sz, d) in zip(desired, dvals)
        rw = sz[1] # real wanted

        # setup: get the relevant object from which to sample

        realset = mk_binset(bins, d, true)

        # execution: perform sampling, adjusting for ws and ts

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
    end

    #=
    the gap (if any left over across all of the true ties) carries over to
    the fake tie sampling.
    =#

    # fake ties
    for (sz, d) in zip(desired, dvals)
        fw = sz[2] # fake wanted

        # setup: get the relevant object from which to sample

        fakeset = mk_binset(bins, d, false)

        # execution: perform sampling, adjusting for ws and ts

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
end
