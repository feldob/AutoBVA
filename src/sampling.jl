abstract type SamplingStrategy{T} end

abstract type NumericalSamplingStrategy <: SamplingStrategy{Number} end

types(ss::SamplingStrategy) = ss.types

function ensuretypesupport(types::Tuple{Vararg{Type}}, T::Type, cts::Bool)
    @assert length(types) > 0 "For sampling, a number of argument types has to be defined."
    @assert .&(.<:(types, T)...) "All entered types (here $(types)) must be supported by the sampler."

    return cts ? compatibletypes(types) : map(t -> Set([t]), types)
end

struct UniformSampling <: NumericalSamplingStrategy
    types::Tuple{Vararg{Set{Type}}}

    UniformSampling(types, cts=false) = new(ensuretypesupport(types, Real, cts))
end

nextinput(rs::UniformSampling) = rand.(rand.(types(rs)))
nextinput(rs::UniformSampling, dim::Int64) = rand(rand(types(rs)[dim]))

struct BituniformSampling <: NumericalSamplingStrategy
    types::Tuple{Vararg{Set{Type}}}

    BituniformSampling(types, cts=false) = new(ensuretypesupport(types, Real, cts))
end

maxbits(::Type{T}) where T <: Unsigned = sizeof(T) * 8
maxbits(::Type{T}) where T <: Signed = sizeof(T) * 8 - 1

bitlogsample(t::Type{<:Integer}) = rand(t) >> rand(0:maxbits(t))
bitlogsample(::Type{Bool}) = rand(Bool)
function bitlogsample(::Type{BigInt}, maxbits = 540)
    maxbig = big"2"^rand(1:maxbits)
    rand((-maxbig):maxbig)
end

nextinput(rs::BituniformSampling) = tuple(map(i -> nextinput(rs, i), eachindex(rs.types))...)
nextinput(rs::BituniformSampling, dim::Integer) = bitlogsample(rand(types(rs)[dim]))
nextinput(::BituniformSampling, type::Type) = bitlogsample(type)