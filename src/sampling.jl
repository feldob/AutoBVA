abstract type SamplingStrategy{T} end

abstract type NumericalSamplingStrategy <: SamplingStrategy{Number} end

types(ss::SamplingStrategy) = ss.types

function ensuretypesupport(types::Tuple{Vararg{DataType}}, T::DataType, cts::Bool)
    @assert length(types) > 0 "For sampling, a number of argument types has to be defined."
    @assert .&(.<:(types, T)...) "All entered types (here $(types)) must be supported by the sampler."

    return cts ? concretetypes(types) : map(t -> Set([t]), types)
end

struct UniformSampling <: NumericalSamplingStrategy
    types::Tuple{Vararg{Set{DataType}}}

    UniformSampling(types, cts=false) = new(ensuretypesupport(types, Number, cts))
end

nextinput(rs::UniformSampling) = rand.(rand.(types(rs)))
nextinput(rs::UniformSampling, dim::Int64) = rand(rand(types(rs)[dim]))