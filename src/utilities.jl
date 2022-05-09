
function sort_edgelist!(ru, c1, c2)
    for (i, r) in enumerate(eachrow(ru))
        ru[i, [c1, c2]] = sort([r[c1], r[c2]])
    end
end

function psn_edgelist(graph, cogls)
    # edgelist
    return hcat(
        fill(get_prop(graph, 1, :name), length(cogls)),
        [c[1] for c in cogls],
        [c[2] for c in cogls]
    )
end

function psn_edgelists(vertlists; df_out = true)
    el = Matrix{String}(undef, 0, 5);
    # edgelist
    for (k, v) in vertlists
        cogls = v[1]
        v
        el = vcat(
            el,
            hcat(
                fill(k, length(cogls)),
                [c[1] for c in cogls],
                [c[2] for c in cogls],
                v[2],
                v[3]
            )
        )
    end

    if df_out
        el = DataFrame(
            perceiver = el[:,1],
            from = el[:, 2],
            to = el[:, 3],
            bin = el[:, 4],
            real = el[:, 5],
        )
        sort_edgelist!(el, 2, 3)
    end
    return el
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
