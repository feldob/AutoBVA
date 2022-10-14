#TODO currently not supported to combine bitlog and uniform sampling for different dimensions

abstract type SamplingStrategy{T} end
types(ss::SamplingStrategy) = ss.types

function ensuretypesupport(types::Tuple{Vararg{Type}}, T::Type, cts::Bool)
    @assert length(types) > 0 "For sampling, a number of argument types has to be defined."
    @assert .&(.<:(types, T)...) "All entered types (here $(types)) must be supported by the sampler."

    return cts ? compatibletypes(types) : map(t -> Set([t]), makeconcrete.(types))
end

include("input_types/integer_input_extension.jl")