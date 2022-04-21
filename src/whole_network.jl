# whole_network.jl

# sampling lists for the whole network

"""
        samplenetwork(
            graph;
            desired = ((10, 10), (5, 5), (5, 5)), dvals = (1:2, 3, 4),
            moreinfo = false
        )

Given an unweighted and undirected sociocentric network, generate
a list of relationships to show each person in the network, based on the
"social orbit" procedure. Sample a number at each degree, for real vs.
counterfactual, according to the amounts specified by desired for each degree
given by `dvals`.

`desired` and `dvals` are in the same order. `dvals` contains either
integers, or integer ranges (for the combination of degrees into one bin). `desired` is a list of tuples, where each element corresponds to the
degree bin specified by `dvals`, at that index.
The format is (# real, # counterfactual)).
"""
function samplenetwork(
    graph;
    desired = ((10, 10), (5, 5), (5, 5)), dvals = (1:2, 3, 4),
    moreinfo = false
)    

    dₘₐₓ = maximum(reduce(vcat, dvals))

    verticeslists = if !moreinfo
        Dict{String, Vector{Tuple{String, String}}}()
    else
        Dict{String, Tuple{Vector{Tuple{String, String}}, Vector{Union{Int, UnitRange}}, Vector{Bool}}}()
    end
    
    sizehint!(verticeslists, nv(graph))
    _samplenet!(verticeslists, graph, dₘₐₓ, desired, dvals, moreinfo)
    
    return verticeslists
end

function _samplenet!(verticeslists, graph, dₘₐₓ, desired, dvals, moreinfo)
    for v in vertices(graph)
        rad = vertexorbit(graph, v, dₘₐₓ); # 2.79 MiB
        bins = samplingbins(rad, dₘₐₓ);
    
        verticeslists[get_prop(graph, v, :name)] = samplebins(
            bins;
            desired = desired, dvals = dvals, moreinfo = moreinfo
        )
    end
end
