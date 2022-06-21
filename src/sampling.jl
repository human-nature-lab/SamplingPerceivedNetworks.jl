# sampling.jl

# sampling bins

function setuplists(dₘₐₓ)
    population = Dict{Tuple{Int, Bool}, Vector{Tuple{String, String}}}()
    for s in Iterators.product(1:dₘₐₓ, [true, false])
        population[s] = Vector{Tuple{String, String}}()
    end
    return population
end

function samplingbins(orbit, dₘₐₓ)
    population = setuplists(dₘₐₓ)
    _samplingbins!(population, orbit)
    return population
end

function _samplingbins!(population, orbit)
    for e in edges(orbit)
        d, rl = get_prop(orbit, e, :d), get_prop(orbit, e, :real)
        p1, p2 = get_prop(orbit, src(e), :name), get_prop(orbit, dst(e), :name)
        push!(population[d, rl], (p1, p2))
    end
    return
end

# sampling

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

function samplebins(
    rng,
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
        append!(coglist, sample(rng, realset, rnum; replace = false))
        
        if moreinfo
            append!(degrees, fill(d, rnum))
            append!(realness, fill(true, rnum))
        end
        
        ws += rw # total wanted up to this point
        ts += rnum # add number actually sampled
        
        gap = ws - ts # num. units still wanted, try to pick these up
        fnum = min(length(fakeset), fw + gap)
        append!(coglist, sample(rng, fakeset, fnum; replace = false))

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
