using Test, Random, Graphs, MetaGraphs, DataFrames
using SamplingPerceivedNetworks
using SamplingPerceivedNetworks: splitwanted
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

@testset "_vertexbins reproduces samplingbins(vertexorbit) exactly" begin
    rng = MersenneTwister(11)
    graphs = (watts_strogatz(40, 4, 0.3; rng = rng), erdos_renyi(35, 0.05; rng = rng),
              barabasi_albert(30, 2; rng = rng))
    for g in graphs
        mg = named_graph(g)
        cons = Dict("p$i" => rand(rng, 0:3) for i in 1:nv(mg))
        for dmax in (1, 3, 5), v in vertices(mg)
            @test SPN._vertexbins(mg, v, dmax) == samplingbins(vertexorbit(mg, v, dmax), dmax)
            @test SPN._vertexbins(mg, v, dmax, cons) ==
                samplingbins(vertexorbit(mg, v, dmax), dmax, cons)
        end
    end
end

@testset "vertexorbit edge cases" begin
    # isolated vertex and a second component
    mg = named_graph(SimpleGraph(Edge.([(1,2),(2,3),(4,5)])))
    add_vertex!(mg); set_prop!(mg, 6, :name, "p6")
    @test ne(vertexorbit(mg, 6, 3)) == 0
    @test nv(vertexorbit(mg, 1, 10)) == 2          # dmax beyond the diameter; other component excluded
    @test SPN._vertexbins(mg, 6, 3) == samplingbins(vertexorbit(mg, 6, 3), 3)
    # index = false (requires name indexing)
    set_indexing_prop!(mg, :name)
    @test nv(vertexorbit(mg, "p1", 2; index = false)) == nv(vertexorbit(mg, 1, 2))
    # vertexorbit_d keeps only ties at d
    rad = vertexorbit(named_graph(watts_strogatz(20, 4, 0.3; rng = MersenneTwister(2))), 1, 3)
    for d in 1:3
        radd = SPN.vertexorbit_d(rad, d)
        @test all(get_prop(radd, e, :d) == d for e in edges(radd))
    end
end

@testset "argument validation" begin
    mg = named_graph(watts_strogatz(20, 4, 0.3; rng = MersenneTwister(3)))
    @test_throws ArgumentError samplenetwork(mg; desired = ((3, 3), (2, 2)), dvals = (1:2,))
    @test_throws ArgumentError samplenetwork(mg; desired = ((3, 3),), dvals = (3:2,))
    @test_throws ArgumentError samplebins(Dict{Tuple{Int,Bool},Vector{Tuple{String,String}}}();
        desired = ((1, 1), (1, 1)), dvals = (1,))
    bins = samplingbins(vertexorbit(mg, 1, 2), 2)
    @test_throws ArgumentError samplebins(bins; desired = ((1, 1),), dvals = (3,))
    @test_throws ArgumentError samplingbins(vertexorbit(mg, 1, 3), 2)
    @test_throws ArgumentError samplingbins(vertexorbit(mg, 1, 2), 2, Dict("p2" => 2))
    # StepRange dvals work
    @test length(samplebins(bins; desired = ((2, 2),), dvals = (1:1:2,))) == 4
end

@testset "samplenetwork without rng, with consents" begin
    mg = named_graph(watts_strogatz(30, 4, 0.3; rng = MersenneTwister(4)))
    cons = Dict("p$i" => 2 for i in 1:30)
    r = samplenetwork(mg, cons; desired = ((3, 3), (3, 3)), dvals = (1, 2))
    @test length(r) == 30 && all(0 < length(l) <= 12 for l in values(r))
    Random.seed!(1); a = samplenetwork(mg; desired = ((3, 3), (3, 3)), dvals = (1, 2))
    Random.seed!(1); b = samplenetwork(mg; desired = ((3, 3), (3, 3)), dvals = (1, 2))
    @test a == b
end

