module AutoBVA

    using Distances, # distances.jl: make metrics defs compatible through standard use (SemiMetric, Metric)
        InteractiveUtils, # cts.jl: subtypes and meta programming support
        DataFrames, # boundarycandidates.jl: everything related to storage and export of candidates
        BlackBoxOptim # bbo.jl: detection algs built on framework

    # cts.jl
    export compatibletypes, concretetypes, cts_supportedtypes,

    # sampling.jl
        SamplingStrategy, UniformSampling, BituniformSampling, nextinput,

    # distances.jl
        Strlendist, RelationalMetric, ProgramDerivative, evaluate,

    # sut.jl
        SUT, name, argtypes, call,
        myidentity_sut, tuple_sut, # example suts

    # boundarycandidates.jl
        BoundaryCandidateArchive, sut, add, size,

    #neighbors.jl

    #nextboundary.jl

    # bbo.jl
        SUTProblem, LocalNeighborSearch, lns, BoundaryCrossingSearch, bcs

    include("cts.jl")
    include("sampling.jl")
    include("distances.jl")
    include("sut.jl")
    include("detection/boundarycandidates.jl")
    include("detection/neighbors.jl")
    include("detection/nextboundary.jl")
    include("detection/bbo.jl")

end # module