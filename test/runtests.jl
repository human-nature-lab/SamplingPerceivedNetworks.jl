using Test, Random, Graphs, MetaGraphs, DataFrames
using SamplingPerceivedNetworks
const SPN = SamplingPerceivedNetworks

function named_graph(g)
    mg = MetaGraph(g)
    for i in 1:nv(mg); set_prop!(mg, i, :name, "p$i"); end
    return mg
end

pair(a, b) = a < b ? (a, b) : (b, a)

# brute force: the orbit of v, from shortest-path distances
# real tie (u, w), u,w != v, both within dmax of v: bin max(dist(u), dist(w))
# counterfactual: the same for non-adjacent pairs
function brute_bins(mg, v, dmax)
    dist = gdistances(mg, v)
    name(i) = get_prop(mg, i, :name)
    bins = Dict((d, r) => Set{Tuple{String,String}}() for d in 1:dmax, r in (true, false))
    others = [u for u in vertices(mg) if u != v && dist[u] <= dmax]
    for (i, u) in enumerate(others), w in others[i+1:end]
        d = max(dist[u], dist[w])
        push!(bins[d, has_edge(mg, u, w)], pair(name(u), name(w)))
    end
    return bins
end

orbit_bins(mg, v, dmax) = Dict(
    k => Set(pair.(first.(x), last.(x))) for (k, x) in
        samplingbins(vertexorbit(mg, v, dmax), dmax)
)

@testset "orbit and bins match brute force" begin
    # hand-computed: path 1-2-3-4-5 with a chord 2-4, perceiver 1
    mg = named_graph(SimpleGraph(Edge.([(1,2),(2,3),(3,4),(4,5),(2,4)])))
    b = orbit_bins(mg, 1, 3)
    @test b[1, true] == Set{Tuple{String,String}}()           # alter 2 is alone at d = 1
    @test b[2, true] == Set([("p2","p3"), ("p2","p4"), ("p3","p4")])
    @test b[2, false] == Set{Tuple{String,String}}()
    @test b[3, true] == Set([("p4","p5")])
    @test b[3, false] == Set([("p2","p5"), ("p3","p5")])
    @test b == brute_bins(mg, 1, 3)

    # random graphs, every perceiver, several dmax
    rng = MersenneTwister(1)
    for g in (watts_strogatz(40, 4, 0.3; rng = rng), erdos_renyi(35, 0.08; rng = rng),
              barabasi_albert(30, 2; rng = rng))
        mg = named_graph(g)
        for dmax in (2, 3, 4), v in vertices(mg)
            @test orbit_bins(mg, v, dmax) == brute_bins(mg, v, dmax)
        end
    end
end

@testset "samplebins: stratified draw and gap carry-over" begin
    mkpairs(tag, n) = [("$(tag)a$i", "$(tag)b$i") for i in 1:n]
    function mkbins(sizes)  # sizes[(d, real)] => number of pairs
        bins = Dict{Tuple{Int,Bool},Vector{Tuple{String,String}}}()
        for ((d, r), n) in sizes
            bins[d, r] = mkpairs("$d$r", n)
        end
        return bins
    end
    desired = ((10, 10), (5, 5), (5, 5)); dvals = (1:2, 3, 4)
    tally(deg, real) = Dict(
        (d, r) => count(i -> deg[i] == d && real[i] == r, eachindex(deg))
        for d in unique(deg), r in (true, false)
    )

    # plentiful bins: exactly the desired counts
    big = mkbins(Dict((d, r) => 50 for d in 1:4, r in (true, false)))
    cog, deg, real = samplebins(MersenneTwister(1), big; desired, dvals, moreinfo = true)
    t = tally(deg, real)
    @test length(cog) == 40 && allunique(cog)
    @test t[1:2, true] == 10 && t[1:2, false] == 10
    @test t[3, true] == 5 && t[3, false] == 5 && t[4, true] == 5 && t[4, false] == 5

    # shortfalls: real d1:2 has 3 (7 short), real d3 has 20, real d4 has 2,
    # fake d1:2 has 100, fake d3 has 1, fake d4 has 100.
    # hand computation of the algorithm's gap rule:
    #   real 1:2 -> 3 (ws 10, ts 3); real 3 -> 5+7 = 12 (ws 15, ts 15);
    #   real 4 -> min(2, 5) = 2 (ws 20, ts 17);
    #   fake 1:2 -> 10 + 3 = 13 (ws 30, ts 30); fake 3 -> min(1, 5) = 1
    #   (ws 35, ts 31); fake 4 -> 5 + 4 = 9
    small = mkbins(Dict(
        (1, true) => 2, (2, true) => 1, (3, true) => 20, (4, true) => 2,
        (1, false) => 60, (2, false) => 40, (3, false) => 1, (4, false) => 100,
    ))
    cog, deg, real = samplebins(MersenneTwister(2), small; desired, dvals, moreinfo = true)
    cnt(d, r) = count(i -> deg[i] == d && real[i] == r, eachindex(deg))
    @test cnt(1:2, true) == 3 && cnt(3, true) == 12 && cnt(4, true) == 2
    @test cnt(1:2, false) == 13 && cnt(3, false) == 1 && cnt(4, false) == 9
    @test length(cog) == 40 && allunique(cog)

    # every sampled pair belongs to the bin it is labelled with
    for (p, d, r) in zip(cog, deg, real)
        ds = d isa UnitRange ? collect(d) : [d]
        @test any(x -> p in small[x, r], ds)
    end

    # moreinfo = false returns only the pairs, identical for the same rng
    @test samplebins(MersenneTwister(2), small; desired, dvals) == cog

    # a total shortfall is not made up out of thin air
    tiny = mkbins(Dict((d, r) => 1 for d in 1:4, r in (true, false)))
    @test length(samplebins(MersenneTwister(3), tiny; desired, dvals)) == 1 * 2 * 4

    # sampling without replacement is uniform: each element of a bin of 10,
    # drawn 3 at a time, is included with probability 0.3
    one = Dict((1, true) => mkpairs("x", 10), (1, false) => Tuple{String,String}[])
    hits = Dict(p => 0 for p in one[1, true])
    rng = MersenneTwister(4); R = 30_000
    for _ in 1:R
        for p in samplebins(rng, one; desired = ((3, 0),), dvals = (1,))
            hits[p] += 1
        end
    end
    @test all(abs(h / R - 0.3) < 0.015 for h in values(hits))
