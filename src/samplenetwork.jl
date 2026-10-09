# samplenetwork.jl
# sampling lists for the whole network

#=
types for list storage
two cases:
1. a single degree bin
2. a unit range over multiple degree distances\
=#

const VerticesList1 = Dict{String, Vector{Tuple{String, String}}};
const VerticesList2 = Dict{String, Tuple{Vector{Tuple{String, String}}, Vector{Union{Int, UnitRange{Int}}}, Vector{Bool}}};

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
            desired = ((5, 5), (5, 5), (5, 5), (5, 5)),
            dvals = (1, 2, 3, 4),
            moreinfo = false,
            shuffle = true,
            carryover = true,
            outer = nothing
        )

Generate, for each person in an unweighted, undirected sociocentric network,
a list of relationships to show them, using the social orbit procedure. For
each degree bin in `dvals`, sample real and counterfactual pairs in the
numbers given by `desired`.

`dvals` contains integers or integer ranges (a range combines several degrees
into one bin). `desired` has one tuple `(# real, # counterfactual)` for each
element of `dvals`, in the same order.

By default a bin smaller than desired is made up from other bins (see
`samplebins`), so lists keep their full length where possible. With
`carryover = false` each bin supplies at most its own desired number, as in the
procedure described in Feltham et al. (2025), and a short bin gives a shorter
list.

With `outer = (r, f)`, an extra outer bin holds every remaining pair (a
member farther than the last degree bin, or unreachable) and supplies `r`
real and `f` counterfactual pairs, so that no eligible pair has inclusion
probability zero. It is the last bin in the carry-over order, and its degree
label is `0`. The default, `nothing`, is the deployed design.

This is the stratified stage only. `samplevillage` adds the fill to the target
length and the lists for isolates, as deployed.

Optionally specify a random number generator (rng).
"""
function samplenetwork(
    rng::AbstractRNG,
    graph;
    desired = deployed_design.desired,
    dvals = deployed_design.dvals,
    moreinfo = false,
    shuffle = true,
    carryover = true,
    outer = nothing
)

    _checkspec(desired, dvals, outer)
    dₘₐₓ = maximum(maximum, dvals)

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
        seeds, verticeslists, graph, dₘₐₓ, desired, dvals, moreinfo, shuffle, carryover,
        outer
    )

    return verticeslists
end

# consent versions

"""
        samplenetwork(
            [rng],
            graph,
            consents;
            desired = ((5, 5), (5, 5), (5, 5), (5, 5)),
            dvals = (1, 2, 3, 4),
            moreinfo = false,
            shuffle = true,
            carryover = true,
            outer = nothing
        )

Generate, for each person in an unweighted, undirected sociocentric network,
a list of relationships to show them, using the social orbit procedure. For
each degree bin in `dvals`, sample real and counterfactual pairs in the
numbers given by `desired`.

`dvals` contains integers or integer ranges (a range combines several degrees
into one bin). `desired` has one tuple `(# real, # counterfactual)` for each
element of `dvals`, in the same order.

By default a bin smaller than desired is made up from other bins (see
`samplebins`), so lists keep their full length where possible. With
`carryover = false` each bin supplies at most its own desired number, as in the
procedure described in Feltham et al. (2025), and a short bin gives a shorter
list. `outer` adds an outer bin of all remaining pairs (see above).

Optionally specify a random number generator (rng).

Consent codes in `consents` (a `Dict` from node name to code): 0 = none,
1 = survey only, 2 = survey and photo, 3 = photo only. Only perceivers with
code 1 or 2 receive a list (others are absent from the result); a pair is
included only if both nodes have code ≥ 2, so a perceiver may get a short or
empty list. Every node must have an entry (`ArgumentError` otherwise).
"""
function samplenetwork(
    rng::AbstractRNG,
    graph,
    consents;
    desired = deployed_design.desired,
    dvals = deployed_design.dvals,
    moreinfo = false,
    shuffle = true,
    carryover = true,
    outer = nothing
)

    _checkspec(desired, dvals, outer)
    dₘₐₓ = maximum(maximum, dvals)

    _checkconsents(graph, consents)

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
        dₘₐₓ, desired, dvals, moreinfo, shuffle, carryover, outer
    )

    return verticeslists
end

function samplenetwork(
    graph;
    desired = deployed_design.desired,
    dvals = deployed_design.dvals,
    moreinfo = false,
    shuffle = true,
    carryover = true,
    outer = nothing
)
    return samplenetwork(
        Random.default_rng(), graph;
        desired = desired, dvals = dvals, moreinfo = moreinfo, shuffle = shuffle,
        carryover = carryover, outer = outer
    )
end

function samplenetwork(
    graph,
    consents::AbstractDict;
    desired = deployed_design.desired,
    dvals = deployed_design.dvals,
    moreinfo = false,
    shuffle = true,
    carryover = true,
    outer = nothing
)
    return samplenetwork(
        Random.default_rng(), graph, consents;
        desired = desired, dvals = dvals, moreinfo = moreinfo, shuffle = shuffle,
        carryover = carryover, outer = outer
    )
end
