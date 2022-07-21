abstract type SamplingStrategy{T} end

types(ss::SamplingStrategy) = ss.types

function ensuretypesupport(ss::SamplingStrategy{T}) where T
    @assert length(types(ss)) > 0 "For sampling, a number of argument types has to be defined."
    @assert .&(.<:(types(ss), T)...) "All entered types must be supported by the sampler."
    return ss
end

struct UniformSampling <: SamplingStrategy{Number}
    types::Tuple{Vararg{DataType}}

    UniformSampling(types) = ensuretypesupport(new(types))
end

nextinput(rs::UniformSampling) = rand.(types(rs))
nextinput(rs::UniformSampling, dim::Int64) = rand(types(rs)[dim])