next(v::Bool, operand::Function, by::Bool=true) = !v
function next(v::I, operand::Function, by::I=one(I))::I where {I<:Integer}
    return operand(v, by)
end

function next(t::T, dim::Int64, operand::Function, by=one(typeof(t[dim])))::T where {T <: Tuple}
    v = next(t[dim], operand, by)
    return singlechangecopy(t, dim, v)
end

function withinbounds(current::X, incumbent::Real, operand::Function) where {X <: Real}
    if operand == (+)
        return current < incumbent && incumbent < typemax(X)
    else # operand == (-)
        return current > incumbent && incumbent > typemin(X)
    end
end

# OBS abstract function to be implemented
function next(v, operand::Function)
    throws(DomainError(typeof(v), "next method not implemented"))
end

function next(v::I, operand::Function, by::Integer)::I where {I<:Integer}
    try
        return next(v, operand, I(by))
    catch
        return v # OBS! default back to original value, which should be taken as a signal of failure
    end
end

abstract type BoundarySearch end

struct NextBoundary <: BoundarySearch
    sut::SUT
end

function next(nb::NextBoundary, i::Tuple, dim::Int, operator::Function)
    return i
end

next(v::Bool, operand::Function, by::Bool=true) = !v
function next(v::I, operand::Function, by::I=one(I))::I where {I<:Integer}
    return operand(v, by)
end