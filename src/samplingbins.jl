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

Group every candidate pair in `orbit` (the output of `vertexorbit`) into
sampling bins, keyed by `(distance, is_real)`. Each bin is a vector of name
pairs, and the bins are the sets from which `samplebins` draws.
"""
function samplingbins(orbit, dₘₐₓ)
    population = setuplists(dₘₐₓ)
    _samplingbins!(population, orbit)
    return population
end

"""
        samplingbins(orbit, dₘₐₓ, consents)

As `samplingbins(orbit, dₘₐₓ)`, omitting pairs in which either node has not
consented to photos (consent code below 2).

Arguments
≡≡≡≡≡≡≡≡≡≡≡
- orbit: the output of `vertexorbit`
- dₘₐₓ: the maximum distance the orbit was built with
- consents: a map from each node name to its consent code
"""
function samplingbins(orbit, dₘₐₓ, consents)
    population = setuplists(dₘₐₓ)
    _samplingbins!(population, orbit, consents)
    return population
end

function _bin(population, d, rl)
    haskey(population, (d, rl)) || throw(ArgumentError(
        "orbit has an edge at distance $d, beyond the dₘₐₓ the bins were " *
        "set up for; pass the dₘₐₓ used to build the orbit"
    ))
    return population[d, rl]
end

function _samplingbins!(population, orbit)
    for e in edges(orbit)
        d, rl = get_prop(orbit, e, :d), get_prop(orbit, e, :real)
        p1, p2 = get_prop(orbit, src(e), :name), get_prop(orbit, dst(e), :name)
        push!(_bin(population, d, rl), (string(p1), string(p2)))
    end
end

function _samplingbins!(population, orbit, consents)
    for e in edges(orbit)
        d, rl = get_prop(orbit, e, :d), get_prop(orbit, e, :real)
        p1, p2 = get_prop(orbit, src(e), :name), get_prop(orbit, dst(e), :name)

        # only add if both nodes have consented to photo
        if consented(p1, p2, consents)
            push!(_bin(population, d, rl), (string(p1), string(p2)))
        end
    end
end

"""
        consented(p1, p2, consents)

Return true if both nodes in the pair may appear in a photo, that is, if both
have consent code 2 or 3.

0: no consent
1: survey only
2: survey and photo
3: photo only
"""
function consented(p1, p2, consents)
    for p in (p1, p2)
        haskey(consents, p) || throw(ArgumentError(
            "consents has no entry for node $p"
        ))
    end
    return _consent_ok(p1, consents) && _consent_ok(p2, consents)
end

#=
Bins for a perceiver computed directly from the graph, without materializing
the orbit as a MetaGraph. Equivalent to
`samplingbins(vertexorbit(graph, v, dₘₐₓ), dₘₐₓ[, consents])`, including the
order of the pairs within each bin (so that seeded sampling is unchanged).

A pair (a, b) of non-perceiver nodes within dₘₐₓ of v lies in bin
d = max(dist(v, a), dist(v, b)), and is real iff a and b are tied in `graph`.
The ordering reproduces vertexorbit: the vertices of the dₘₐₓ-egonet in
neighborhood order, with the perceiver's slot taken by the last vertex
(as `rem_vertex!` does), and pairs in lexicographic order of position.

With `outer = true`, also build the outer bin under the keys (OUTERBIN, real):
every eligible pair of non-perceiver nodes with at least one member beyond
dₘₐₓ (or unreachable). Its pairs follow the orbit-far pairs, then the
far-far pairs, in vertex order.
=#
function _vertexbins(graph, v, dₘₐₓ, consents = nothing; outer = false)
    population = setuplists(dₘₐₓ)

    nd = Graphs.neighborhood_dists(graph, v, dₘₐₓ)
    verts = first.(nd)
    dists = last.(nd)

    # remove the perceiver (the first entry) the way rem_vertex! does
    p = findfirst(==(v), verts)
    verts[p], dists[p] = verts[end], dists[end]
    pop!(verts); pop!(dists)

    rawnames = [get_prop(graph, u, :name) for u in verts]
    names = string.(rawnames)  # node names need not be Strings
    ok = consents === nothing ? fill(true, length(verts)) :
        [_consent_ok(nm, consents) for nm in rawnames]

    n = length(verts)
    for i in 1:n-1
        ok[i] || continue
        for j in i+1:n
            ok[j] || continue
            rl = has_edge(graph, verts[i], verts[j])
            push!(population[max(dists[i], dists[j]), rl], (names[i], names[j]))
        end
    end

    outer && _outerbin!(population, graph, v, verts, names, ok, consents)
    return population
end

function _outerbin!(population, graph, v, verts, names, ok, consents)
    inorbit = falses(nv(graph)); inorbit[v] = true; inorbit[verts] .= true
    far = [u for u in vertices(graph) if !inorbit[u]]
    rawfar = [get_prop(graph, u, :name) for u in far]
    farnames = string.(rawfar)
    farok = consents === nothing ? fill(true, length(far)) :
        [_consent_ok(nm, consents) for nm in rawfar]

    population[OUTERBIN, true] = Tuple{String, String}[]
    population[OUTERBIN, false] = Tuple{String, String}[]
    # orbit member with a far node
    for i in eachindex(verts), j in eachindex(far)
        ok[i] && farok[j] || continue
        rl = has_edge(graph, verts[i], far[j])
        push!(population[OUTERBIN, rl], (names[i], farnames[j]))
    end
    # two far nodes
    for i in eachindex(far), j in i+1:length(far)
        farok[i] && farok[j] || continue
        rl = has_edge(graph, far[i], far[j])
        push!(population[OUTERBIN, rl], (farnames[i], farnames[j]))
    end
    return population
end

function _consent_ok(name, consents)
    haskey(consents, name) || throw(ArgumentError(
        "consents has no entry for node $name"
    ))
    c = consents[name]
    ismissing(c) && throw(ArgumentError("consent for node $name is missing"))
    return c >= 2
end
