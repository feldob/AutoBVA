function apply(mo::MutationOperator, t::T, dim::Int64, times::Integer=1)::T where {T <: Tuple}
    v = t[dim]
    try
        v = apply(mo, v, times)
    catch
        # original value - sign of failure
    end

    return singlechangecopy(t, dim, v)
end

cut_half(x::I) where I <: Integer = max(one(I), div(abs(x), 2))

@enum Direction begin
    forward
    backward
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
#TODO here we directly translate to string, that should be more controlled for the actual type.
#TODO should be possible to take that via the impl of the specific evaluation method instead
# is there only one output, should it not be multiple?
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

oversteps(current, beta, mo::MutationOperator) = !isnothing(beta) && !rightdirection(mo, current, beta)

function next_recursive(bs::NextBoundary,
                input::Tuple,
                current::Tuple,
                dim::Int64,
                mo::MutationOperator,
                times=1,
                counter::Int64=1,
                direction::Direction=forward,
                beta=nothing)

    incumbent = apply(mo, current, dim, times)
    if oversteps(incumbent[dim], beta, mo)
        incumbent = singlechangecopy(incumbent, dim, beta)
        times = abs(-(current[dim], beta))
    end

    #"REC($counter) current: $current, incumbent: $incumbent" |> println
    # TODO it is not so much the direct similarity of the neighboring points, but the fact that the similarity measures signal similarity! strlendist for instance could end up in an endless loop, even for strings of same length.
    if counter > 120 || incumbent == current # TODO when the direction and operator a change is not happening, assuming deterministic mutation, halt as no progress can be made.
        #"circuit breaker: $(incumbent[dim])." |> println
        return input
    else
        outofbounds = !withinbounds(mo, current[dim], incumbent[dim])
        stopcondition = check(stopcriterion(bs), call(bs, current), call(bs, incumbent), current, incumbent)

        if outofbounds || stopcondition
            atom = isatomic(times)
            if stopcondition && atom # recursive stop criterion
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
            return next_recursive(bs, input, current, dim, mo, cut_half(times), counter + 1, backward, beta) # backtracking
        else # forward below
            times_next = direction == backward ? cut_half(times) : 2 * times
            return next_recursive(bs, input, incumbent, dim, mo, times_next, counter + 1, forward, beta)
        end
    end
end

function apply(bs::NextBoundary, mo::MutationOperator, input::Tuple, dim::Int64)
    return next_recursive(bs, input, input, dim, mo)
end