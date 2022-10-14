abstract type StringSamplingStrategy <: SamplingStrategy{String} end

struct ABCStringSampling <: StringSamplingStrategy end

nextinput(::ABCStringSampling) = ((rand() < .01 ? "a" : "") * randstring('b':'b', rand(0:10)),)

struct StringShorteningOperator <: ReductionOperator{String} end
function apply(::StringShorteningOperator, datum::String, times::Integer=1) #TODO have a more efficient implementation that gets smarter
    for _ in 1:times
        datum = startswith(datum, "a") ? datum[2:end] : datum
    end
    return datum
end
rightdirection(::StringShorteningOperator, current::String, next::String) = length(current) ≥ length(next)
withinbounds(so::StringShorteningOperator, current::String, next::String) = rightdirection(so, current, next) && rightdirection(so, next, "") # TODO here we decide we cut at string length 20
edgecase(::ReductionOperator{String}, value::String) = value == ""

struct StringExtensionOperator <: ExtensionOperator{String} end
function apply(::StringExtensionOperator, datum::String, times::Integer=1)
    for _ in 1:times
        datum = startswith(datum, "a") ? datum * "a" : datum
    end
    return datum
end
rightdirection(::StringExtensionOperator, current::String, next::String) = length(current) ≤ length(next)
withinbounds(so::StringExtensionOperator, current::String, next::String) = rightdirection(so, current, next) && length(next) < 20 # TODO here we decide we cut at string length 20
edgecase(::ExtensionOperator{String}, value::String) = false

BasicStringMutationOperators = [ StringShorteningOperator(), StringExtensionOperator() ]
