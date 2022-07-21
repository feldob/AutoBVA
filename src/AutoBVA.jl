module AutoBVA

    using Distances

    # distances.jl
    export Strlendist, ProgramDerivative, evaluate,

    # sut.jl
    SUT, name, argtypes, call,
    myidentity_sut, tuple_sut, # example suts

    # sampling.jl
    SamplingStrategy, UniformSampling, nextinput

    include("distances.jl")
    include("sut.jl")
    include("sampling.jl")

end # module