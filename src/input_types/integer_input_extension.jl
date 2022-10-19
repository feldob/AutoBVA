abstract type NumericalSamplingStrategy <: SamplingStrategy{Number} end
types(ss::NumericalSamplingStrategy) = ss.types

ensuretypesupport(T::DataType, cts::Bool) = cts ? compatibletypes(T) : Set([makeconcrete(T)])

nextinput(rs::NumericalSamplingStrategy) = rand(rand(types(rs)))

struct UniformSampling <: NumericalSamplingStrategy
    types::Set{DataType}

    UniformSampling(type::Type{<:Number}, cts=false) = new(ensuretypesupport(type, cts))
end

struct BituniformSampling <: NumericalSamplingStrategy
    types::Set{DataType}

    BituniformSampling(type::Type{<:Number}, cts=false) = new(ensuretypesupport(type, cts))
end

maxbits(::Type{T}) where T <: Unsigned = sizeof(T) * 8
maxbits(::Type{T}) where T <: Signed = sizeof(T) * 8 - 1

bitlogsample(t::Type{<:Integer}) = rand(t) >> rand(0:maxbits(t))
bitlogsample(::Type{Bool}) = rand(Bool)
function bitlogsample(::Type{BigInt}, maxbits = 540)
    maxbig = bitlogsize(maxbits)
    rand((-maxbig):maxbig)
end