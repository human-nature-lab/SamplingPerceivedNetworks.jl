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
for example. The paper's procedure draws what each bin has, so such a
perceiver receives fewer than 40 pairs. Set `carryover = false` to reproduce
this.

By default (`carryover = true`) the package makes up the shortfall. Real bins
are processed in order of distance, and each tops up what earlier bins could
not supply. A real shortfall remaining after the last distance is added to the
counterfactual draws, which are processed in the same way. The list then
reaches the requested total whenever enough candidate pairs exist. The paper
does not describe this rule; it is specific to this package.

```julia
samplenetwork(graph; deployed_design..., carryover = false)
```

### Reproducibility

Given an `rng`, `samplenetwork` draws one seed per perceiver. A single seeded
stream drives both that perceiver's sampling and shuffling, so their list
depends only on the seed and the orbit. Without an `rng`, the global generator
is used.

## Outer bin

The orbit stops at ``d_{max}``, so a pair with a member farther away, or
unreachable, has inclusion probability zero in the deployed design. With
`outer = (r, f)`, an extra bin holds all of these remaining eligible pairs
and supplies `r` real and `f` counterfactual pairs. Every eligible pair then
has a positive inclusion probability. The outer bin is the last bin in the
carry-over order, so a real shortfall in the degree bins is made up from it
before the counterfactual bins. It is off by default (`outer = nothing`, as
deployed):

```julia
samplenetwork(graph; deployed_design..., outer = (4, 4))
```

With `moreinfo = true` its pairs have degree label `0` (`"outer"` in
[`psn_edgelists`](@ref)).

## The deployed procedure: fill and isolates

[`samplevillage`](@ref) runs the whole per-village procedure of the Honduras
deployment (the `HonCog.jl` server code) in one call:

```julia
lists = samplevillage(MersenneTwister(seed), graph, consents; isolates = isolates)
```

1. The stratified stage, as in [`samplenetwork`](@ref).
2. **Fill.** A list shorter than the target (40 for `deployed_design`) gets
   `ceil(gap/2)` real and `floor(gap/2)` counterfactual pairs, drawn uniformly
   without replacement from the whole village: every real tie, or every
   non-adjacent pair, among the vertices of `graph` whose members both have
   consent code ≥ 2, minus the pairs already on the list. The fill pairs carry
   no distance stratum. They are shuffled and appended after the stratified
   pairs, so they are shown last.
3. **Isolates.** Respondents who named no one are not in the edgelist, and
   so not in `graph`; pass their names as `isolates`. Each one with consent
   code 2 or 3 gets `ceil(target/2)` real and `floor(target/2)`
   counterfactual pairs drawn uniformly from the village pools.

Build `graph` from the edgelist alone, as the deployment did. With
`moreinfo = true` the fill and isolate pairs have degree label `-1`
(`"fill"` in [`psn_edgelists`](@ref)).

The port reproduces the deployment code, including two rules that look
unintended:

- Fill pairs may include the perceiver (`excludeperceiver = false`, the
  default). This is the HonCog version of 2022-10-25. A later commit
  (2022-12-12) meant to exclude such pairs but passes its arguments in the
  wrong order, so it fails on any short list and cannot have produced lists.
  `excludeperceiver = true` gives the intended rule.
- Perceivers need consent code 1 or 2, but isolates need 2 or 3, so an
  isolate with code 3 (photo only) gets a list.

The deployment drew the fill and isolate pairs from Julia's global random
generator, so they cannot be regenerated from the village seed.
`samplevillage` draws them from the `rng` it is given, after the stratified
stage.
