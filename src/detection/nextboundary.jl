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
function next(v, ::Function)
    throws(DomainError(typeof(v), "next method not implemented"))
end

function next(v::I, operand::Function, by::Integer)::I where {I<:Integer}
    try
        return next(v, operand, I(by))
    catch
        return v # OBS! default back to original value, which should be taken as a signal of failure
    end
end

nextby_half(x::I) where I <: Integer = max(one(I), div(abs(x), 2))
isatomic(x::Integer, T::DataType) = x ≤ one(T)

@enum Direction begin
    forward
    backward
end

function oversteps(current, beta, operand::Function)
    comp = operand == (+) ? (>) : (<)
    return !isnothing(beta) && comp(current, beta)
end

abstract type StopCriterion end

check(::StopCriterion, o₁, o₂, i₁::Tuple, i₂::Tuple)::Bool = throws("implementation required")

struct OutputTypeDiff <: StopCriterion end

check(::OutputTypeDiff, o₁, o₂, i₁::Tuple, i₂::Tuple) = typeof(o₁) != typeof(o₂)

struct OutputDelta <: StopCriterion
    τ::Real
    rm::RelationalMetric

    OutputDelta(τ=0, rm=ProgramDerivative()) = new(τ, rm) # FIXME have the \tau be set
end

τ(od::OutputDelta) = od.τ
metric(od::OutputDelta) = od.rm
check(od::OutputDelta, o₁, o₂, i₁::Tuple, i₂::Tuple) = evaluate(metric(od),o₁, o₂, i₁, i₂) > τ(od)

abstract type BoundarySearch end

struct NextBoundary <: BoundarySearch
    sut::SUT
    sc::StopCriterion

    NextBoundary(sut, sc=OutputTypeDiff()) = new(sut,sc)
end

sut(bs::BoundarySearch) = bs.sut
stopcriterion(bs::BoundarySearch) = bs.sc
call(bs::BoundarySearch, i::Tuple) = call(sut(bs), i)

function oversteps(current, beta, operand::Function)
    comp = operand == (+) ? (>) : (<)
    return !isnothing(beta) && comp(current, beta)
end

function next_recursive(bs::NextBoundary,
                input::Tuple,
                current::Tuple,
                dim::Int64,
                operand::Function,
                by=nextby_half(current[dim]),
                counter::Int64=1,
                direction::Direction=forward,
                beta=nothing)

    incumbent = next(current, dim, operand, by)
    if oversteps(incumbent[dim], beta, operand)
        incumbent = singlechangecopy(incumbent, dim, beta)
        by = abs(-(current[dim], beta))
    end

    #"REC($counter) current: $current, incumbent: $incumbent" |> println
    if counter > 120 # TODO change back to 120 if not working!!!
        #"circuit breaker: $(incumbent[dim])." |> println
        return input
    else
        outofbounds = !withinbounds(current[dim], incumbent[dim], operand)
        stopcondition = check(stopcriterion(bs), call(bs, current), call(bs, incumbent), current, incumbent) # TODO dont compute this each time!

        if outofbounds || stopcondition
            atom = isatomic(by, typeof(input[dim]))
            if stopcondition && atom # recursive stop criterion, TODO generalize for other datatypes, e.g. floats (where the min distance may be lower than "one")
                #"successfully converged!: $(incumbent[dim])" |> println
                return incumbent
            end

            if outofbounds
                #"out of bounds: $(incumbent[dim])." |> println
                if atom
                    #"out of bounds fail." |> println
                    return input
                end
            end

            beta = incumbent[dim] # cutting point for forward search
            return next_recursive(bs, input, current, dim, operand, nextby_half(by), counter + 1, backward, beta) # backtracking
        else # forward below
            by_next = direction == backward ? nextby_half(by) : 2 * by
            return next_recursive(bs, input, incumbent, dim, operand, by_next, counter + 1, forward, beta)
        end
    end
end

function next(bs::NextBoundary, input::Tuple, dim::Int64, operand::Function)
    return next_recursive(bs, input, input, dim, operand)
end
