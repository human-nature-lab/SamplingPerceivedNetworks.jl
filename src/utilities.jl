
"""
        sort_edgelist!(df, c1, c2)

Within each row of the `DataFrame` `df`, order the values in columns `c1` and
`c2` alphanumerically (so that an undirected tie always reads the same way).
"""
function sort_edgelist!(ru, c1, c2)
    a, b = ru[!, c1], ru[!, c2]
    for i in eachindex(a, b)
        if a[i] > b[i]
            a[i], b[i] = b[i], a[i]
        end
    end
    return ru
end

"""
        psn_edgelists(vertlists; df_out = true)

Flatten the output of `samplenetwork` (a dictionary from perceiver name to
that perceiver's list) into one edgelist with a row per (perceiver, pair).
Columns: `perceiver`, `from`, `to`; if the lists were generated with
`moreinfo = true`, also `bin` (the degree bin, e.g., "1:2" or "3") and `real`
(whether the pair is a real tie). Each pair is sorted alphanumerically.
Return a `DataFrame`, or a `Matrix` if `df_out` is false.
"""
function psn_edgelists(vertlists; df_out = true)
    moreinfo = !isempty(vertlists) && first(values(vertlists)) isa Tuple

    perceiver = String[]; from = String[]; to = String[]
    bin = String[]; real = Bool[]

    for (k, v) in vertlists
        pairs = moreinfo ? v[1] : v
        for (a, b) in pairs
            push!(perceiver, k)
            push!(from, min(a, b))
            push!(to, max(a, b))
        end
        if moreinfo
            append!(bin, string.(v[2]))
            append!(real, v[3])
        end
    end

    el = DataFrame(perceiver = perceiver, from = from, to = to)
    if moreinfo
        el.bin = bin
        el.real = real
    end
    return df_out ? el : Matrix(el)
end

"""
        edgelist(graph; df_out = true)

Extract the sociocentric edgelist of `graph` (a `MetaGraph` with `:name`
vertex properties) as node names. Return a `DataFrame` with columns `from` and
`to`, each row sorted alphanumerically; if `df_out` is false, return the raw
`Matrix` of names in the graph's edge order (rows are not sorted).
"""
function edgelist(graph; df_out = true)
    el = fill("", length(edges(graph)), 2);
    for (i, e) in enumerate(edges(graph))
        el[i, 1] = get_prop(graph, src(e), :name)
        el[i, 2] = get_prop(graph, dst(e), :name)
    end

    if df_out
        el = DataFrame(from = el[:, 1], to = el[:, 2])
        sort_edgelist!(el, 1, 2)
    end
    return el
end

"""
        countdesired(desired)

Total number of relationships in a `desired` specification, i.e., the sum of
all (# real, # counterfactual) entries: the target list length per perceiver.
"""
function countdesired(desired)
    nrel = 0
    for des in desired
        nrel += sum(des)
    end
    return nrel
end

"""
        tuplesort!(pls)

Alphanumerically sort a vector of tuples.
"""
function tuplesort!(pls)
    for (i, (e1, e2)) in enumerate(pls)
        if e1 > e2
            # if e1 is alphanumerically after e2, switch their values
            pls[i] = (e2, e1)
        end
    end
end

"""
        tupleize(alters1, alters2; sort = false)

Create a vector of tuples from the columns of an edgelist. If `sort` is true, each tuple is ordered alphanumerically (for symmetric ties); leave it false if the ties are asymmetric.
"""
function tupleize(alters1, alters2; sort = false)
    tups = Vector{Tuple{String, String}}(undef, length(alters1))
    for (i, (e1, e2)) in enumerate(zip(alters1, alters2))
        tups[i] = if sort
            e1 > e2 ? (e2, e1) : (e1, e2)
        else
            (e1, e2)
        end
    end
    return tups
end
