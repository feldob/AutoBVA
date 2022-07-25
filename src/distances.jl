# OBS current limitation is that inputs must be numbers, and that the output distance (after Strlendist) automatically falls back to geometrical euclidean, direct line distance.

struct Strlendist <: Metric end

evaluate(::Strlendist, t₁::AbstractString, t₂::AbstractString) = Distances.evaluate(Euclidean(), length(t₁), length(t₂))

abstract type RelationalMetric end

function evaluate(r::RelationalMetric, ::AbstractString, ::AbstractString, ::Tuple{Vararg{<:Real}}, ::Tuple{Vararg{<:Real}})
    throws(ArgumentError("method implementation for type $r missing and must be implemented."))
end

struct ProgramDerivative <: RelationalMetric end

ensurenotcomplex(i::Tuple{Vararg{<:Real}}) = i[1] isa Int8 ? [convert(Int64, i[1]),i[2:end]...] : i

# Default input distance: Euclidean
# Default output distance: Strlendist
# OBS that entering the same input twice results in a divide by zero in the input space (Inf or NaN as result, depending on output consistency).
function evaluate(::ProgramDerivative, o₁::AbstractString, o₂::AbstractString, i₁::Tuple{Vararg{<:Real}}, i₂::Tuple{Vararg{<:Real}})
    i₁ = ensurenotcomplex(i₁)
    i₂ = ensurenotcomplex(i₂)
    # "$o₁, $o₂, $i₁, $i₂, $(typeof(i₁)), $(typeof(i₂))" |> println

    idist = Distances.evaluate(Euclidean(), i₁, i₂)
    #"$idist" |> println

    odist = evaluate(Strlendist(), o₁, o₂)
    #"$odist" |> println

    return odist / idist
end