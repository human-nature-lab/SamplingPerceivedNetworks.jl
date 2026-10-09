# inclusion.jl
# design presets and exact inclusion probabilities

"""
        deployed_design

Preset for the `desired` and `dvals` keywords (splat it in, e.g.,
`samplenetwork(graph; deployed_design...)`): the design fielded in the
Honduras CSS. Four separate degree bins, 5 real and 5 counterfactual in each.
This is the default of `samplenetwork`, `samplebins` and `inclusionprobs`.
"""
const deployed_design = (
    desired = ((5, 5), (5, 5), (5, 5), (5, 5)),
    dvals = (1, 2, 3, 4)
)

"""
        merged_design

Preset for the `desired` and `dvals` keywords: an alternative that combines
degrees 1 and 2 into one bin with 10 + 10 (and 5 + 5 at degrees 3 and 4).
It was never deployed.
"""
const merged_design = (
    desired = ((10, 10), (5, 5), (5, 5)),
    dvals = (1:2, 3, 4)
)

# every node needs a consent status, and it cannot be `missing`
function _checkconsents(graph, consents)
    missingnames = [
        nm for nm in (get_prop(graph, v, :name) for v in vertices(graph))
        if !haskey(consents, nm)
    ]
    isempty(missingnames) || throw(ArgumentError(
        "consents has no entry for $(length(missingnames)) node(s), " *
        "e.g., $(first(missingnames))"
    ))

    missingvals = [nm for nm in keys(consents) if ismissing(consents[nm])]
    isempty(missingvals) || throw(ArgumentError(
        "consents has missing values for $(length(missingvals)) node(s), " *
        "e.g., $(first(missingvals))"
    ))
    return nothing
end

"""
        inclusionprobs(graph, v[, consents]; desired, dvals)
        inclusionprobs(graph[, consents]; desired, dvals)

Exact first-order inclusion probabilities of the stratified draw in
`samplenetwork`, computed from the graph without any random sampling.

The first form is for the perceiver at vertex `v`. The second stacks all
perceivers (when `consents` is given, only those who would receive a list:
code 1 or 2) and adds a `perceiver` column. Both return a `DataFrame` with
one row for every pair that could be shown, with columns `from` and `to`
(each pair sorted alphanumerically), `bin` (the degree bin, e.g., "1:2"),
`real` (whether the pair is a real tie) and `pi` (the probability that the
pair is on the perceiver's list). Pairs outside the orbit, or in a bin
beyond `dvals`, are not listed; their probability is zero. For a perceiver
who has no list, the second form has no rows.

Within a bin the draw is a simple random sample without replacement, so
`pi = n / N`: `N` is the size of the bin and `n` the number drawn, after the
gap carry-over (see `samplebins`). The weight for estimation is `1 / pi`.

Covers the stratified stage only. A top-up of short lists to the full length
(as in the survey software), or the addition of isolates, is not modeled.
`consents` follows `samplenetwork`: a pair is eligible only if both nodes have
code ≥ 2.
"""
function inclusionprobs(
    graph, v::Integer, consents = nothing;
    desired = deployed_design.desired, dvals = deployed_design.dvals
)
    _checkspec(desired, dvals)
    dₘₐₓ = maximum(maximum, dvals)
    consents === nothing || _checkconsents(graph, consents)

    bins = _vertexbins(graph, v, dₘₐₓ, consents)
    realsets = [mk_binset(bins, d, true) for d in dvals]
    fakesets = [mk_binset(bins, d, false) for d in dvals]
    nr, nf = _quotas(length.(realsets), length.(fakesets), desired)

    from = String[]; to = String[]; bin = String[]
    real = Bool[]; pr = Float64[]
    for (sets, ns, rl) in ((realsets, nr, true), (fakesets, nf, false))
        for (set, n, d) in zip(sets, ns, dvals)
            for (a, b) in set
                push!(from, min(a, b)); push!(to, max(a, b))
                push!(bin, string(d)); push!(real, rl)
                push!(pr, n / length(set))
            end
        end
    end
    return DataFrame(from = from, to = to, bin = bin, real = real, pi = pr)
end

function inclusionprobs(
    graph, consents = nothing;
    desired = deployed_design.desired, dvals = deployed_design.dvals
)
    _checkspec(desired, dvals)
    consents === nothing || _checkconsents(graph, consents)

    out = DataFrame(
        perceiver = String[], from = String[], to = String[],
        bin = String[], real = Bool[], pi = Float64[]
    )
    for v in vertices(graph)
        nm = get_prop(graph, v, :name)
        if consents !== nothing && !(consents[nm] in (1, 2))
            continue  # no list for this perceiver
        end
        df = inclusionprobs(
            graph, v, consents; desired = desired, dvals = dvals
        )
        insertcols!(df, 1, :perceiver => fill(string(nm), nrow(df)))
        append!(out, df)
    end
    return out
end
