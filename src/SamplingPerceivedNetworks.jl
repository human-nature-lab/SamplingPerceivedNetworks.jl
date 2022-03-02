# SamplingPerceivedNetworks.jl

module SamplingPerceivedNetworks

    using Graphs, MetaGraphs
    using CairoMakie, GraphMakie, NetworkLayout, Colors, ColorSchemes
    import StatsBase.sample

    include("orbit.jl")
    include("plotting.jl")
    include("context.jl")
    include("sampling.jl")
    include("whole_network.jl")

    export
        vertexorbit, vertexorbit_d,
        context_graph,
        plot_orbit_d, plot_context,
        samplingbins, samplebins, samplenetwork
end