end

@testset "consents" begin
    mg = named_graph(watts_strogatz(40, 4, 0.3; rng = MersenneTwister(5)))
    names = [get_prop(mg, i, :name) for i in vertices(mg)]
    status = Dict(nm => [0, 1, 2, 3][mod1(i, 4)] for (i, nm) in enumerate(names))
    kw = (desired = ((3, 3), (2, 2), (2, 2)), dvals = (1:2, 3, 4), moreinfo = true)

    lists = samplenetwork(MersenneTwister(6), mg, status; kw...)
    # perceivers: only those who consented to the survey (1 or 2)
    @test Set(keys(lists)) == Set(nm for nm in names if status[nm] in (1, 2))
    # shown pairs: both consented to photo (2 or 3)
    for (k, v) in lists, (a, b) in v[1]
        @test status[a] >= 2 && status[b] >= 2
        @test k != a && k != b
    end

    # the filtered bins are the unfiltered ones minus non-consented pairs
    rad = vertexorbit(mg, 1, 4)
    full = samplingbins(rad, 4); filt = samplingbins(rad, 4, status)
    for k in keys(full)
        @test Set(filt[k]) == Set(p for p in full[k] if status[p[1]] >= 2 && status[p[2]] >= 2)
    end

    # missing consent entries are an error, with a message
    bad = delete!(copy(status), "p7")
    @test_throws ArgumentError samplenetwork(MersenneTwister(6), mg, bad; kw...)
end

@testset "samplenetwork variants" begin
    mg = named_graph(watts_strogatz(60, 4, 0.3; rng = MersenneTwister(7)))
    consents = Dict(get_prop(mg, i, :name) => (i % 5 == 0 ? 0 : 2) for i in vertices(mg))
    kw = (desired = ((10, 10), (5, 5), (5, 5)), dvals = (1:2, 3, 4))
    for mi in (false, true), sh in (false, true)
        a = samplenetwork(mg; kw..., moreinfo = mi, shuffle = sh)
        b = samplenetwork(MersenneTwister(1), mg; kw..., moreinfo = mi, shuffle = sh)
        b2 = samplenetwork(MersenneTwister(1), mg; kw..., moreinfo = mi, shuffle = sh)
        c = samplenetwork(MersenneTwister(1), mg, consents; kw..., moreinfo = mi, shuffle = sh)
        @test b == b2
        n(x) = mi ? length(x[1]) : length(x)
        pairs(x) = mi ? x[1] : x
        @test all(n(v) == 40 for v in values(a)) && all(n(v) == 40 for v in values(b))
        @test length(c) == 48
        @test all(all(p[1] <= p[2] for p in pairs(v)) for v in values(c))
        mi && @test all(length(v[1]) == length(v[2]) == length(v[3]) for v in values(c))
    end

    # shuffling permutes pairs, degrees and realness together
    lst = samplenetwork(MersenneTwister(1), mg; kw..., moreinfo = true, shuffle = true)
    plain = samplenetwork(MersenneTwister(1), mg; kw..., moreinfo = true, shuffle = false)
    for k in keys(lst)
        @test sort(lst[k][1]) == sort(plain[k][1])
        @test Set(zip(lst[k]...)) == Set(zip(plain[k]...))
    end

    # an isolated vertex gets a (possibly empty) list without error
    g2 = named_graph(SimpleGraph(Edge.([(1,2),(2,3),(3,4)])))
    add_vertex!(g2); set_prop!(g2, 5, :name, "p5")
    l = samplenetwork(g2; desired = ((2, 2), (2, 2)), dvals = (1, 2), moreinfo = true)
    @test isempty(l["p5"][1])
end

@testset "edgelists" begin
    mg = named_graph(watts_strogatz(30, 4, 0.3; rng = MersenneTwister(8)))
    kw = (desired = ((10, 10), (5, 5), (5, 5)), dvals = (1:2, 3, 4))
    rich = psn_edgelists(samplenetwork(mg; kw..., moreinfo = true))
    @test names(rich) == ["perceiver", "from", "to", "bin", "real"]
    @test nrow(rich) == 30 * 40
    @test all(rich.from .<= rich.to)
    @test Set(rich.bin) ⊆ Set(["1:2", "3", "4"])
    @test eltype(rich.real) == Bool

    bare = psn_edgelists(samplenetwork(mg; kw...))
    @test names(bare) == ["perceiver", "from", "to"]
    @test nrow(bare) == 30 * 40
    @test psn_edgelists(samplenetwork(mg; kw..., moreinfo = true); df_out = false) isa Matrix

    el = edgelist(mg)
    @test nrow(el) == ne(mg) && all(el.from .<= el.to)
    @test tupleize(["b", "a"], ["a", "b"]; sort = true) == [("a", "b"), ("a", "b")]
end
