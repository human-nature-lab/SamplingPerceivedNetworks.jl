# plotting.jl 

function plot_radius_d(radᵢ)

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
    nodeout = colors[7] # outside (magenta)
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