# base example.jl
# basic example for perceived network sampling from an underlying
# sociocentric network
# author: eric martin feltham
# contact: eric.feltham@yale.edu
# date: 2022-02-21

# you may not need need to run this line
import Pkg; Pkg.activate(pwd())

using Graphs, MetaGraphs, SamplingPerceivedNetworks, CairoMakie, Random
import StatsBase.sample

# so that the lists are generated in a reproducible way
Random.seed!(2022)

#=
setup the test network

Create a "small-world" network, as a simple starting point
for a test run-through. These network broadly similar to human
social networks.
=#

graph = watts_strogatz(100, 4, 0.3)
    
graph = MetaGraph(graph)

# add names for test network
using Downloads, DataFrames; import CSV
http_response = Downloads.download("https://raw.githubusercontent.com/hadley/data-baby-names/master/baby-names.csv");
namedat = CSV.File(http_response) |> DataFrame;
babynames = sample(unique(namedat.name), nv(graph); replace = false);

# e.g., "John_1", "John_2", ..., "John_N" are all people in this network
for (i, nme) in zip(1:nv(graph), babynames)
    set_prop!(graph, i, :name, nme)
end

## end setup test network

#=
parameters

For pedagogical purposes, pick some "person" on the network and
a maximum degree away from that individual to look for alters
who could possibly be in ties that we want to sample.
=#
v = 1; dₘₐₓ = 4;

# check the vertex name (since we picked the person's index):
get_prop(graph, v, :name)

rad = vertexorbit(graph, v, dₘₐₓ); # generate the social orbit of v

# pick degree to view (from 1 to dmax)
d = 2

# create the graph of relationships at d
orbitd = vertexorbit_d(rad, d);

# check the included nodes at d
[get_prop(orbitd, vtx, :name) for vtx in vertices(orbitd)]

# visualize the set of relationships at d degrees away from person v
plot_orbit_d(orbitd)

# plot the social orbit of v on the whole network
# this shows orbitd in the context of the larger social network
gcon = context_graph(graph, orbitd, v; index = true);

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

# idx = sortperm(cogls)
# hcat(cogls, degls, real_ls)[idx, :]

# generate a sampling list for each vertex in the network
# now, instead of focusing on person v, look at the whole network
# and 
vertlists = samplenetwork(
    graph;
    desired = ((10, 10), (5, 5), (5, 5)), dvals = (1:2, 3, 4),
    moreinfo = true,
    shuffle = true,
);

# import JLD2; JLD2.save_object("test.jld2", vertlists);

# import JLD2; old = JLD2.load_object("test.jld2");

# edgelists: sampling lists for egos; sociocentric graph
pel = psn_edgelists(vertlists)
el = edgelist(graph)

for (e, z) in zip([el, pel], ["el", "pel"])
    CSV.write(z * ".csv",  e)
end