# alternate.jl
# alternate sampling
# NOT USED

NodeBin2 = Tuple{Vector{Tuple{String, String}}, Vector{Union{UnitRange{Int64}, Int64}}, Vector{Bool}}

NodeBin1 = Vector{Tuple{String, String}}

function permute_nodebin!(seed, nodebin)
    ln = length_nodebin(nodebin);
    if ln > 1
        idx = sample(
                MersenneTwister(seed), collect(1:ln), ln;
                replace = false
            );
        _permute_nodebin!(nodebin, idx)
    end
end

function _permute_nodebin!(nb::NodeBin1, idx)
    permute!(nb , idx)
end

function _permute_nodebin!(nb::NodeBin2, idx)
    for n in nb
        permute!(n , idx)
    end
end

function length_nodebin(nb::NodeBin1)
    return length(nb)
end

function length_nodebin(nb::NodeBin2)
    return length(nb[1])
end

function add_to_edgetable!(edgetab, nodebin::NodeBin1, nodename)
    for (e1, e2) in nodebin
        push!(edgetab, [nodename, e1, e2])
    end
end

function add_to_edgetable!(edgetab, nodebin::NodeBin2, nodename)
    for ((e1, e2), b, r) in zip(nodebin...)
        push!(edgetab, [nodename, e1, e2, b, r])
    end
end

"""
        init_edgetable(nrows, moreinfo)

Initialze the edgetable for sampling list output. Once filled, this object will be streamed out, via stdout.
"""
function init_edgetable(nrows, moreinfo)

    return if !moreinfo
        DataFrame(
            :perceiver => Vector{String}(undef, nrows),
            :alter1 => Vector{String}(undef, nrows),
            :alter2 => Vector{String}(undef, nrows)
        )
    else
        DataFrame(
            :perceiver => Vector{String}(undef, nrows),
            :alter1 => Vector{String}(undef, nrows),
            :alter2 => Vector{String}(undef, nrows),
            :bin => Vector{Int}(undef, nrows),
            :real => Vector{Bool}(undef, nrows)
        )
    end
end

function _samplenet!(
    seeds,
    edgetab,
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
        nodename = get_prop(graph, v, :name);

        if consents[nodename] != 0

            rad = vertexorbit(graph, v, dₘₐₓ); # 2.79 MiB
            bins = samplingbins(rad, dₘₐₓ, consents);

            # only one call per seed number (i.e., one seed per villager)
            nodebin = samplebins(
                MersenneTwister(seed),
                bins;
                desired = desired,
                dvals = dvals,
                moreinfo = moreinfo
            );

            if shuffle
                permute_nodebin!(seed, nodebin)
            end

            add_to_edgetable!(edgetab, nodebin, nodename)

        end
    end
end