@testset "utilities and name handling" begin
    @test countdesired(((10, 10), (5, 5), (5, 5))) == 40
    v = [("b", "a"), ("a", "b"), ("c", "d")]
    tuplesort!(v)
    @test v == [("a", "b"), ("a", "b"), ("c", "d")]
    df = DataFrame(x = ["b", "a"], y = ["a", "b"])
    sort_edgelist!(df, :x, :y)
    @test df.x == ["a", "a"] && df.y == ["b", "b"]
    @test edgelist(named_graph(path_graph(3)); df_out = false) isa Matrix

    # integer node names are converted to Strings
    mg = MetaGraph(watts_strogatz(20, 4, 0.3; rng = MersenneTwister(9)))
    for i in 1:nv(mg); set_prop!(mg, i, :name, i); end
    r = samplenetwork(MersenneTwister(1), mg; desired = ((2, 2), (2, 2)), dvals = (1, 2))
    @test all(k isa String for k in keys(r))
    cons = Dict(i => 2 for i in 1:20)
    @test length(samplenetwork(MersenneTwister(1), mg, cons; desired = ((2, 2),), dvals = (1,))) == 20

    # missing consent values are an ArgumentError
    mgs = named_graph(watts_strogatz(20, 4, 0.3; rng = MersenneTwister(9)))
    cm = Dict{String,Union{Int,Missing}}("p$i" => 2 for i in 1:20); cm["p3"] = missing
    @test_throws ArgumentError samplenetwork(MersenneTwister(1), mgs, cm)
end

@testset "presets" begin
    @test deployed_design.dvals == (1, 2, 3, 4)
    @test all(==((5, 5)), deployed_design.desired)
    @test countdesired(deployed_design.desired) == 40
    @test countdesired(merged_design.desired) == 40

    # samplebins and samplenetwork default to the deployed design
    mg = named_graph(watts_strogatz(60, 6, 0.3; rng = MersenneTwister(11)))
    bins = samplingbins(vertexorbit(mg, 1, 4), 4)
    @test samplebins(MersenneTwister(1), bins) ==
          samplebins(MersenneTwister(1), bins; deployed_design...)
    @test samplenetwork(MersenneTwister(2), mg) ==
          samplenetwork(MersenneTwister(2), mg; deployed_design...)

    # the merged preset is accepted and gives the merged bin
    _, deg, _ = samplebins(MersenneTwister(1), bins; merged_design..., moreinfo = true)
    @test any(==(1:2), deg)
end

@testset "inclusionprobs" begin
    # hand-computed: path 1-2-3-4-5 with a chord 2-4, perceiver 1, d up to 3
    mg = named_graph(SimpleGraph(Edge.([(1,2),(2,3),(3,4),(4,5),(2,4)])))
    kw = (desired = ((1, 1), (1, 1), (1, 1)), dvals = (1, 2, 3))
    df = inclusionprobs(mg, 1; kw...)
    # bins: (2, real) = 3 pairs, (3, real) = 1, (3, fake) = 2; d = 1 is empty.
    # Real: d1 -> 0 (empty), gap 1 -> d2 draws 1 + 1 = 2 of 3, d3 draws 1 of 1
    # (ws 3, ts 3). Fake: d1 and d2 are empty (ws 5, ts 3), so d3 draws
    # 1 + 2 = 3 but has only 2: both pairs, pi = 1.
    p(a, b) = only(df[(df.from .== a) .& (df.to .== b), :pi])
    @test nrow(df) == 6
    @test all(p.(["p2","p2","p3"], ["p3","p4","p4"]) .≈ 2/3)
    @test p("p4", "p5") ≈ 1
    @test p("p2", "p5") ≈ 1 && p("p3", "p5") ≈ 1
    @test Set(df.bin) == Set(["2", "3"])

    # the probabilities in each (bin, reality) cell sum to the number drawn
    mg = named_graph(watts_strogatz(60, 6, 0.3; rng = MersenneTwister(12)))
    for v in (1, 17, 42)
        df = inclusionprobs(mg, v)
        @test sum(df.pi) <= 40 + 1e-9  # never more than the list length
        @test all(0 .< df.pi .<= 1)
    end

    # empirical inclusion frequency = pi, for the deployed design and one with
    # a short bin (so that carry-over is active), with and without consents
    function check(mg, v, consents, kw; R = 20_000, tol = 0.02)
        df = inclusionprobs(mg, v, consents; kw...)
        nm = get_prop(mg, v, :name)
        hits = Dict(
            (r.from, r.to) => 0 for r in eachrow(df)
        )
        rng = MersenneTwister(99)
        bins = SPN._vertexbins(mg, v, maximum(maximum, kw.dvals), consents)
        for _ in 1:R
            for (a, b) in samplebins(rng, bins; kw...)
                hits[min(a, b), max(a, b)] += 1
            end
        end
        @test all(
            abs(hits[r.from, r.to] / R - r.pi) < tol for r in eachrow(df)
        )
        # every listed pair is a candidate, so the expected list length matches
        @test sum(values(hits)) / R ≈ sum(df.pi) atol = 0.1
    end
    sparse = named_graph(watts_strogatz(30, 4, 0.2; rng = MersenneTwister(13)))
    for v in (1, 9)
        check(sparse, v, nothing, deployed_design)
        check(sparse, v, nothing, (desired = ((3, 3), (3, 3), (6, 6)), dvals = (1, 2, 3)))
        check(sparse, v, nothing, merged_design)
    end
    names = [get_prop(sparse, i, :name) for i in vertices(sparse)]
    cons = Dict(nm => mod(i, 5) == 0 ? 1 : 2 for (i, nm) in enumerate(names))
    check(sparse, 1, cons, deployed_design)

    # network version: perceivers, consents, and agreement with the single form
    all_df = inclusionprobs(sparse; deployed_design...)
    @test Set(all_df.perceiver) == Set(names)
    one = inclusionprobs(sparse, 3)
    sub = all_df[all_df.perceiver .== names[3], Not(:perceiver)]
    @test sort(sub, [:from, :to, :real]) == sort(one, [:from, :to, :real])
    con2 = Dict(nm => [0, 1, 2, 3][mod1(i, 4)] for (i, nm) in enumerate(names))
    cdf = inclusionprobs(sparse, con2)
    @test Set(cdf.perceiver) == Set(nm for (i, nm) in enumerate(names) if con2[nm] in (1, 2))
    # only pairs of nodes with photo consent (code >= 2) appear
    ok = Set(nm for nm in names if con2[nm] >= 2)
    @test all(in(ok), cdf.from) && all(in(ok), cdf.to)

    # argument validation matches samplenetwork
    @test_throws ArgumentError inclusionprobs(sparse, Dict(names[1] => 2))
    @test_throws ArgumentError inclusionprobs(sparse, 1; desired = ((1, 1),), dvals = (1, 2))
