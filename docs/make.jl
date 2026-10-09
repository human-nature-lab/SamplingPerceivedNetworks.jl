using Documenter, SamplingPerceivedNetworks

DocMeta.setdocmeta!(
    SamplingPerceivedNetworks, :DocTestSetup,
    :(using SamplingPerceivedNetworks); recursive = true
)

makedocs(;
    sitename = "SamplingPerceivedNetworks.jl",
    modules = [SamplingPerceivedNetworks],
    authors = "Eric Martin Feltham",
    format = Documenter.HTML(;
        canonical = "https://human-nature-lab.github.io/SamplingPerceivedNetworks.jl",
        edit_link = "main",
    ),
    pages = [
        "Home" => "index.md",
        "Guide" => [
            "The sampling procedure" => "procedure.md",
            "Worked example" => "example.md",
            "Consents" => "consents.md",
            "Inclusion probabilities" => "inclusion.md",
        ],
        "API reference" => "api.md",
    ],
    warnonly = [:missing_docs],
)

deploydocs(;
    repo = "github.com/human-nature-lab/SamplingPerceivedNetworks.jl",
    devbranch = "main",
)
