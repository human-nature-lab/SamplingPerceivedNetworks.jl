# _samplenet!.jl

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

            # sort the edges alphanumericaly
            tuplesort!(verticeslists[nodename])

            if shuffle
                # length of the list of pairs
                # drop [1] index since we don't keep
                # (pairs, degree, realness) -> only pairs
                ln = length(verticeslists[nodename]);
                if ln > 1 # if there is more than one valid pair
                    # shuffle the pairs for random presentation
                    idx = sample(
                        MersenneTwister(seed), collect(1:ln), ln;
                        replace = false
                    )
                    # iterate over the info types (pairs, degree, realness)
                    # we don't store all of these for branch "Server"
                    # so don't iterate
                    if !moreinfo
                        permute!(verticeslists[nodename], idx)
                    else
                        for k in 1:3
                            permute!(verticeslists[nodename][k], idx)
                        end
                    end
                end
            end
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
        rad = vertexorbit(graph, v, dₘₐₓ); # 2.79 MiB
        bins = samplingbins(rad, dₘₐₓ);
    
        verticeslists[get_prop(graph, v, :name)] = samplebins(
            MersenneTwister(seed),
            bins;
            desired = desired, dvals = dvals, moreinfo = moreinfo
        )

        # sort the edges alphanumericaly
        tuplesort!(verticeslists[nodename])

        if shuffle
            # length of the list of pairs
            # drop [1] index since we don't keep
            # (pairs, degree, realness) -> only pairs
            ln = length(verticeslists[get_prop(graph, v, :name)]);
            if ln > 1 # if there is more than one valid pair
                # shuffle the pairs for random presentation
                idx = sample(
                    MersenneTwister(seed), collect(1:ln), ln;
                    replace = false
                )
                # iterate over the info types (pairs, degree, realness)
                # we don't store all of these for branch "Server"
                # so don't iterate
                permute!(verticeslists[get_prop(graph, v, :name)], idx)
            end
        end
    end
end
