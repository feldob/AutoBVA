# OBS current limitation is that inputs must be numbers, and that the output distance (after Strlendist) automatically falls back to geometrical euclidean, direct line distance.

struct Strlendist <: Metric end

evaluate(::Strlendist, t₁::AbstractString, t₂::AbstractString) = Distances.evaluate(Euclidean(), length(t₁), length(t₂))

struct ProgramDerivative end

# Default input distance: Euclidean
# Default output distance: Strlendist
# OBS that entering the same input twice results in a divide by zero in the input space (Inf or NaN as result, depending on output consistency).
function evaluate(::ProgramDerivative, o₁::AbstractString, o₂::AbstractString, i₁::NTuple{I,<:Number}, i₂::NTuple{I,<:Number}) where I
    idist = Distances.evaluate(Euclidean(), i₁, i₂)
    odist = evaluate(Strlendist(), o₁, o₂)

    return odist / idist
end