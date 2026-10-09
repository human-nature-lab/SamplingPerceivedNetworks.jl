# randomfill.jl
# fill short lists to the target length, and lists for isolates, with pairs
# drawn uniformly from the whole village (port of HonCog.jl, the deployment
# code: `randomfill!.jl`, `randomfills.jl`, `randomfill_utilities.jl`,
# `isolates.jl`)

"""
        splitwanted(wanted)

Split the number of pairs `wanted` into real and counterfactual parts,
`(ceil(wanted / 2), floor(wanted / 2))`, as HonCog did: an odd gap gets one
more real pair.
"""
splitwanted(wanted) = (cld(wanted, 2), fld(wanted, 2))

#=
Village-wide candidate pairs for the fill and the isolates, as HonCog built
them: every real tie, and every non-adjacent pair, among the nodes of `graph`
(HonCog's nodes were those in the edgelist, so isolates are not candidates),
keeping only pairs whose members both have consent code >= 2. Pairs are
sorted alphanumerically. The order follows HonCog for a graph built from the
edgelist as `HonCog.villagegraph` does: real ties in edge order, and
counterfactual pairs (a, b), a < b, with the second member in the outer loop.
=#
function _fillpools(graph, consents = nothing)
    rawnames = [get_prop(graph, u, :name) for u in vertices(graph)]
    names = string.(rawnames)
    ok = consents === nothing ? fill(true, nv(graph)) :
        [_consent_ok(nm, consents) for nm in rawnames]

    reals = Tuple{String, String}[]
    for e in edges(graph)
        a, b = src(e), dst(e)
        ok[a] && ok[b] || continue
        push!(reals, names[a] < names[b] ? (names[a], names[b]) : (names[b], names[a]))
    end

    fakes = Tuple{String, String}[]
    for j in vertices(graph), i in vertices(graph)
        if names[i] < names[j] && ok[i] && ok[j] && !has_edge(graph, i, j)
            push!(fakes, (names[i], names[j]))
        end
    end
    return reals, fakes
end

# pairs that do not involve the perceiver k
_withoutperceiver(ls, k) = filter(p -> !(k in p), ls)

# draw `nr` real and `nf` counterfactual pairs (at most what each pool has),
# then shuffle them together, in HonCog's order of rng calls
function _drawfill(rng, reals, fakes, nr, nf, shuffle)
    rs = sample(rng, reals, min(length(reals), nr); replace = false)
    fs = sample(rng, fakes, min(length(fakes), nf); replace = false)
    newpairs = vcat(rs, fs)
    newreal = vcat(fill(true, length(rs)), fill(false, length(fs)))
    if shuffle
        idx = sample(rng, collect(1:length(newpairs)), length(newpairs); replace = false)
        newpairs, newreal = newpairs[idx], newreal[idx]
    end
    return newpairs, newreal
end

"""
        _randomfill!(rng, lists, reals, fakes, target, moreinfo, shuffle, excludeperceiver)

Port of HonCog `randomfill!`/`_randomfill!`. For each list shorter than
`target`, draw `splitwanted(gap)` real and counterfactual pairs uniformly,
without replacement, from the village pools minus the pairs already on the
list (and, with `excludeperceiver`, minus the pairs involving the perceiver),
shuffle them, and append them after the stratified pairs. Each pool supplies
at most what it has; a real shortfall is not made up from counterfactuals.
Lists are visited in `Dict` order, as in HonCog.
"""
function _randomfill!(rng, lists, reals, fakes, target, moreinfo, shuffle, excludeperceiver)
    for (k, lst) in lists
        pairs = moreinfo ? lst[1] : lst
        length(pairs) < target || continue
        gapreal, gapfake = splitwanted(target - length(pairs))

        # copies, so that the village pools are never modified
        allowed = isempty(pairs) ? copy(reals) : setdiff(reals, pairs)
        allowedfakes = isempty(pairs) ? copy(fakes) : setdiff(fakes, pairs)
        if excludeperceiver
            allowed = _withoutperceiver(allowed, k)
            allowedfakes = _withoutperceiver(allowedfakes, k)
        end

        # only bother if there are allowable pairs to add
        if !isempty(allowed) || !isempty(allowedfakes)
            newpairs, newreal = _drawfill(
                rng, allowed, allowedfakes, gapreal, gapfake, shuffle
            )
            append!(pairs, newpairs)
            if moreinfo
                append!(lst[2], fill(FILLBIN, length(newpairs)))
                append!(lst[3], newreal)
            end
        end
    end
    return lists
end

"""
        _isolatefill!(rng, lists, isolates, reals, fakes, target, moreinfo, shuffle)

Port of HonCog `isolatefill!`. Each isolate gets `splitwanted(target)` real
and counterfactual pairs drawn uniformly from the whole village pools, with no
exclusions. The new list replaces any list the person already has, unless it
is empty.
"""
function _isolatefill!(rng, lists, isolates, reals, fakes, target, moreinfo, shuffle)
    wantreal, wantfake = splitwanted(target)
    for k in isolates
        newpairs, newreal = _drawfill(rng, reals, fakes, wantreal, wantfake, shuffle)
        if !isempty(newpairs)
            lists[string(k)] = moreinfo ?
                (newpairs, Union{Int, UnitRange{Int}}[FILLBIN for _ in newpairs], newreal) :
                newpairs
        end
    end
    return lists
end

# isolates who get a list: HonCog kept those with consent code > 1 (2 or 3)
function _eligibleisolates(isolates, consents)
    consents === nothing && return collect(isolates)
    for k in isolates
        haskey(consents, k) || throw(ArgumentError(
            "consents has no entry for isolate $k"
        ))
        ismissing(consents[k]) && throw(ArgumentError(
            "consent for isolate $k is missing"
        ))
    end
    return [k for k in isolates if consents[k] > 1]
end

# target list length: all quotas, including the outer bin's
_target(desired, outer) = countdesired(desired) + (outer === nothing ? 0 : sum(outer))
