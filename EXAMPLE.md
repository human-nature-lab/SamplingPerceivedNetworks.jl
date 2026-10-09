# Example Plan for example.jl

This document plans the structure and content for the example.jl demonstration file.

## Goals

The example should:
1. Be **runnable** - only use functions that exist in the package
2. Be **pedagogical** - clearly demonstrate the three-stage workflow
3. Be **minimal** - avoid unnecessary complexity or external dependencies
4. Be **reproducible** - use fixed random seeds
5. Show both **single-perceiver** and **network-wide** workflows
6. Demonstrate **data export** for practical use

## Current Issues in example.jl

- **Lines 66, 70, 72, 75**: Call non-existent functions - remove
- **Line 11**: Imports `CairoMakie` - remove
- **Line 31**: Downloads data from internet (fragile dependency)
- **Lines 101-102, 114-116**: Commented-out code creates clutter
- **Line 106**: Incomplete comment

## Proposed Structure

### 1. Setup Section
```julia
# Package activation
import Pkg; Pkg.activate(".")

# Load dependencies
using Graphs, MetaGraphs, SamplingPerceivedNetworks, Random, DataFrames, CSV
import StatsBase.sample

# Set seed for reproducibility
Random.seed!(2022)
```

### 2. Network Creation
```julia
# Create Watts-Strogatz small-world network
graph = watts_strogatz(100, 4, 0.3)
graph = MetaGraph(graph)

# Add names (simple approach without internet dependency)
# Option A: Generic names "Person_1", "Person_2", etc.
# Option B: Small built-in list of names
for i in 1:nv(graph)
    set_prop!(graph, i, :name, "Person_$i")
end

# Set up name indexing (required for the package)
set_indexing_prop!(graph, :name)
```

**Decision needed**: Use simple "Person_N" names or include a small hardcoded name list?

### 3. Single Perceiver Example
```julia
# Pick a person and maximum distance
v = 1
dₘₐₓ = 4

# Stage 1: Generate social orbit
rad = vertexorbit(graph, v, dₘₐₓ)

# Demonstrate extracting specific distance
d = 2
orbitd = vertexorbit_d(rad, d)

# Stage 2: Create sampling bins
bins = samplingbins(rad, dₘₐₓ)

# Stage 3: Sample relationships
cogls, degls, real_ls = samplebins(
    bins;
    desired = ((10, 10), (5, 5), (5, 5)),
    dvals = (1:2, 3, 4),
    moreinfo = true
)
```

### 4. Network-Wide Sampling
```julia
# Generate sampling lists for all vertices
vertlists = samplenetwork(
    graph;
    desired = ((10, 10), (5, 5), (5, 5)),
    dvals = (1:2, 3, 4),
    dₘₐₓ = dₘₐₓ,
    moreinfo = true,
    shuffle = true
)
```

### 5. Export Data
```julia
# Convert to edgelist format
pel = psn_edgelists(vertlists)
el = edgelist(graph)

# Save to CSV
# pel.csv: Sampling lists for all perceivers
# el.csv: True sociocentric network
CSV.write("pel.csv", pel)
CSV.write("el.csv", el)
```

## Optional Sections

### Advanced Features
Could add optional demonstrations of:
- Consent filtering (if data available)
- Custom RNG seeds per perceiver
- Different sampling specifications
- Saving/loading with JLD2 (if useful)

## Dependencies

### Required
- Graphs.jl
- MetaGraphs.jl
- Random.jl
- StatsBase.jl
- DataFrames.jl (for export)
- CSV.jl (for export)

### Optional
- JLD2.jl (only if save/load example useful)

## Output

The example produces:
1. **Two CSV files**:
   - `pel.csv` - sampling lists for all perceivers
   - `el.csv` - true sociocentric network

## Next Steps

1. Decide on naming strategy (simple "Person_N" vs. hardcoded list)
2. Decide whether to keep/remove JLD2 save/load example
3. Implement revised example.jl based on this plan
4. Update CLAUDE.md to reflect example capabilities
