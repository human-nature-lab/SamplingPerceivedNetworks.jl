# example.jl
# Basic example for perceived network sampling from an underlying sociocentric network
# This demonstrates the three-stage workflow: orbit generation, bin creation, and stratified sampling
#
# Author: Eric Martin Feltham
# Contact: eric.feltham@aya.yale.edu
# Date: 2022-02-21

# Package activation (you may not need this line)
import Pkg; Pkg.activate(pwd())

# Load required packages
using Graphs, MetaGraphs, SamplingPerceivedNetworks, Random, DataFrames, CSV
import StatsBase.sample

# Set seed for reproducible results
Random.seed!(2022)

#=
1. SETUP THE TEST NETWORK

Create a Watts-Strogatz "small-world" network as a simple test case.
These networks are broadly similar to human social networks.
=#

# Create network with 100 nodes, 4 neighbors per node, 0.3 rewiring probability
graph = watts_strogatz(100, 4, 0.3)
graph = MetaGraph(graph)

# Add simple names to vertices
for i in 1:nv(graph)
    set_prop!(graph, i, :name, "Person_$i")
end

# Set up name indexing (required for the package)
set_indexing_prop!(graph, :name)

#=
2. SINGLE PERCEIVER EXAMPLE

Demonstrate the workflow for a single perceiver.
We'll pick one person and generate their sampling list.
=#

# Pick a focal person and maximum distance
v = 1
dₘₐₓ = 4
perceiver_name = get_prop(graph, v, :name)

# STAGE 1: Generate the social orbit extending to distance dₘₐₓ
rad = vertexorbit(graph, v, dₘₐₓ)

# Extract nodes at a specific distance (for demonstration)
d = 2
orbitd = vertexorbit_d(rad, d)

# STAGE 2: Create sampling bins organized by (distance, reality) tuples
bins = samplingbins(rad, dₘₐₓ)

# STAGE 3: Sample relationships from bins
# Sampling specification: (# real, # counterfactual) per bin
# Bin 1: distances 1-2 combined → 10 real + 10 counterfactual
# Bin 2: distance 3 → 5 real + 5 counterfactual
# Bin 3: distance 4 → 5 real + 5 counterfactual
cogls, degls, real_ls = samplebins(
    bins;
    desired = ((10, 10), (5, 5), (5, 5)),
    dvals = (1:2, 3, 4),
    moreinfo = true
)

#=
3. NETWORK-WIDE SAMPLING

Generate sampling lists for all perceivers in the network.
Each person gets their own stratified random sample.
=#

vertlists = samplenetwork(
    graph;
    desired = ((10, 10), (5, 5), (5, 5)),
    dvals = (1:2, 3, 4),
    dₘₐₓ = dₘₐₓ,
    moreinfo = true,
    shuffle = true  # Randomize order of relationships within each list
)

#=
4. EXPORT DATA TO CSV

Convert the sampling lists and true network to edgelist format
suitable for survey implementation and analysis.
=#

# Convert sampling lists to edgelist DataFrame
pel = psn_edgelists(vertlists)

# Extract true sociocentric network as edgelist
el = edgelist(graph)

# Write to CSV files
# pel.csv: Sampling lists for all perceivers
# el.csv: True sociocentric network
CSV.write("pel.csv", pel)
CSV.write("el.csv", el)
