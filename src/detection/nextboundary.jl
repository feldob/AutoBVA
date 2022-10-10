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
        return v # OBS! default back to original value, which should be taken as a sign of failure
    end
end

nextby_half(x::I) where I <: Integer = max(one(I), div(abs(x), 2))
isatomic(x::Integer, T::DataType) = x ≤ one(T)
isatomic(x::String, ::DataType) = isempty(x)

@enum Direction begin
    forward
    backward
end

function oversteps(current, beta, mutationoperator::Function)
    comp = mutationoperator == (+) ? (>) : (<)
    return !isnothing(beta) && comp(current, beta)
end

abstract type StopCriterion end

check(::StopCriterion, o₁::SUTOutput, o₂::SUTOutput, i₁::Tuple, i₂::Tuple)::Bool = throws("implementation required")

struct OutputTypeDiff <: StopCriterion end

check(::OutputTypeDiff, o₁::SUTOutput, o₂::SUTOutput, i₁::Tuple, i₂::Tuple) = datatype(o₁) != datatype(o₂)

struct OutputDelta <: StopCriterion
    τ::Real
    rm::RelationalMetric

    OutputDelta(τ=0, rm=ProgramDerivative()) = new(τ, rm) # FIXME have the \tau be set
end

τ(od::OutputDelta) = od.τ
metric(od::OutputDelta) = od.rm
check(od::OutputDelta, o₁::SUTOutput, o₂::SUTOutput, i₁::Tuple, i₂::Tuple) = evaluate(metric(od),string(value(o₁)), string(value(o₂)), i₁, i₂) > τ(od)

abstract type BoundarySearch end

struct NextBoundary <: BoundarySearch
    sut::SUT
    sc::StopCriterion

    NextBoundary(sut, sc=OutputTypeDiff()) = new(sut,sc)
end

sut(bs::BoundarySearch) = bs.sut
stopcriterion(bs::BoundarySearch) = bs.sc
call(bs::BoundarySearch, i::Tuple) = call(sut(bs), i)

#TODO not sufficiently generic - must work for all operators and datatypes
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
                direction::Direction=forward,   # describes only orientation in search, not "reduction/extension"
                beta=nothing)

    "a: $counter" |> println
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
        stopcondition = check(stopcriterion(bs), call(bs, current), call(bs, incumbent), current, incumbent) # version reducing sut calls, see end of file

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


# TODO have a smart mechanism that decides the alg to use, depending on the time it takes to run the sut commonly. (This could go as far as different ranges of the space use different alg impls.)

#==============================================================================#
# ------recursive implementatin for slow suts, where outputs are cached---------
#==============================================================================#
# Candidate is an abstraction that ensures the execution of the sut is done exactly once per active input (OBS no cache applied, so if the same input comes up at a later point in time again, it gets evaluated again).
# to activate, simply uncomment below ->

# mutable struct Candidate
#     sut::SUT
#     input::Tuple
#     output

#     Candidate(sut, input) = new(sut, input)
# end

# sut(c::Candidate) = c.sut
# input(c::Candidate) = c.input
# function output(c::Candidate)
#     if isdefined(c, :output)
#         return c.output
#     else
#         return c.output = call(sut(c), input(c))
#     end
# end

# function next_recursive(bs::NextBoundary,
#                 start::Candidate,
#                 current::Candidate,
#                 dim::Int64,
#                 operand::Function,
#                 by=nextby_half(input(current)[dim]),
#                 counter::Int64=1,
#                 direction::Direction=forward,
#                 beta=nothing)

#     incumbent = Candidate(sut(bs), next(input(current), dim, operand, by))
#     if oversteps(input(incumbent)[dim], beta, operand)
#         incumbent = Candidate(sut(bs), singlechangecopy(input(incumbent), dim, beta))
#         by = abs(-(input(current)[dim], beta))
#     end

#     #"REC($counter) current: $current, incumbent: $incumbent" |> println
#     if counter > 120 # TODO change back to 120 if not working!!!
#         #"circuit breaker: $(incumbent[dim])." |> println
#         return start
#     else
#         outofbounds = !withinbounds(input(current)[dim], input(incumbent)[dim], operand)
#         stopcondition = check(stopcriterion(bs), output(current), output(incumbent), input(current), input(incumbent))

#         if outofbounds || stopcondition
#             atom = isatomic(by, typeof(input(start)[dim]))
#             if stopcondition && atom # recursive stop criterion, TODO generalize for other datatypes, e.g. floats (where the min distance may be lower than "one")
#                 #"successfully converged!: $(incumbent[dim])" |> println
#                 return incumbent
#             end

#             if outofbounds
#                 #"out of bounds: $(incumbent[dim])." |> println
#                 if atom
#                     #"out of bounds fail." |> println
#                     return start
#                 end
#             end

#             beta = input(incumbent)[dim] # cutting point for forward search
#             return next_recursive(bs, start, current, dim, operand, nextby_half(by), counter + 1, backward, beta) # backtracking
#         else # forward below
#             by_next = direction == backward ? nextby_half(by) : 2 * by
#             return next_recursive(bs, start, incumbent, dim, operand, by_next, counter + 1, forward, beta)
#         end
#     end
# end

# function next(bs::NextBoundary, i::Tuple, dim::Int64, operand::Function)
#     start = Candidate(sut(bs), i)
#     final = next_recursive(bs, start, start, dim, operand)
#     return input(final)
# end