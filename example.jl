# example.jl
# basic example for perceived network sampling from an underlying
# sociocentric network
# author: eric martin feltham
# contact: eric.feltham@yale.edu
# date: 2022-02-21

using Graphs, MetaGraphs, SamplingPerceivedNetworks

## setup the test network
graph = watts_strogatz(100, 4, 0.3)
graph = MetaGraph(graph)

# add names for test network
for i in 1:nv(graph)
    set_prop!(graph, i, :name, "John" * "_" * string(i))
end

## end setup test network

# choose a vertex, and a maximum degree
v = 1; dₘₐₓ = 4;

get_prop(graph, v, :name) # check the vertex name

rad = vertexradius(graph, v, dₘₐₓ); # generate the social radius of v

# pick degree to view (from 1 to dmax)
d = 1
radiusd = vertexradius_d(rad, d);

# check the included nodes at d
[get_prop(radiusd, vtx, :name) for vtx in vertices(radiusd)]

plot_radius_d(radiusd)

# plot the social radius of v on the whole network
gcon = context_graph(graph, radiusd, v; index = true);

f_cont = plot_context(gcon);

CairoMakie.save("context.svg", f_cont, px_per_unit = 2)

# sampling

bins = samplingbins(rad, dₘₐₓ)

# more info: dels, real_ls
cogls, degls, real_ls = samplebins(
    bins;
    desired = ((10, 10), (5, 5), (5, 5)), dvals = (1:2, 3, 4),
    moreinfo = true
);

# generate a sampling list for each vertex in the network

vertlists = samplenetwork(
    graph, dₘₐₓ;
    desired = ((10, 10), (5, 5), (5, 5)), dvals = (1:2, 3, 4),
    moreinfo = true
);
