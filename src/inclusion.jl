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
        inclusionprobs(graph, v[, consents]; desired, dvals, carryover, outer,
                       randomfill = false, excludeperceiver = false, isolates)
        inclusionprobs(graph[, consents]; desired, dvals, carryover, outer,
                       randomfill = false, excludeperceiver = false, isolates)

Exact first-order inclusion probabilities of the lists drawn by
`samplenetwork` (the default) or, with `randomfill = true`, by
`samplevillage`, computed from the graph without any random sampling. Pass
the same keywords as to the sampler.

The first form is for the perceiver at vertex `v`. The second stacks every
person who would receive a list (with `consents`: code 1 or 2, plus the
`isolates` that `samplevillage` serves) and adds a `perceiver` column. Both
return a `DataFrame` with one row for every pair that could be shown, with
columns `from` and `to` (each pair sorted alphanumerically), `bin` (the
stratum: the degree bin, e.g., "1:2", `"outer"`, or `"none"` for a pair that
enters only through the fill or an isolate's list), `real` (whether the pair
is a real tie) and `pi` (the probability that the pair is on the perceiver's
list). Pairs that are not listed have probability zero. The weight for
estimation is `1 / pi`.

**Stratified stage.** Within a cell (bin × reality) the draw is a simple
random sample without replacement, so `pi₁ = n / N`: `N` is the size of the
cell and `n` the number drawn after the gap carry-over (see `samplebins`;
`carryover = false` turns it off). `n` depends only on the cell sizes, so it
is fixed given the graph and consents. The outer bin (`outer = (r, f)`) is
one more cell.

