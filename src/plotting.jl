# plotting.jl 

"""
        plot_orbit_d(radᵢ)

Plot the marginal set of ties that exist in the social orbit for a given
vertex, at degree d. radᵢ is the output of vertexorbit_d, the graph of the marginal ties at d. Ties that exist are displayed in green, counterfactual
ties in orange.

cf. vertexorbit_d
"""
function plot_orbit_d(radᵢ)

    rlc = ColorSchemes.:Set2_3[1] # real (green)
    fc = ColorSchemes.:Set2_3[2] # counterfactual (orange)

    ereal = RGB{Float64}[]
    for e in edges(radᵢ)
        push!(ereal, get_prop(radᵢ, e, :real) ? rlc : fc)
    end

    f, ax, _ = graphplot(
        radᵢ,
        # layout = Shell(),
        # node_color = [:black, :red, :red, :red, :black],
        edge_color = ereal
    )

    hidedecorations!(ax); hidespines!(ax);
    ax.aspect = DataAspect();

    return f
end

"""
        plot_context(gcon)

Plot the context graph for a given vertex, and a specified marginal set of ties
that exist at degree d away from the perceiver. gcon is the output of
context_graph(). Ties that exist are displayed in green, counterfactual ties in
orange; those that are outside the social orbit are in grey. The perceiver
node is presented in green, those inside the social orbit are in blue, and
those outside are in pale yellow.

cf. context_graph
"""
function plot_context(gcon)

    colors = ColorSchemes.:Set2_8;

    rlc = colors[1] # real (green)
    fc = colors[2] # counterfactual (orange)
    outside = colors[8] # outside (grey)

    estats = RGB{Float64}[]
    for e in edges(gcon)
        tiestat = get_prop(gcon, e, :tiestatus)
        if tiestat == :outside
            push!(estats, outside)
        elseif tiestat == :fake
            push!(estats, fc)
        elseif tiestat == :real
            push!(estats, rlc)
        end
    end

    nodein = colors[3] # inside (blue)
    nodeout = colors[7] # outside (yellow)
    nodeperc = colors[5] # perceiver (green)

    nstats = RGB{Float64}[]
    for vtx in vertices(gcon)
        nstat = get_prop(gcon, vtx, :nodestatus)
        if nstat == :inside
            push!(nstats, nodein)
        elseif nstat == :outside
            push!(nstats, nodeout)
        elseif nstat == :perceiver
            push!(nstats, nodeperc)
        end
    end
    
    f = Figure(resolution = (1800, 1200))

    ax = Axis(f[1,1])

    # layout = Stress()

    graphplot!(
        ax,
        gcon,
        # layout = layout,
        node_color = nstats,
        edge_color = estats
    )

    hidedecorations!(ax); hidespines!(ax);
    ax.aspect = DataAspect();

    return f 
end