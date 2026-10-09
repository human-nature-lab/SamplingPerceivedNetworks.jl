# _samplenet!.jl

#=
Finish one perceiver's list: sort the pairs alphanumerically and optionally
shuffle them for random presentation. With moreinfo the list is
(pairs, degrees, realness); only the pairs are sorted, and all three
are permuted together.
=#
function _finishlist!(lst, moreinfo, shuffle, rng)
    pairs = moreinfo ? lst[1] : lst
    tuplesort!(pairs)

    if shuffle
        ln = length(pairs)
        if ln > 1
            idx = sample(rng, collect(1:ln), ln; replace = false)
            if moreinfo
                for k in 1:3
                    permute!(lst[k], idx)
                end
            else
                permute!(lst, idx)
            end
        end
    end
    return lst
end

function _samplenet!(
    seeds,
    verticeslists,
    graph,
    consents,
    dₘₐₓ,
    desired,
    dvals,
    moreinfo,
    shuffle
)

    for (v, seed) in zip(vertices(graph), seeds)

        # if consent[node_name] == 0 then skip, since
        # the person will not be surveyed for css
        nodename = get_prop(graph, v, :name)

        # consent states:         
        # 0: not consented to either
        # 1: consented to survey
        # 2: consented to survey and photo
        # 3: consented to photo, but not survey
        # include as perceivers those who agreed to survey
        if (consents[nodename] == 1) | (consents[nodename] == 2)

            rad = vertexorbit(graph, v, dₘₐₓ);
            bins = samplingbins(rad, dₘₐₓ, consents);
        
            # only one call per seed number (i.e., one seed per villager)
            verticeslists[nodename] = samplebins(
                MersenneTwister(seed),
                bins;
                desired = desired, dvals = dvals, moreinfo = moreinfo
            )

            _finishlist!(
                verticeslists[nodename], moreinfo, shuffle, MersenneTwister(seed)
            )
        end # (consents[nodename]...
    end # (v,seed)
end

function _samplenet!(
    seeds,
    verticeslists,
    graph,
    dₘₐₓ,
    desired,
    dvals,
    moreinfo,
    shuffle
)

    for (v, seed) in zip(vertices(graph), seeds)
        nodename = get_prop(graph, v, :name)
        rad = vertexorbit(graph, v, dₘₐₓ);
        bins = samplingbins(rad, dₘₐₓ);

        # only one call per seed number (i.e., one seed per villager)
        verticeslists[nodename] = samplebins(
            MersenneTwister(seed),
            bins;
            desired = desired, dvals = dvals, moreinfo = moreinfo
        )

        _finishlist!(
            verticeslists[nodename], moreinfo, shuffle, MersenneTwister(seed)
        )
    end
end
