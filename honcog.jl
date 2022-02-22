# recreate the R package functions 

using Graphs, MetaGraphs
using CairoMakie, GraphMakie, NetworkLayout, Colors, ColorSchemes

# load package functions
include("radius.jl")
include("sampling.jl")
include("plotting.jl")
include("context.jl")
include("whole_network.jl")

# setup the test network
graph = watts_strogatz(100, 4, 0.3)
graph = MetaGraph(graph)

# add names for test network
for i in 1:nv(graph)
    set_prop!(graph, i, :name, "John" * "_" * string(i))
end

# end setup

v = 1; dₘₐₓ = 4;

get_prop(graph, v, :name)

rad = vertexradius(graph, v, dₘₐₓ);

d = 1
radiusd = vertexradius_d(rad, d);

[get_prop(radiusd, vtx, :name) for vtx in vertices(radiusd)]

plot_radius_d(radiusd)

gcon = context_graph(graph, radiusd, v; index = true);

f_cont = plot_context(gcon);

CairoMakie.save("context.svg", f_cont, px_per_unit = 2)

#=
tasks:
1. context graph []
2. sampling from radius [DONE]
    sample from each real, fake for each d
    with option to keep degree and real-fake status
=#

bins = samplingbins(rad)

cogls, degls, real_ls = samplebins(
    bins;
    desired = ((10, 10), (5, 5), (5, 5)), dvals = (1:2, 3, 4),
    moreinfo = true
);

vertlists = samplenetwork(
    graph;
    desired = ((10, 10), (5, 5), (5, 5)), dvals = (1:2, 3, 4),
    moreinfo = true
);
