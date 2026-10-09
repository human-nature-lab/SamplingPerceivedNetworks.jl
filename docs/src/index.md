# SamplingPerceivedNetworks.jl

SamplingPerceivedNetworks.jl implements the distance-based sampling procedure
for collecting cognitive social structures (CSS): respondents' beliefs about
the relationships among other people in their community.

A perceiver cannot be asked about every pair in a large network. The package
instead draws, for each perceiver, a stratified list of real and counterfactual
(nonexistent) relationships from their social orbit, the network neighborhood
out to distance ``d_{max}``. Stratifying by distance allows accuracy to be
assessed across social distance.

The procedure was developed and applied in Feltham, Forastiere, and Christakis
(2025), "Cognitive representations of social networks in isolated villages,"
*Nature Human Behaviour* ([doi:10.1038/s41562-025-02221-6](https://doi.org/10.1038/s41562-025-02221-6)).

## Installation

The package is not registered. It requires Julia 1.10 or later.

```julia
using Pkg
Pkg.add(url = "https://github.com/human-nature-lab/SamplingPerceivedNetworks.jl")
```

## Pipeline

1. [`vertexorbit`](@ref) builds the perceiver's orbit, with real and counterfactual ties.
2. [`samplingbins`](@ref) groups the candidate pairs into bins by distance and reality.
3. [`samplebins`](@ref) draws a stratified list for one perceiver;
   [`samplenetwork`](@ref) does so for every perceiver in the network.

[`samplenetwork`](@ref) runs all three steps. Call the others to inspect or
customize a step. [`samplevillage`](@ref) adds the fill to the target length
and the lists for isolates, reproducing the deployed procedure, and
[`inclusionprobs`](@ref) returns each pair's exact inclusion probability.
