# Inclusion probabilities

Design-based analysis of the responses requires the probability ``\pi`` that
each pair appeared on a perceiver's list; the estimation weight is ``1/\pi``.
[`inclusionprobs`](@ref) computes it exactly from the graph, without random
sampling. It takes the sampler's keywords, which should match the ones used
to draw the lists:

```julia
# lists from samplenetwork (the stratified stage)
pi_all = inclusionprobs(graph, consents; deployed_design...)      # every perceiver
pi_one = inclusionprobs(graph, 1, consents; deployed_design...)   # vertex 1 only

# lists from samplevillage (the deployed procedure, with fill and isolates)
pi_vil = inclusionprobs(graph, consents; randomfill = true, isolates = isolates)
```

The result is a `DataFrame` with columns `perceiver` (omitted for a single
perceiver), `from`, `to`, `bin`, `real`, and `pi`. `bin` is the stratum of
the pair (a degree bin, `"outer"`, or `"none"` for a pair that can enter only
through the fill or an isolate's list). Pairs not listed have ``\pi = 0``.

## Derivation

**Stratified stage.** Within a cell (bin × reality) the draw is a simple
random sample without replacement of ``n`` from ``N`` pairs, so
``\pi_1 = n/N``. The number ``n`` comes from the carry-over rule, which
depends only on the cell sizes, so it is fixed given the graph and consents.
The outer bin is one more cell.

**Fill.** The stratified list therefore has a fixed length ``L = \sum n``, so
the gap ``g = \text{target} - L`` and its split
``(g_r, g_f) = (\lceil g/2 \rceil, \lfloor g/2 \rfloor)`` are fixed too. Let
``P_r`` be the village pool of real pairs (minus the perceiver's own pairs
with `excludeperceiver = true`). Every real pair drawn in the stratified
stage belongs to ``P_r``, and ``\sum n_{\text{real}}`` of them are drawn, so
the pool left for the fill has size ``M_r = |P_r| - \sum n_{\text{real}}``
whichever pairs were drawn. The fill takes ``m_r = \min(g_r, M_r)`` of them
uniformly. A pair not already on the list is drawn with probability
``m_r / M_r``, so

```math
\pi = \pi_1 + (1 - \pi_1)\, \frac{m_r}{M_r},
```

with ``\pi_1 = 0`` for a pair in no stratum. Counterfactual pairs are handled
in the same way. The formula is exact, not an approximation.

**Isolates.** An isolate's list is a uniform draw of ``\lceil t/2 \rceil``
real and ``\lfloor t/2 \rfloor`` counterfactual pairs from the whole pools
(``t`` is the target length), so
``\pi = \min(\lceil t/2 \rceil, |P_r|) / |P_r|`` for real pairs, and likewise
for counterfactual pairs.

The test suite compares these values with inclusion frequencies over 20,000
runs of [`samplevillage`](@ref), with the fill active, with isolates, and
with the outer bin.

`pi` is the probability that a pair is on the list, not that it was
answered. Respondents who do not recognize someone in a pair are not asked
about it, and this is not modeled.
