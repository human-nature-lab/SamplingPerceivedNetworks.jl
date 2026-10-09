# samplevillage.jl
# the full deployed procedure for one village

"""
        samplevillage(
            [rng],
            graph[, consents];
            isolates = String[],
            desired = deployed_design.desired,
            dvals = deployed_design.dvals,
            outer = nothing,
            carryover = true,
            randomfill = true,
            excludeperceiver = false,
            moreinfo = false,
            shuffle = true
        )

Generate the CSS lists for one village with the procedure deployed in the
Honduras CSS (the `HonCog.jl` server code), in one call:

1. the stratified stage, `samplenetwork` (orbit bins, gap carry-over,
   consent filter, shuffle), with the same arguments;
2. fill to the target length (with `randomfill = true`): a list shorter than
   the target (`countdesired(desired)`, 40 for `deployed_design`, plus the
   outer-bin quota if any) gets `ceil(gap/2)` real and `floor(gap/2)`
   counterfactual pairs, drawn uniformly without replacement from the whole
   village: every real tie, or every non-adjacent pair, among the nodes of
   `graph` with consent code ≥ 2, minus the pairs already on the list. Each
   pool supplies at most what it has. The fill pairs are shuffled and
   appended after the stratified pairs (so they are shown last);
3. isolates: each name in `isolates` with consent code > 1 (2 or 3; any name
   if `consents` is not given) gets `ceil(target/2)` real and
   `floor(target/2)` counterfactual pairs drawn uniformly from the same village
   pools, with no exclusions. In HonCog an isolate is a respondent who named
   no one (a row with a missing alter), so they are not in `graph` and not in
   the pools. If an isolate is in `graph`, the new list replaces their
   stratified list.

Build `graph` from the edgelist alone, as HonCog did, so that people without
ties enter only through `isolates`; the fill pools are the pairs among the
vertices of `graph`. With `moreinfo = true`, fill and isolate pairs have the
degree label `-1` (`"fill"` in `psn_edgelists`). The stratified stage uses
one seed per perceiver drawn from `rng`; the fill and isolate draws then
continue on `rng`, visiting the lists in `Dict` order and then the isolates
in the given order. (HonCog drew them from the global generator, so the field
draws cannot be regenerated from the village seed.)

Deployed behavior reproduced, and the options that change it:
- `excludeperceiver = false` (default): the fill pool may contain pairs that
  involve the perceiver, as in HonCog of 2022-10-25 (commit `6213868`), the
  version that ran. HonCog's last commit (2022-12-12, `ecbab7f`) tried to
  remove them but passes its arguments in the wrong order and throws a
  `MethodError` whenever a list is short, so it cannot have produced lists.
  `excludeperceiver = true` gives the intended rule.
- consent: perceivers need code 1 or 2 (as in `samplenetwork`), isolates
  code > 1, so an isolate with code 3 (photo only) gets a list.
- isolates' lists have no perceiver exclusion and no distance structure.

`inclusionprobs(graph[, consents]; randomfill = true, isolates, ...)` returns
the exact inclusion probabilities of this procedure.
"""
function samplevillage(
    rng::AbstractRNG,
    graph,
    consents = nothing;
    isolates = String[],
    desired = deployed_design.desired,
    dvals = deployed_design.dvals,
    outer = nothing,
    carryover = true,
    randomfill = true,
    excludeperceiver = false,
    moreinfo = false,
    shuffle = true
)
    kw = (
        desired = desired, dvals = dvals, outer = outer, carryover = carryover,
        moreinfo = moreinfo, shuffle = shuffle
    )
    lists = consents === nothing ? samplenetwork(rng, graph; kw...) :
        samplenetwork(rng, graph, consents; kw...)

    isolates = _eligibleisolates(isolates, consents)
    target = _target(desired, outer)
    if randomfill || !isempty(isolates)
        reals, fakes = _fillpools(graph, consents)
        if randomfill
            _randomfill!(
                rng, lists, reals, fakes, target, moreinfo, shuffle, excludeperceiver
            )
        end
        _isolatefill!(rng, lists, isolates, reals, fakes, target, moreinfo, shuffle)
    end
    return lists
end

function samplevillage(graph, consents = nothing; kwargs...)
    return samplevillage(Random.default_rng(), graph, consents; kwargs...)
end
