module AutoBVA

    using Distances

    # distances.jl
    export Strlendist, ProgramDerivative, evaluate,

    # sut.jl
    SUT, name, argtypes, call,
    myidentity_sut, tuple_sut # example suts

    include("distances.jl")
    include("sut.jl")

end # module