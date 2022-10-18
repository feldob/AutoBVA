module AutoBVA

    #-------------Detection----------------------------------#

    using Distances, # distances.jl: make metrics defs compatible through standard use (SemiMetric, Metric)
        InteractiveUtils, # cts.jl: subtypes and meta programming support
        DataFrames, # boundarycandidates.jl: everything related to storage and export of candidates
        Dates, # datesut for testing
        BlackBoxOptim, # bbo.jl: detection algs built on framework
        StringDistances, # summarize.jl + Strlendist <: StringMetric in distances.jl
        Clustering, # summarize.jl
        Statistics, # summarize.jl -> mean
        Combinatorics, # clustering.jl -> combinations
        Random, # randstring
        CSV # summarize.jl, experimentsummary.jl

    # cts.jl
    export compatibletypes,

    # sampling.jl
    SamplingStrategy, nextinput, types,

    # distances.jl
    Strlendist, RelationalMetric, ProgramDerivative, evaluate,

    # sut.jl
    SUT, name, argtypes, call, numargs,
    OutputType, valid, error,
    SUTOutput, datatype, outputtype, value, stringified,
    myidentity_sut, tuple_sut, # example suts

    # boundarycandidates.jl
    BoundaryCandidateArchive, sut, add, size,

    # neighbors.jl

    # nextboundary.jl
    apply, next, NextBoundary, OutputDelta, OutputTypeDiff,

    # bbo.jl
    SUTProblem, LocalNeighborSearch, lns, BoundaryCrossingSearch, bcs, BCDOutput, rank_unique,
    operator, MutationOperator, ReductionOperator, ExtensionOperator,

    #-------------Summarization-------------------------------#
    # summarize.jl
    ClusteringFeature, sl_d, jc_d, lv_d, sl_u, jc_u, lv_u,
    ClusteringSetup, summarize, screen, loadsummary,
    BoundarySummary, ValidityGroup, VV, VE, EE,
    clusterframes, numclusters, silhouettescore, result,
    ALL_BVA_CLUSTERING_FEATURES,

    # experimentsummary.jl
    singlefilesummary,

    # integer_input_extension.jl
    UniformSampling, BituniformSampling,
    IntMutationOperators, IntSubtractionOperator, IntAdditionOperator,

    # string_input_extension.jl
    ABCStringSampling,
    BasicStringMutationOperators,

    # string_input_extension.jl
    SomeArraySampling,
    BasicArrayMutationOperators

    global const MAX_CLUSTERING_SIZE = 1000

    include("cts.jl")
    include("sampling.jl")
    include("distances.jl")
    include("sut.jl")
    include("detection/boundarycandidates.jl")
    include("detection/neighbors.jl")
    include("detection/nextboundary.jl")
    include("detection/bbo.jl")

    include("summarization/experimentsummary.jl")
    include("summarization/summarize.jl")
    include("input_types/integer_input_extension.jl")
    include("input_types/string_input_extension.jl")
    include("input_types/array_input_extension.jl")

end # module