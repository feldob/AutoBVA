# helpfunctions

argnames(f::Function) = string.(Base.method_argnames(methods(f).ms[1])[2:end])

# A SUT is a wrapper for a software under test, in principle any function. It requires at least one argument, and a system wide unique function identifier or be a lambda (no identifier overloading for disambiguity).
# Futher, this implementation is limited in that it does not allow for Tuple to be an input (call would have to be refactored for that).
struct SUT{T}
    name::String
    sut::Function
    argtypes::Tuple{Vararg{DataType}}
    argnames::Vector{String}

    function SUT(name::String, sut::Function)
        @assert methods(sut).ms |> length == 1 "The SUT is not unique, make sure to use a unique identifier or use a lambda to pass it on."
        @assert methods(sut).ms[1].nargs > 1 "The SUT has no arguments, and is therefore not suitable for explorative analysis."

        argtypes = (methods(sut).ms[1].sig.parameters[2:end]...,)
        return new{Tuple{argtypes...}}(name, sut, argtypes, argnames(sut))
    end
end

name(sut::SUT) = sut.name
sut(s::SUT) = s.sut
argtypes(s::SUT) = s.argtypes

# calling sut with inputs and fold regular and error outputs into regular output stream (currently, for simplicity)
function call(s::SUT{T}, input::T) where {T <: NTuple}
    try
        result = sut(s)(input...)
        return result
    catch err
        return err
    end
end

call(s::SUT, input) = call(s, (input,)) # special case for non-tuple parameters (works only for single values that are passed)

# If input not same types as sut, make them fit. It is the users responsibility that the types match and that a convert implementation exists.
call(sut::SUT, input::Tuple) = call(sut, convert.(argtypes(sut), input))

# section with suts that come along

myidentity_sut = SUT("identity", (x::Int8) -> x)
tuple_sut = SUT("identity", (x::Tuple) -> nothing)