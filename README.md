# SamplingPerceivedNetworks.jl

[![Docs: stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://human-nature-lab.github.io/SamplingPerceivedNetworks.jl/stable/)
[![Docs: dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://human-nature-lab.github.io/SamplingPerceivedNetworks.jl/dev/)
[![CI](https://github.com/human-nature-lab/SamplingPerceivedNetworks.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/human-nature-lab/SamplingPerceivedNetworks.jl/actions/workflows/CI.yml)
[![Documentation](https://github.com/human-nature-lab/SamplingPerceivedNetworks.jl/actions/workflows/Docs.yml/badge.svg?branch=main)](https://github.com/human-nature-lab/SamplingPerceivedNetworks.jl/actions/workflows/Docs.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](LICENSE)
[![Julia 1.10+](https://img.shields.io/badge/julia-1.10%2B-9558B2.svg)](https://julialang.org)
[![R interface: psnr](https://img.shields.io/badge/R%20interface-psnr-276DC3.svg)](https://github.com/emfeltham/psnr)

A Julia package for the distance-based sampling procedure used to collect cognitive social structures (CSS) data. It generates stratified lists of real and counterfactual relationships within a perceiver's social orbit: the network neighborhood out to a specified distance from the perceiver.

![](figure.png)
_Figure. Individuals judge the existence of relationships in their communities between pairs of individuals and then merged these data with sociocentric network data from 82 villages to assess their accuracy. a, The social network measured for a representative village for a survey respondent (blue dot), representing the social connections among other villages (black dots). Ties that exist between community members (solid lines) and the numerous ties that do not exist (dotted lines), with the shortest path between people and the survey respondent (the 'cognizer') indicated (shaded circles; 1–4 steps). b, Survey respondents judged the existence of social ties that did or did not exist for up to 40 pairs of individuals. Respondents answered correctly (blue) or not (red) (pairs not presented are in grey). Adapted from the Research Briefing for Feltham, Forastiere, & Christakis (2025)._

## Overview

The package generates survey questions about network perception in three stages:

1. Orbit generation: build a perceiver's social orbit out to distance d_max, including real and counterfactual edges.
2. Bin creation: group the possible relationships into sampling bins by distance and reality.
3. Stratified sampling: draw relationships from the bins according to a sampling specification.

This makes it feasible to collect data on network beliefs in large networks, as in the study of 10,072 adults in 82 villages in rural Honduras. The procedure was developed and applied in:

Feltham, E., Forastiere, L., & Christakis, N.A. (2025). "Cognitive representations of social networks in isolated villages." *Nature Human Behaviour*. [https://doi.org/10.1038/s41562-025-02221-6](https://doi.org/10.1038/s41562-025-02221-6)

## Installation

This package is not registered, install from GitHub (requires Julia 1.10 or later):

```julia
using Pkg
Pkg.add(url="https://github.com/human-nature-lab/SamplingPerceivedNetworks.jl")
```

## Quick Start

```julia
using SamplingPerceivedNetworks
using Graphs, MetaGraphs, Random

# Create or load a network (a MetaGraph with a :name property on each vertex)
graph = # your MetaGraph

# Stratified lists for every perceiver, with the deployed design
# (5 real + 5 counterfactual pairs at each of distances 1 to 4)
lists = samplenetwork(MersenneTwister(1), graph; deployed_design...)

# The full deployed procedure: consents, fill to 40, isolates
# (consents: Dict from name to code 0-3; isolates: names of people with no ties)
lists = samplevillage(MersenneTwister(1), graph, consents; isolates = isolates)

# Exact inclusion probabilities of those lists (weights are 1 / pi)
pis = inclusionprobs(graph, consents; randomfill = true, isolates = isolates)

# Convert to an edgelist DataFrame for export
using DataFrames, CSV
CSV.write("sampling_lists.csv", psn_edgelists(lists))
```

Documentation: <https://human-nature-lab.github.io/SamplingPerceivedNetworks.jl> (build locally with `julia --project=docs docs/make.jl`).

See `example.jl` for a complete working example using a Watts-Strogatz small-world network.

## Key Functions

### Orbit Generation
- `vertexorbit(graph, vertex, dₘₐₓ)` - Generate social orbit extending to distance dₘₐₓ
- `vertexorbit_d(rad, d)` - Extract only ties at specific distance d

### Bin Creation
- `samplingbins(orbit, dₘₐₓ)` - Create sampling bins indexed by (distance, reality) tuples

### Stratified Sampling
- `samplebins([rng,] bins; desired, dvals, moreinfo, carryover)` - Sample relationships for one perceiver
- `samplenetwork([rng,] graph[, consents]; desired, dvals, moreinfo, shuffle, carryover)` - Generate lists for entire network. With `consents` (a `Dict` from name to a code of 0 to 3, required for every node), only perceivers who consented to the survey (1 or 2) get a list, and a pair is shown only if both members consented to photos (2 or 3)

`carryover = true` (the default) makes up a short bin's shortfall from other bins so that lists keep their full length; `carryover = false` draws at most each bin's own desired number, as described in the paper.

`outer = (r, f)` (off by default) adds an outer bin of all remaining eligible pairs (beyond the last distance bin, or unreachable), so that no eligible pair has inclusion probability zero.

### The Deployed Procedure
- `samplevillage([rng,] graph[, consents]; isolates, excludeperceiver, ...)` - The per-village procedure of the Honduras deployment (ported from its server code, HonCog.jl): the stratified stage, then lists shorter than the target (40) are filled with `ceil(gap/2)` real and `floor(gap/2)` counterfactual pairs drawn uniformly from the whole village, and each isolate (a respondent who named no one, not in `graph`) gets 20 + 20 uniform pairs. By default fill pairs may include the perceiver, as in the deployed code; `excludeperceiver = true` removes them. See the documentation for the deployed details it reproduces

### Design Presets and Inclusion Probabilities
- `deployed_design`, `merged_design` - `desired` and `dvals` presets, splatted in with `samplenetwork(graph; deployed_design...)`. `deployed_design` (4 separate degree bins of 5 real + 5 counterfactual) is the Honduras CSS design and the default; `merged_design` (degrees 1-2 combined at 10 + 10, then 5 + 5 at degrees 3 and 4) was never deployed
- `inclusionprobs(graph[, v][, consents]; desired, dvals, carryover, outer, randomfill, excludeperceiver, isolates)` - Exact probability `pi` that each pair is on a perceiver's list (`1/pi` is the estimation weight), computed from the graph with no random sampling, including the gap carry-over, consent filtering, the outer bin and, with `randomfill = true`, the fill and isolates of `samplevillage`. Returns a DataFrame (`perceiver`, `from`, `to`, `bin`, `real`, `pi`; no `perceiver` column when `v` is given). It gives the probability that a pair is on the list, not that it was answered (respondents who do not recognize someone in a pair are not asked about it)

### Utilities
- `psn_edgelists(vertlists)` - Convert sampling output to DataFrame edgelist (columns `perceiver`, `from`, `to`, and with `moreinfo = true`, `bin` and `real`; `bin` is `"outer"` or `"fill"` for pairs from the outer bin or the fill)
- `edgelist(graph)` - Extract sociocentric edgelist from graph
- `tupleize(alters1, alters2; sort = false)` - Create tuples from edgelist columns, alphanumerically sorted within each pair if `sort` is true

## Use from R

An R interface, [psnr](https://github.com/emfeltham/psnr), wraps `samplenetwork` and `inclusionprobs` through JuliaCall.

## Tests

```julia
using Pkg; Pkg.activate("."); Pkg.test()
```

The tests check that `inclusionprobs` agrees with empirical inclusion frequencies over many draws (with carry-over active, with consents, and for `samplevillage` with the fill, isolates and the outer bin). They also check the orbit and sampling bins against a brute-force computation from shortest-path distances on random graphs, the stratified draw (including how a short bin passes its shortfall to later bins), consent filtering, and the edgelist outputs.

## Dependencies

Built on [JuliaGraphs](https://juliagraphs.org):
- Graphs.jl: Core graph data structures and algorithms
- MetaGraphs.jl: Graphs with metadata on vertices/edges
- Random.jl: Random number generation for sampling
- StatsBase.jl: Statistical sampling functions
- DataFrames.jl: Edgelist output

## Features

- Distance-based stratified sampling of network ties
- Separate sampling of real and counterfactual relationships
- Consent filtering for photo permissions
- The deployed fill-to-40 and isolate lists, and an optional outer bin
- Exact inclusion probabilities for design-based weighting
- Reproducible sampling through per-perceiver RNG seeds
- Edgelist export
- Bins of single distances or ranges of distances

## Citation

To cite the software, use the metadata in `CITATION.cff` (GitHub's "Cite this repository"); archived releases have a Zenodo DOI. For the method, please cite:

```bibtex
@article{feltham_cognitive_2025,
  title = {Cognitive Representations of Social Networks in Isolated Villages},
  author = {Feltham, Eric and Forastiere, Laura and Christakis, Nicholas A.},
  year = {2025},
  month = jun,
  journal = {Nature Human Behaviour},
  issn = {2397-3374},
  doi = {10.1038/s41562-025-02221-6},
  keywords = {Biological anthropology,Human behaviour,Social anthropology,Social behaviour,Sociology}
}
```
