# orbit.jl

# perceiver's social orbit

"""
        vertexorbit(graph::T, vertex, dₘₐₓ; index = true) where T <: MetaGraph

Generate the social orbit of a perceiver on an undirected, unweighted network
(a `MetaGraph` whose vertices have a `:name` property). The orbit contains
everyone within `dₘₐₓ` steps of the perceiver, who is removed from the returned
graph. Edges carry the properties `:d` (distance) and `:real` (whether the tie
exists in `graph`).

If `index` is true, `vertex` is the vertex index; otherwise it is the node name,
which requires `set_indexing_prop!(graph, :name)`. `name` is the property that
holds node names.
"""
function vertexorbit(graph::T, vertex, dₘₐₓ; index = true, name = :name) where T <: MetaGraph
    if index
        vname = get_prop(graph, vertex, name)
        v = vertex
    elseif !index
        v = graph[vertex, name]
        vname = vertex
    end

    rad = maxnet(graph, v, dₘₐₓ)
    _vertexorbit!(rad, dₘₐₓ, graph, v)

    # remove the perceiver
    v = rad[vname, name]
    rem_vertex!(rad, v)

    return rad
end

function _vertexorbit!(rad, dₘₐₓ, graph, v)
    for d in dₘₐₓ - 1 : -1 : 1
        gd = egonet(graph, v, d)
        
        addreals!(rad, gd, d)
        add_counterfacts!(rad, gd, d)
    end
    return rad
end

"""
        vertexorbit_d(rad, d) where T <: MetaGraph

Restrict a social orbit to the ties that first appear at distance `d`, removing
those at all other distances. `rad` is the output of `vertexorbit`.
"""
function vertexorbit_d(rad::T, d) where T <: MetaGraph
    radᵢ = deepcopy(rad);

    einc = fill(false, length(edges(rad)));
    for (i, e) in enumerate(edges(rad))
        einc[i] = get_prop(rad, e, :d) == d ? true : false
    end

    for (e, o) in zip(edges(rad), einc)
        if !o
            rem_edge!(radᵢ, e)
        end
    end

    rem_names = String[]
    for v in vertices(radᵢ)
        if degree(radᵢ, v) == 0
            push!(rem_names, get_prop(radᵢ, v, :name))
        end
    end

    for nm in rem_names
        rem_vertex!(radᵢ, radᵢ[nm, :name])
    end
    
    return radᵢ
end


# inner functions

function add_counterfacts!(gₘₐₓ, gd, d)

    # counterfactual
    gdc = complete_graph(nv(gd))
    fakeadd = setdiff(edges(gdc), edges(gd))

    # test to ensure no overlap
    # intersect(fakeadd, collect(edges(gmax)))

    # add counterfactual edges
    for e in fakeadd
        add_edge!(gₘₐₓ, e)
        set_prop!(gₘₐₓ, e, :real, false)
        set_prop!(gₘₐₓ, e, :d, d)
    end
    return gₘₐₓ
end

function addreals!(gₘₐₓ, gd, d)
    for e in edges(gd)
        srcname = get_prop(gd, src(e), :name)
        dstname = get_prop(gd, dst(e), :name)
        
        enme = Edge(gₘₐₓ[srcname, :name], gₘₐₓ[dstname, :name])
        set_prop!(gₘₐₓ, enme, :d, d)
        set_prop!(gₘₐₓ, enme, :real, true)

    end
    return gd
end

"""
        maxnet(graph, v, dₘₐₓ)

Construct the ego network for vertex (v) out to dₘₐₓ, and add counterfactual
ties. Label each tie as real or counterfactual with a boolean for real.
"""
function maxnet(graph, v, dₘₐₓ)

    gₘₐₓ = egonet(graph, v, dₘₐₓ)
    set_indexing_prop!(gₘₐₓ, :name)

    # set properties on the real edges
    for e in edges(gₘₐₓ)
        set_prop!(gₘₐₓ, e, :d, dₘₐₓ)
        set_prop!(gₘₐₓ, e, :real, true)
    end

    # add the counterfactual ties at dₘₐₓ
    add_counterfacts!(gₘₐₓ, gₘₐₓ, dₘₐₓ)

    return gₘₐₓ
end
