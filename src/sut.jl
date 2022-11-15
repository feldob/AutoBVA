# helpfunctions

argnames(f::Function) = string.(Base.method_argnames(methods(f).ms[1])[2:end])

# A SUT is a wrapper for a software under test, in principle any function. It requires at least one argument, and a system wide unique function identifier or be a lambda (no identifier overloading for disambiguity).
# Futher, this implementation is limited in that it does not allow for Tuple to be an input (call would have to be refactored for that).
struct SUT{T}
    name::String
    sut::Function
    argtypes::Tuple{Vararg{Type}}

    function SUT(sut::Function, name::String=string(nameof(sut)), method::Method=methods(sut).ms[1])
        argtypes = (method.sig.parameters[2:end]...,)
        return new{Tuple{argtypes...}}(name, sut, argtypes)
    end

    function SUT(sut::Function, name::String=string(nameof(sut)), argtypes::Tuple = (methods(sut).ms[1].sig.parameters[2:end]...,))
        return new{Tuple{argtypes...}}(name, sut, argtypes)
    end
end

name(sut::SUT) = sut.name
sut(s::SUT) = s.sut
numargs(s::SUT)=length(argtypes(s))
argtypes(s::SUT) = s.argtypes
argnames(s::SUT) = argnames(sut(s))

@enum OutputType valid error

mutable struct SUTOutput
    type::OutputType
    value
    stringified::AbstractString

    SUTOutput(type, value) = new(type, value)
end

value(o::SUTOutput) = o.value
outputtype(o::SUTOutput) = o.type
datatype(o::SUTOutput) = typeof(value(o))
function stringified(s::SUTOutput)
    if isdefined(s, :stringified)
        return s.stringified
    else
        return s.stringified = string(value(s))
    end
end

# calling sut with inputs and fold regular and error outputs into regular output stream (currently, for simplicity)
function call(s::SUT{T}, input::T) where {T <: Tuple}
    try
        result = sut(s)(input...)
        return SUTOutput(valid::OutputType, result)
    catch err
        return SUTOutput(error::OutputType, err)
    end
end

call(s::SUT, input) = call(s, (input,)) # special case for non-tuple parameters (works only for single values that are passed)

# If input not same types as sut, make them fit. It is the users responsibility that the types match and that a convert implementation exists.
call(sut::SUT, input::Tuple) = call(sut, convert.(argtypes(sut), input))

# helper functions
UniformSampling(sut::SUT, cts::Bool=false) = UniformSampling(argtypes(sut), cts)
BituniformSampling(sut::SUT, cts::Bool=false) = BituniformSampling(argtypes(sut), cts)

# section with suts that come along

myidentity_sut = SUT((x::Int8) -> x)
tuple_sut = SUT((x::Tuple) -> 0.0)