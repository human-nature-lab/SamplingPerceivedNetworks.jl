# Inclusion probabilities

Design-based analysis of the responses requires the probability ``\pi`` that
each pair appeared on a perceiver's list; the estimation weight is ``1/\pi``.
[`inclusionprobs`](@ref) computes it exactly from the graph, without random
sampling, including gap carry-over and consent filtering:

```julia
pi_all = inclusionprobs(graph; deployed_design...)       # every perceiver
pi_one = inclusionprobs(graph, 1; deployed_design...)    # vertex 1 only
```

The result is a `DataFrame` with columns `perceiver` (omitted for a single
perceiver), `from`, `to`, `bin`, `real`, and `pi`. Within a bin the draw is a
simple random sample without replacement, so `pi = n / N` for a bin of size
`N` from which `n` pairs are drawn after carry-over.

The calculation covers the stratified stage only. It does not model topping up
short lists or adding isolates.
