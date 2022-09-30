# helpfunctions

argnames(f::Function) = string.(Base.method_argnames(methods(f).ms[1])[2:end])

# A SUT is a wrapper for a software under test, in principle any function. It requires at least one argument, and a system wide unique function identifier or be a lambda (no identifier overloading for disambiguity).
# Futher, this implementation is limited in that it does not allow for Tuple to be an input (call would have to be refactored for that).
struct SUT{T}
    name::String
    sut::Function
    argtypes::Tuple{Vararg{Type}}
    argnames::Vector{String}

    function SUT(name::String, sut::Function)
        @assert methods(sut).ms |> length == 1 "The SUT is not unique, make sure to use a unique identifier or use a lambda to pass it on."
        @assert methods(sut).ms[1].nargs > 1 "The SUT has no arguments, and is therefore not suitable for explorative analysis."
        @assert !haskey(SUTS, name) "You must use a unique SUT name, the name '$name' is already taken by a registered SUT."

        #TODO add an impl that creates a lambda expression (clone) for the sut, so that each sut is unique.
        argtypes = (methods(sut).ms[1].sig.parameters[2:end]...,)
        this = new{Tuple{argtypes...}}(name, sut, argtypes, argnames(sut))
        SUTS[name] = this
        return this
    end
end

global const SUTS = Dict{String, SUT}()

name(sut::SUT) = sut.name
sut(s::SUT) = s.sut
numargs(s::SUT)=length(argtypes(s))
argtypes(s::SUT) = s.argtypes
argnames(s::SUT) = s.argnames

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

myidentity_sut = SUT("identity", (x::Int8) -> x)
tuple_sut = SUT("tuple", (x::Tuple) -> 0.0)