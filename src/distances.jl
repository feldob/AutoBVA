# OBS current limitation is that inputs must be numbers, and that the output distance (after Strlendist) automatically falls back to geometrical euclidean, direct line distance.

struct Strlendist <: StringMetric end

# TODO somewhat redundant here below, both needed?
evaluate(::Strlendist, t₁::AbstractString, t₂::AbstractString) = Distances.evaluate(Euclidean(), length(t₁), length(t₂))

function (dist::Strlendist)(s1, s2)
    (s1 === missing) | (s2 === missing) && return missing
    return abs(length(s2) - length(s1))
end

abstract type RelationalMetric end

function evaluate(r::RelationalMetric, ::AbstractString, ::AbstractString, ::Tuple{Vararg{<:Real}}, ::Tuple{Vararg{<:Real}})
    throws(ArgumentError("method implementation for type $r missing and must be implemented."))
end

struct ProgramDerivative <: RelationalMetric end


#TODO difference metric here is just assumed to be strlendist
function evaluate(pd::ProgramDerivative, o₁::AbstractString, o₂::AbstractString, i₁::Tuple{Vararg{<:String}}, i₂::Tuple{Vararg{<:String}})
    evaluate(pd, o₁, o₂, length.(i₁), length.(i₂))
end

# Default input distance: Euclidean
# Default output distance: Strlendist
# OBS that entering the same input twice results in a divide by zero in the input space (Inf or NaN as result, depending on output consistency).
function evaluate(::ProgramDerivative, o₁::AbstractString, o₂::AbstractString, i₁::Tuple{Vararg{<:Real}}, i₂::Tuple{Vararg{<:Real}})
    # "$o₁, $o₂, $i₁, $i₂, $(typeof(i₁)), $(typeof(i₂))" |> println

    # euclidean
    #idist = Distances.evaluate(Euclidean(), i₁, i₂) # produced problems "complex numbers"
    idist = sum((i₁ .- i₂) .^ 2)
    idist = idist < 0 ? 0.0 : sqrt(idist)
    #"$idist" |> println

    odist = evaluate(Strlendist(), o₁, o₂)
    #"$odist" |> println

    return odist / idist
end