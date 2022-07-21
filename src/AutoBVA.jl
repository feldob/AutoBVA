module AutoBVA

    using Distances, # distances.jl: common metric abstractions
        InteractiveUtils # cts.jl: subtypes and meta stuff

    # cts.jl
    export compatibletypes, concretetypes, cts_supportedtypes,

    # sampling.jl
        SamplingStrategy, UniformSampling, nextinput,

    # distances.jl
        Strlendist, ProgramDerivative, evaluate,

    # sut.jl
        SUT, name, argtypes, call,
        myidentity_sut, tuple_sut # example suts

    include("cts.jl")
    include("sampling.jl")
    include("distances.jl")
    include("sut.jl")

end # module