end

@testset "carryover = false matches the paper (no compensation)" begin
    pr(tag, n) = [("$(tag)a$i", "$(tag)b$i") for i in 1:n]
    bins = Dict{Tuple{Int,Bool},Vector{Tuple{String,String}}}(
        (1, true) => pr("1t", 2), (2, true) => pr("2t", 10), (3, true) => pr("3t", 10),
        (1, false) => pr("1f", 10), (2, false) => pr("2f", 10), (3, false) => pr("3f", 10),
    )
    kw = (desired = ((5, 5), (5, 5), (5, 5)), dvals = (1, 2, 3), moreinfo = true)
    cnt(r, d, rl) = count(i -> r[2][i] == d && r[3][i] == rl, eachindex(r[2]))

    r = samplebins(MersenneTwister(1), bins; kw..., carryover = false)
    @test [cnt(r, d, true) for d in 1:3] == [2, 5, 5]     # d = 1 stays short
    @test [cnt(r, d, false) for d in 1:3] == [5, 5, 5]
    @test length(r[1]) == 27

    r = samplebins(MersenneTwister(1), bins; kw...)       # default: carries over
    @test [cnt(r, d, true) for d in 1:3] == [2, 8, 5]
    @test length(r[1]) == 30

    # inclusion probabilities follow the same rule
    mg = named_graph(watts_strogatz(40, 4, 0.3; rng = MersenneTwister(12)))
    spec = (desired = ((5, 5), (5, 5), (5, 5)), dvals = (1, 2, 3))
    for v in (1, 7)
        lists = samplenetwork(MersenneTwister(2), mg; spec..., carryover = false)
        nm = "p$v"
        ip = inclusionprobs(mg, v; spec..., carryover = false)
        @test sum(ip.pi) ≈ length(lists[nm])
        @test sum(inclusionprobs(mg, v; spec...).pi) ≥ sum(ip.pi)
    end
end

# a village with short lists: a small world plus small components
function shortvillage(seed)
    g = watts_strogatz(24, 4, 0.2; rng = MersenneTwister(seed))
    for (a, b) in ((25, 26), (26, 27), (25, 27), (28, 29), (29, 30), (31, 32))
        while nv(g) < b; add_vertex!(g); end
        add_edge!(g, a, b)
    end
    return named_graph(g)
end

