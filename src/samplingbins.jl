# sampling.jl

# sampling bins

function setuplists(dₘₐₓ)
    population = Dict{Tuple{Int, Bool}, Vector{Tuple{String, String}}}()
    for s in Iterators.product(1:dₘₐₓ, [true, false])
        population[s] = Vector{Tuple{String, String}}()
    end
    return population
end

"""
        samplingbins(orbit, dₘₐₓ)

Generate all possible edges that could appear in a sampling bin. These are the
sets from which we sample.
"""
function samplingbins(orbit, dₘₐₓ)
    population = setuplists(dₘₐₓ)
    _samplingbins!(population, orbit)
    return population
end

"""
        samplingbins(orbit, dₘₐₓ, consents)

Generate all possible edges that could appear in a sampling bin. These are the
sets from which we sample.

Filter out pairs that are not consented for their photos.

Arguments
≡≡≡≡≡≡≡≡≡≡≡
- orbit
- dₘₐₓ
- consents: the map from each node id to its consent status.
"""
function samplingbins(orbit, dₘₐₓ, consents)
    population = setuplists(dₘₐₓ)
    _samplingbins!(population, orbit, consents)
    return population
end

function _samplingbins!(population, orbit)
    for e in edges(orbit)
        d, rl = get_prop(orbit, e, :d), get_prop(orbit, e, :real)
        p1, p2 = get_prop(orbit, src(e), :name), get_prop(orbit, dst(e), :name)
        push!(population[d, rl], (p1, p2))
    end
end

function _samplingbins!(population, orbit, consents)
    for e in edges(orbit)
        d, rl = get_prop(orbit, e, :d), get_prop(orbit, e, :real)
        p1, p2 = get_prop(orbit, src(e), :name), get_prop(orbit, dst(e), :name)

        # only add if both nodes have consented to photo
        if consented(p1, p2, consents)
            push!(population[d, rl], (p1, p2))
        end
    end
end

"""
        consented!(p1, p2, consents)

Check whether a node in the pair has not consented. If so, signal 'false'.

2 is defined as consented to survey and photo. All other values do not have
consent to use of photo (and are not usable).
"""
function consented(p1, p2, consents)
    return if (consents[p1] != 2) | (consents[p2] != 2)
        false
    else
        true
    end
end
