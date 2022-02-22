# context.jl

"""
        context_graph(graph, radiusd, vertex; index = true)

Make a new graph object containing the whole graph, with properties
on the edges indicating the perceived and real ties in the social radius of
vertex v.
"""
function context_graph(graph, radiusd, vertex; index = true)

    gcon = deepcopy(graph)

    set_indexing_prop!(gcon, :name)

    for e in edges(gcon)
        set_prop!(gcon, e, :tiestatus, :outside)
        set_prop!(gcon, e, :d, -1)
    end

    for ν in vertices(gcon)
        set_prop!(gcon, ν, :nodestatus, :outside)
        set_prop!(gcon, ν, :noded, -1)
    end

    for e in edges(radiusd)

        snme = get_prop(radiusd, src(e), :name)
        dnme = get_prop(radiusd, dst(e), :name)

        srce = gcon[snme, :name]
        dest = gcon[dnme, :name]

        if !get_prop(radiusd, e, :real)
            fk = :fake
            newe = Edge(srce, dest)
            add_edge!(gcon, newe)
        elseif get_prop(radiusd, e, :real)
            fk = :real
            if has_edge(graph, srce, dest)
                newe = Edge(srce, dest)
            elseif has_edge(graph, dest, srce)
                newe = Edge(dest, srce)
            else error("missing edge")
            end
        end

        set_prop!(gcon, newe, :tiestatus, fk)
        set_prop!(gcon, newe, :d, get_prop(radiusd, e, :d))

        # indicate that node is in the social radius
        assign_nodestatus!(gcon, radiusd, e, srce)
        assign_nodestatus!(gcon, radiusd, e, dest)

    end
    
    if index
        vname = get_prop(gcon, vertex, :name)
        v = gcon[vname, :name]
    elseif !index
        v = gcon[vertex, :name]
    end    
    
    set_prop!(gcon, v, :noded, 0)
    set_prop!(gcon, v, :nodestatus, :perceiver)

    return gcon
end

function assign_nodestatus!(gcon, radiusd, e, vertex)
    set_prop!(gcon, vertex, :nodestatus, :inside)
    sprop = get_prop(gcon, vertex, :noded)
    if sprop == -1
        set_prop!(gcon, vertex, :noded, get_prop(radiusd, e, :d))
    elseif (sprop != -1) & (get_prop(radiusd, e, :d) < sprop)
        set_prop!(gcon, vertex, :noded, get_prop(radiusd, e, :d))
    end
   return gcon 
end