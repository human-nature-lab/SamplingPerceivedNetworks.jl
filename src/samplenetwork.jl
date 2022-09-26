# whole_network.jl
# sampling lists for the whole network

VerticesList1 = Dict{String, Vector{Tuple{String, String}}};
VerticesList2 = Dict{String, Tuple{Vector{Tuple{String, String}}, Vector{Union{Int, UnitRange}}, Vector{Bool}}};

function verticeslist(moreinfo)
    return if !moreinfo
        VerticesList1()
    else
        VerticesList2()
    end
end

"""
        samplenetwork(
            [rng],
            graph;
            desired = ((10, 10), (5, 5), (5, 5)), dvals = (1:2, 3, 4),
            moreinfo = false,
            shuffle = true
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

Optionally specify a random number generator (rng).
"""
function samplenetwork(
    rng,
    graph;
    desired = ((10, 10), (5, 5), (5, 5)), dvals = (1:2, 3, 4),
    moreinfo = false,
    shuffle = true
)    

    dₘₐₓ = maximum(reduce(vcat, dvals))

    verticeslists = verticeslist(moreinfo)

    #= 
    alternative to vertices lists
    this alternative requires rewriting samplebins
    which currently outputs in the Dict{String, Vector{Tuple}} format
    note that we need to sample all at once, since it is w/o replacement
    =#
    # edgetab = init_edgetable(nv(graph) * countdesired(desired), moreinfo);
    
    # create a seed number for each perceiver
    # using village seed (input exogenously)
    seeds = sample(
        rng, 1:typemax(Int), nv(graph);
        replace = false
    );

    sizehint!(verticeslists, nv(graph))
    _samplenet!(
        seeds, verticeslists, graph, dₘₐₓ, desired, dvals, moreinfo, shuffle
    )
    
    return verticeslists
end

function _samplenet!(
    verticeslists, graph, dₘₐₓ, desired, dvals, moreinfo, shuffle
)
    for v in vertices(graph)
        rad = vertexorbit(graph, v, dₘₐₓ); # 2.79 MiB
        bins = samplingbins(rad, dₘₐₓ);
    
        verticeslists[get_prop(graph, v, :name)] = samplebins(
            bins;
            desired = desired,
            dvals = dvals,
            moreinfo = moreinfo
        )

        if shuffle
            # length of the list of pairs
            ln = length(verticeslists[get_prop(graph, v, :name)][1]);
            if ln > 1 # if there is more than one valid pair
                # shuffle the pairs for random presentation
                idx = sample(collect(1:ln), ln; replace = false)
                # iterate over the info types (pairs, degree, realness)
                for i in eachindex(verticeslists[get_prop(graph, v, :name)])
                    permute!(verticeslists[get_prop(graph, v, :name)][i], idx)
                end
            end
        end
    end
end

# consent versions

"""
        samplenetwork(
            [rng],
            graph,
            consents;
            desired = ((10, 10), (5, 5), (5, 5)), dvals = (1:2, 3, 4),
            moreinfo = false,
            shuffle = true
        )

Given an unweighted and undirected sociocentric network, generate
a list of relationships to show each person in the network, based on the
"social orbit" procedure. Sample a number at each degree, for real vs.
counterfactual, according to the amounts specified by desired for each degree
given by `dvals`.

`desired` and `dvals` are in the same order. `dvals` contains either
integers, or integer ranges (for the combination of degrees into one bin).
`desired` is a list of tuples, where each element corresponds to the
degree bin specified by `dvals`, at that index.
The format is (# real, # counterfactual)).

Optionally specify a random number generator (rng).
"""
function samplenetwork(
    rng,
    graph,
    consents;
    desired = ((10, 10), (5, 5), (5, 5)), dvals = (1:2, 3, 4),
    moreinfo = false,
    shuffle = true
)    

    dₘₐₓ = maximum(reduce(vcat, dvals))

    verticeslists = verticeslist(moreinfo)

    # alternative to vertices lists
    # edgetab = init_edgetable(nv(graph) * countdesired(desired), moreinfo);

    # create a seed number for each perceiver
    # using village seed (input exogenously)
    seeds = sample(
        rng, 1:typemax(Int), nv(graph);
        replace = false
    );

    sizehint!(verticeslists, nv(graph))
    _samplenet!(
        seeds, verticeslists, graph, consents,
        dₘₐₓ, desired, dvals, moreinfo, shuffle
    )
    
    return verticeslists
end

function samplenetwork(
    graph;
    desired = ((10, 10), (5, 5), (5, 5)), dvals = (1:2, 3, 4),
    moreinfo = false,
    shuffle = true
)    

    dₘₐₓ = maximum(reduce(vcat, dvals))

    verticeslists = verticeslist(moreinfo)
    
    sizehint!(verticeslists, nv(graph))
    _samplenet!(verticeslists, graph, dₘₐₓ, desired, dvals, moreinfo, shuffle)
    
    return verticeslists
end
