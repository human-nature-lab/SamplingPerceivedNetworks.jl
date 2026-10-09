
function sort_edgelist!(ru, c1, c2)
    for (i, r) in enumerate(eachrow(ru))
        ru[i, [c1, c2]] = sort([r[c1], r[c2]])
    end
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
        tupleize(alters1, alters2; sort = true)

Create a vector of tuples from the columns of an edgelist. If asymmetric, sort should be false.
"""
function tupleize(alters1, alters2; sort = false)
    tups = Vector{Tuple{String, String}}(undef, length(alters1))
    for (i, (e1, e2)) in enumerate(zip(alters1, alters2))
        tups[i] = if sort
            tups[i] = if e1 > e2
                (e2, e1)
            else
                (e1, e2)
            end
        else
            (e1, e2)
        end
    end
    return tups
end
