abstract type NumericalSamplingStrategy <: SamplingStrategy{Number} end

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
    maxbig = bitlogsize(maxbits)
    rand((-maxbig):maxbig)
end

# TODO mechanism to allow for multiple inputs of different types
nextinput(rs::BituniformSampling) = tuple(map(i -> nextinput(rs, i), eachindex(rs.types))...)
nextinput(rs::BituniformSampling, dim::Integer) = bitlogsample(rand(types(rs)[dim]))
nextinput(::BituniformSampling, type::Type) = bitlogsample(type)