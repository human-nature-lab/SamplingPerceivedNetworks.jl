# The sampling procedure

## Social orbit

The procedure takes a sociocentric network as input, and a pair is real if it
is tied in that network. In the Honduras study this was the union of three
relationship networks (free time, personal or private matters, and kin): two
people are tied if either reports the relationship.

The orbit of a perceiver ``v`` contains everyone within ``d_{max}`` steps of
``v``, excluding ``v``. Every pair of orbit members is a candidate
relationship. A pair is real if its members are tied in the network and
counterfactual otherwise. Its distance is ``d = \max(\mathrm{dist}(v,a),
\mathrm{dist}(v,b))``, the smallest ``d`` at which both members belong to the
orbit.

[`vertexorbit`](@ref) returns the orbit as a `MetaGraph` whose edges carry the
properties `:d` and `:real`. [`vertexorbit_d`](@ref) keeps only the ties that
first appear at a given distance.

## Bins

[`samplingbins`](@ref) returns a
`Dict{Tuple{Int,Bool},Vector{Tuple{String,String}}}` keyed by
`(distance, is_real)`. [`samplenetwork`](@ref) computes the same bins directly
from the graph, without constructing the orbit, which is much faster for large
orbits.

## Stratified sampling

Two keyword arguments define the design. `dvals` lists the degree bins in
increasing order; each element is an integer or a range such as `1:2`, which
merges several distances into one bin. `desired` gives, for each element of
`dvals`, a tuple `(# real, # counterfactual)`. The two must have the same
length. The default design, [`deployed_design`](@ref), draws five real and five
counterfactual pairs at each of distances 1 to 4, for up to 40 pairs per
perceiver, as in the Honduras study:

```julia
samplenetwork(graph; desired = ((5,5), (5,5), (5,5), (5,5)), dvals = (1, 2, 3, 4))
```

### Gap carry-over

Some bins cannot supply the requested number. A perceiver with two direct
connections has fewer than five real ties among their first-degree neighbors,
for example. Without compensation the list would then fall short of 40. Real bins are processed in
order of distance, and each tops up the shortfall left by earlier bins. A real
shortfall remaining after the last distance is added to the counterfactual
draws, which are processed in the same way. The list reaches the requested
total whenever enough candidate pairs exist. The paper notes that short bins can leave a
list under 40 but does not describe a carry-over rule; the rule is specific to
this package.

### Reproducibility

Given an `rng`, `samplenetwork` draws one seed per perceiver. A single seeded
stream drives both that perceiver's sampling and shuffling, so their list
depends only on the seed and the orbit. Without an `rng`, the global generator
is used.
