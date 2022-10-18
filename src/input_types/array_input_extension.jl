struct SomeArraySampling <: SamplingStrategy{Vector} end

nextinput(::SomeArraySampling) = rand(rand(1:10))

struct ArrayShorteningOperator <: ReductionOperator{Vector} end
function apply(::ArrayShorteningOperator, datum::Vector, times::Integer=1)
    for _ in 1:times
        if isempty(datum)
            return
        end
        
        datum = datum[1:end-1]
    end
    return datum
end
rightdirection(::ArrayShorteningOperator, current::Vector, next::Vector) = length(current) ≥ length(next)
withinbounds(so::ArrayShorteningOperator, current::Vector, next::Vector) = rightdirection(so, current, next) && rightdirection(so, next, [])
edgecase(::ReductionOperator{Vector}, value::Vector) = isempty(value)

struct ArrayExtensionOperator <: ExtensionOperator{Vector} end
function apply(::ArrayExtensionOperator, datum::Vector, times::Integer=1)
    for _ in 1:times
        datum = push!(datum, rand())
    end
    return datum
end
rightdirection(::ArrayExtensionOperator, current::Vector, next::Vector) = length(current) ≤ length(next)
withinbounds(so::ArrayExtensionOperator, current::Vector, next::Vector) = rightdirection(so, current, next) && length(next) < 20 # TODO here we decide we cut at string length 20
edgecase(::ExtensionOperator{Vector}, value::Vector) = length(value) > 15

BasicArrayMutationOperators = [ ArrayShorteningOperator(), ArrayExtensionOperator() ]