**Fill** (`randomfill = true`). The stratified list has the fixed length
`L = Σ n`, so the gap `g = target - L` and its split
`(g_r, g_f) = (ceil(g/2), floor(g/2))` are fixed too. Let `P_r` be the
village pool of real pairs (consent-eligible ties among the nodes of `graph`;
without the perceiver's own pairs if `excludeperceiver`). Every real pair
drawn in the stratified stage is in `P_r`, and the number drawn is
`Σ n_real`, so the pool left for the fill always has size
`M_r = |P_r| - Σ n_real`, whichever pairs were drawn. The fill takes
`m_r = min(g_r, M_r)` of them uniformly, so a pair not already on the list is
drawn with probability `m_r / M_r`, and

    pi = pi₁ + (1 - pi₁) m_r / M_r,

with `pi₁ = 0` for a pair in no stratum; likewise for counterfactual pairs.
This is exact. **Isolates** (`isolates`): an isolate's list is
`ceil(target/2)` real and `floor(target/2)` counterfactual pairs drawn
uniformly from the whole pools `P_r` and `P_f` (no exclusions), so
`pi = min(⌈target/2⌉, |P_r|) / |P_r|` for real pairs, and likewise for
counterfactual pairs; it replaces any other list the person has.

`pi` is the probability that a pair is on the list, not that it was answered:
respondents who do not recognize someone in a pair are not asked about it,
and this is not modeled.
`consents` follows `samplenetwork`: a pair is eligible only if both nodes have
code ≥ 2.
"""
function inclusionprobs(
    graph, v::Integer, consents = nothing;
    desired = deployed_design.desired, dvals = deployed_design.dvals,
    carryover = true, outer = nothing, randomfill = false,
    excludeperceiver = false, isolates = String[]
)
    _checkspec(desired, dvals, outer)
    consents === nothing || _checkconsents(graph, consents)
    isolates = _eligibleisolates(isolates, consents)

    pools = randomfill || !isempty(isolates) ? _fillpools(graph, consents) : nothing
    target = _target(desired, outer)
    isolist = string(get_prop(graph, v, :name)) in string.(isolates) &&
        _isolatelist(pools, target)
    return _inclusionprobs(
        graph, v, consents, pools, isolist;
        desired = desired, dvals = dvals, carryover = carryover, outer = outer,
        randomfill = randomfill, excludeperceiver = excludeperceiver
    )
end

function inclusionprobs(
    graph, consents = nothing;
    desired = deployed_design.desired, dvals = deployed_design.dvals,
    carryover = true, outer = nothing, randomfill = false,
    excludeperceiver = false, isolates = String[]
)
    _checkspec(desired, dvals, outer)
    consents === nothing || _checkconsents(graph, consents)
    isolates = _eligibleisolates(isolates, consents)

    pools = randomfill || !isempty(isolates) ? _fillpools(graph, consents) : nothing
    target = _target(desired, outer)
    isoset = Set(string.(isolates))
    isolist = _isolatelist(pools, target)  # whether an isolate's list is nonempty

    out = DataFrame(
        perceiver = String[], from = String[], to = String[],
        bin = String[], real = Bool[], pi = Float64[]
    )
    graphnames = Set{String}()
    for v in vertices(graph)
        nm = get_prop(graph, v, :name)
        push!(graphnames, string(nm))
        iso = string(nm) in isoset && isolist
        if !iso && consents !== nothing && !(consents[nm] in (1, 2))
            continue  # no list for this person
        end
        df = _inclusionprobs(
            graph, v, consents, pools, iso;
            desired = desired, dvals = dvals, carryover = carryover, outer = outer,
            randomfill = randomfill, excludeperceiver = excludeperceiver
        )
        insertcols!(df, 1, :perceiver => fill(string(nm), nrow(df)))
        append!(out, df)
    end

    # isolates outside the graph
    if isolist
        for k in unique(string.(isolates))
            k in graphnames && continue
            df = _isolaterows(pools, target)
            insertcols!(df, 1, :perceiver => fill(k, nrow(df)))
            append!(out, df)
        end
    end
    return out
end

# an isolate's list is replaced only if the new one is nonempty
function _isolatelist(pools, target)
    pools === nothing && return false
    wantreal, wantfake = splitwanted(target)
    return min(wantreal, length(pools[1])) + min(wantfake, length(pools[2])) > 0
end

function _isolaterows(pools, target)
    from = String[]; to = String[]; real = Bool[]; pr = Float64[]
    for (pool, want, rl) in zip(pools, splitwanted(target), (true, false))
        isempty(pool) && continue
        p = min(want, length(pool)) / length(pool)
        p > 0 || continue
        for (a, b) in pool
            push!(from, a); push!(to, b); push!(real, rl); push!(pr, p)
        end
    end
    return DataFrame(from = from, to = to, bin = fill("none", length(from)), real = real, pi = pr)
end

function _inclusionprobs(
    graph, v, consents, pools, isolist;
    desired, dvals, carryover, outer, randomfill, excludeperceiver
)
    target = _target(desired, outer)
    isolist && return _isolaterows(pools, target)

    dₘₐₓ = maximum(maximum, dvals)
    bins = _vertexbins(graph, v, dₘₐₓ, consents; outer = outer !== nothing)
    realsets, fakesets, des, labels = _cells(bins, desired, dvals, outer)
    nr, nf = _quotas(length.(realsets), length.(fakesets), des; carryover = carryover)

    # fill: the probability that a pair not already on the list is drawn
    fillfrac = (0.0, 0.0)
    gap = target - sum(nr) - sum(nf)
    if randomfill && gap > 0
        nm = string(get_prop(graph, v, :name))
        poolr, poolf = excludeperceiver ?
            (_withoutperceiver(pools[1], nm), _withoutperceiver(pools[2], nm)) : pools
        fillfrac = map(
            (pool, ndrawn, want) -> begin
                left = length(pool) - ndrawn   # fixed: the drawn pairs are all in the pool
                left > 0 ? min(want, left) / left : 0.0
            end,
            (poolr, poolf), (sum(nr), sum(nf)), splitwanted(gap)
        )
    end

    from = String[]; to = String[]; bin = String[]
    real = Bool[]; pr = Float64[]
    instrata = Set{Tuple{String, String}}()
    for (sets, ns, rl, ff) in ((realsets, nr, true, fillfrac[1]), (fakesets, nf, false, fillfrac[2]))
        for (set, n, d) in zip(sets, ns, labels)
            for (a, b) in set
                p₁ = n / length(set)
                push!(from, min(a, b)); push!(to, max(a, b))
                push!(bin, _binlabel(d)); push!(real, rl)
                push!(pr, p₁ + (1 - p₁) * ff)
                push!(instrata, (min(a, b), max(a, b)))
            end
        end
    end

    # pairs in no stratum, reachable only through the fill
    if randomfill && gap > 0
        for (pool, rl, ff) in ((poolr, true, fillfrac[1]), (poolf, false, fillfrac[2]))
            ff > 0 || continue
            for p in pool
                p in instrata && continue
                push!(from, p[1]); push!(to, p[2])
                push!(bin, "none"); push!(real, rl); push!(pr, ff)
            end
        end
    end
    return DataFrame(from = from, to = to, bin = bin, real = real, pi = pr)
end
