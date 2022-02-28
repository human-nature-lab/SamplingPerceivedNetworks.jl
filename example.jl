# example.jl
# basic example for perceived network sampling from an underlying
# sociocentric network
# author: eric martin feltham
# contact: eric.feltham@yale.edu
# date: 2022-02-21

# you don't need to run this line
# import Pkg; Pkg.activate(pwd())

using Graphs, MetaGraphs, SamplingPerceivedNetworks, CairoMakie
import StatsBase.sample

#=
setup the test network

Create a "small-world" network, as a simple starting point
for a test run-through. These network broadly similar to human
social networks.
=#

graph = watts_strogatz(100, 4, 0.3)
    
graph = MetaGraph(graph)

# add names for test network
# e.g., "John_1", "John_2", ..., "John_N" are all people in this network
for i in 1:nv(graph)
    set_prop!(graph, i, :name, "John" * "_" * string(i))
end

## end setup test network

#=
parameters

For pedagogical purposes, pick some "person" on the network and
a maximum degree away from that individual to look for alters
who could possibly be in ties that we want to sample.
=#
v = 1; dₘₐₓ = 4;

get_prop(graph, v, :name) # check the vertex name (since we picked the person's index)

rad = vertexradius(graph, v, dₘₐₓ); # generate the social radius of v

# pick degree to view (from 1 to dmax)
d = 1

# create the graph of relationships at d
radiusd = vertexradius_d(rad, d);

# check the included nodes at d
[get_prop(radiusd, vtx, :name) for vtx in vertices(radiusd)]

# visualize the set of relationships at d degrees away from person v
plot_radius_d(radiusd)

# plot the social radius of v on the whole network
# this shows radiusd in the context of the larger social network
gcon = context_graph(graph, radiusd, v; index = true);

f_cont = plot_context(gcon);

# save the plot as "context.svg" (this could have been ".png" or ".jpg" instead)
save("context.svg", f_cont, px_per_unit = 2)

#=
perform sampling

As an example, consider person v again. We want to create one list of 40
relationships to show to person v. There are two steps
(1) create lists of all of the possible relationships that we are interested
in showing v.
(2) randomly sample 40 to show to v.
=#

# For person v, create lists of all the possible relationships that exist
# at each d, each for real and fake
# 
bins = samplingbins(rad, dₘₐₓ)

# sample 40 relationships, stratified according to the procedure,
# for person v. Also show information about each relationships, including its
# sampling bin and whether it is real or counterfactual
cogls, degls, real_ls = samplebins(
    bins;
    desired = ((10, 10), (5, 5), (5, 5)), dvals = (1:2, 3, 4),
    moreinfo = true
);

# generate a sampling list for each vertex in the network
# now, instead of focusing on person v, look at the whole network
# and 
vertlists = samplenetwork(
    graph;
    desired = ((10, 10), (5, 5), (5, 5)), dvals = (1:2, 3, 4),
    moreinfo = true
);