@testset "samplevillage: fill to the target and isolates" begin
    mg = shortvillage(21)
    nms = [get_prop(mg, i, :name) for i in vertices(mg)]
    cons = Dict(nm => (i % 7 == 0 ? 1 : i % 11 == 0 ? 0 : 2) for (i, nm) in enumerate(nms))
    cons["iso1"] = 2; cons["iso2"] = 3; cons["iso3"] = 1     # isolates, not in the graph
    isolates = ["iso1", "iso2", "iso3"]
    ok(nm) = cons[nm] >= 2
    reals, fakes = SPN._fillpools(mg, cons)
    @test all(ok(a) && ok(b) && a < b for (a, b) in vcat(reals, fakes))
    @test Set(reals) == Set(pair(get_prop(mg, src(e), :name), get_prop(mg, dst(e), :name))
                            for e in edges(mg) if ok("p$(src(e))") && ok("p$(dst(e))"))
    @test length(reals) + length(fakes) == binomial(count(ok, nms), 2)

    strat = samplenetwork(MersenneTwister(3), mg, cons; moreinfo = true)
    @test count(v -> length(v[1]) < 40, values(strat)) >= 5   # the fill is active
    for excl in (false, true)
        lists = samplevillage(MersenneTwister(3), mg, cons; isolates, excludeperceiver = excl,
                              moreinfo = true)
        # isolates with code > 1 get a list (code 3 too); code 1 does not
        @test Set(keys(lists)) == union(Set(keys(strat)), Set(["iso1", "iso2"]))
        for (k, (ps, deg, rl)) in lists
            @test allunique(ps) && length(ps) == 40           # the pools are large enough
            @test all(ok(a) && ok(b) for (a, b) in ps)
            @test rl == [pair(a, b) in Set(reals) for (a, b) in ps]
            k in ("iso1", "iso2") && (@test all(==(-1), deg); @test count(rl) == 20; continue)
            # stratified pairs first, unchanged; then the fill
            s = strat[k]; L = length(s[1]); g = 40 - L
            @test ps[1:L] == s[1] && deg[1:L] == s[2]
            @test all(==(-1), deg[L+1:end])
            @test count(rl[L+1:end]) == cld(g, 2)              # ceil(gap/2) real
            excl && @test !any(k in p for p in ps)
        end
        # with excludeperceiver = false, some fill pairs involve the perceiver
        if !excl
            @test any(any(k in p for p in v[1]) for (k, v) in lists if !startswith(k, "iso"))
        end
    end

    # without the fill and isolates it is samplenetwork
    @test samplevillage(MersenneTwister(3), mg, cons; randomfill = false) ==
          samplenetwork(MersenneTwister(3), mg, cons)
    # an isolate in the graph has their list replaced; reproducible with an rng
    a = samplevillage(MersenneTwister(4), mg; isolates = ["p1"], moreinfo = true)
    @test all(==(-1), a["p1"][2]) && length(a["p1"][1]) == 40
    @test a == samplevillage(MersenneTwister(4), mg; isolates = ["p1"], moreinfo = true)
    # psn_edgelists labels the fill
    @test "fill" in psn_edgelists(a).bin
    @test splitwanted(7) == (4, 3) && splitwanted(40) == (20, 20)
    @test_throws ArgumentError samplevillage(MersenneTwister(1), mg, cons; isolates = ["nobody"])
end

