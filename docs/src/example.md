# Worked example

Vertices need a `String` property `:name`.

```@example ex
using SamplingPerceivedNetworks, Graphs, MetaGraphs, Random

g = MetaGraph(watts_strogatz(100, 6, 0.2; rng = MersenneTwister(1)))
for i in vertices(g)
    set_prop!(g, i, :name, "p$i")
end
nothing # hide
```

## One perceiver

The orbit of vertex 1, out to ``d_{max} = 3``, and the number of candidate
pairs in each bin:

```@example ex
orbit = vertexorbit(g, 1, 3)
bins  = samplingbins(orbit, 3)
Dict(k => length(v) for (k, v) in bins)
```

With `moreinfo = true`, `samplebins` also returns the degree bin and reality of
each sampled pair:

```@example ex
lst, degrees, real = samplebins(
    MersenneTwister(2), bins;
    desired = ((3, 3), (3, 3), (3, 3)), dvals = (1, 2, 3), moreinfo = true,
)
first(collect(zip(lst, degrees, real)), 5)
```

## The whole network

```@example ex
lists = samplenetwork(
    MersenneTwister(3), g;
    desired = ((5, 5), (5, 5), (5, 5)), dvals = (1, 2, 3), moreinfo = true,
)
length(lists)
```

[`psn_edgelists`](@ref) flattens the lists into a table for export (for
example, with CSV.jl):

```@example ex
el = psn_edgelists(lists)
first(el, 5)
```

[`edgelist`](@ref) returns the true network in the same format, for merging
with survey responses:

```@example ex
first(edgelist(g), 3)
```

!!! note
    Looking up a vertex by name, as in `vertexorbit(g, "p1", 3; index = false)`,
    requires `set_indexing_prop!(g, :name)`. Integer vertex indices do not.
    The output converts node names to `String`.