@testset "outer bin" begin
    mg = shortvillage(22)
    dmax = 2
    spec = (desired = ((3, 3), (3, 3)), dvals = (1, 2))
    for v in (1, 26)
        b = SPN._vertexbins(mg, v, dmax; outer = true)
        dist = gdistances(mg, v)
        far = [u for u in vertices(mg) if u != v && dist[u] > dmax]
        near = [u for u in vertices(mg) if u != v && dist[u] <= dmax]
        nm(u) = get_prop(mg, u, :name)
        brute = Dict(r => Set{Tuple{String,String}}() for r in (true, false))
        for u in far, w in vcat(near, far)
            (w in far && w <= u) && continue
            push!(brute[has_edge(mg, u, w)], pair(nm(u), nm(w)))
        end
        @test Set(pair.(first.(b[0, true]), last.(b[0, true]))) == brute[true]
        @test Set(pair.(first.(b[0, false]), last.(b[0, false]))) == brute[false]
        # without outer the bins are unchanged
        @test SPN._vertexbins(mg, v, dmax) == Dict(k => x for (k, x) in b if k[1] != 0)
    end

    lists = samplenetwork(MersenneTwister(5), mg; spec..., outer = (2, 2), moreinfo = true)
    for (k, (ps, deg, rl)) in lists
        @test length(ps) <= 16 && allunique(ps)
        # an outer pair has a member beyond dmax (or unreachable)
        v = parse(Int, k[2:end]); dist = gdistances(mg, v)
        for (p, d) in zip(ps, deg)
            m = max(dist[parse(Int, p[1][2:end])], dist[parse(Int, p[2][2:end])])
            @test d == 0 ? m > dmax : m == d
        end
    end
    @test "outer" in psn_edgelists(lists).bin
    # off by default: the same stream as before
    @test samplenetwork(MersenneTwister(5), mg; spec...) ==
          samplenetwork(MersenneTwister(5), mg; spec..., outer = nothing)
    # with the outer bin, every eligible pair has pi > 0
    ip = inclusionprobs(mg; spec..., outer = (2, 2))
    n = nv(mg)
    @test all(nrow(ip[ip.perceiver .== "p$v", :]) == binomial(n - 1, 2) for v in (1, 9, 31))
    @test all(ip.pi .> 0)
    @test_throws ArgumentError samplenetwork(mg; spec..., outer = (1,))
    @test_throws ArgumentError samplebins(SPN._vertexbins(mg, 1, 2); spec..., outer = (1, 1))
end

@testset "inclusionprobs with fill, isolates and the outer bin (Monte Carlo)" begin
    # empirical inclusion frequency over R draws of samplevillage = pi
    function mccheck(mg, consents, kw; isolates = String[], R = 20_000, tol = 0.02)
        ip = inclusionprobs(mg, consents; kw..., isolates, randomfill = true)
        hits = Dict((r.perceiver, r.from, r.to) => 0 for r in eachrow(ip))
        rng = MersenneTwister(77)
        for _ in 1:R
            for (k, ps) in samplevillage(rng, mg, consents; kw..., isolates, randomfill = true)
                for (a, b) in ps
                    hits[k, min(a, b), max(a, b)] += 1    # KeyError if pi = 0
                end
            end
        end
        z = [abs(hits[r.perceiver, r.from, r.to] / R - r.pi) for r in eachrow(ip)]
        @test maximum(z) < tol
        # expected list lengths
        for k in unique(ip.perceiver)
            @test sum(ip.pi[ip.perceiver .== k]) ≈
                  sum(hits[x] for x in keys(hits) if x[1] == k) / R atol = 0.05
        end
        return ip
    end

    mg = shortvillage(23)
    nms = [get_prop(mg, i, :name) for i in vertices(mg)]
    cons = Dict(nm => (i % 6 == 0 ? 1 : i % 13 == 0 ? 3 : 2) for (i, nm) in enumerate(nms))
    cons["iso1"] = 2; cons["iso2"] = 3
    small = (desired = ((3, 3), (3, 3)), dvals = (1, 2))   # short lists, small pools

    # the fill alone, both perceiver rules
    for excl in (false, true)
        ip = mccheck(mg, cons, (; small..., excludeperceiver = excl))
        @test any(ip.bin .== "none")                          # pairs reachable only by the fill
        @test excl == !any(r.perceiver in (r.from, r.to) for r in eachrow(ip))
    end
    # the deployed design, with isolates (one in the graph) and consents
    ip = mccheck(mg, cons, (; deployed_design...); isolates = ["iso1", "iso2", "p5"])
    @test all(ip.bin[ip.perceiver .== "iso1"] .== "none")
    # the outer bin (it absorbs shortfalls, so the fill rarely runs), no consents
    mccheck(mg, nothing, (; small..., outer = (1, 1)))
    # carryover off with the fill
    mccheck(mg, cons, (; small..., carryover = false))

    # the per-vertex form agrees with the stacked form
    kw = (; deployed_design..., randomfill = true)
    one = inclusionprobs(mg, 27, cons; kw...)
    all_ = inclusionprobs(mg, cons; kw...)
    sub = all_[all_.perceiver .== "p27", Not(:perceiver)]
    @test nrow(sub) > 0 && any(sub.bin .== "none")
    @test sort(sub, [:from, :to]) == sort(one, [:from, :to])
    # randomfill = false is the stratified stage, unchanged
    @test inclusionprobs(mg, cons) == inclusionprobs(mg, cons; randomfill = false, isolates = String[])
end
