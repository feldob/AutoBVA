#==============================================================#
# ------Mutation Operator Tooling for Numbers-------------------
#==============================================================#

# datatype specific that must be implemented
#-------------------------------------------
isatomic(x::Integer) = x ≤ 1
isatomic(x::String) = isempty(x)

# mutation operator specific that must be implemented
#-------------------------------------------

abstract type MutationOperator{T} end

abstract type ReductionOperator{T} <: MutationOperator{T} end

rightdirection(::ReductionOperator{Integer}, current::Integer, next::Integer) = current > next
edgecase(::ReductionOperator{Integer}, value::Integer) = value == typemin(value)
withinbounds(ro::ReductionOperator{Integer}, current::Integer, next::Integer) = rightdirection(ro, current, next) && rightdirection(ro, next, typemin(current))

abstract type ExtensionOperator{T} <: MutationOperator{T} end

rightdirection(::ExtensionOperator{Integer}, current::Integer, next::Integer) = current < next
edgecase(::ExtensionOperator{Integer}, value::Integer) = value == typemax(value)
withinbounds(eo::ExtensionOperator{Integer}, current::Integer, next::Integer) = rightdirection(eo, current, next) && rightdirection(eo, next, typemax(current))

struct IntSubtractionOperator <: ReductionOperator{Integer} end
apply(::IntSubtractionOperator, datum::I, times::Integer=1) where {I <: Integer} = datum - I(times)

struct IntAdditionOperator <: ExtensionOperator{Integer} end
apply(::IntAdditionOperator, datum::I, times::Integer=1) where {I <: Integer} = datum + I(times)

IntMutationOperators = [ IntSubtractionOperator(), IntAdditionOperator() ]


struct StringShorteningOperator <: ReductionOperator{String} end
function apply(::StringShorteningOperator, datum::String, times::Integer=1) #TODO have a more efficient implementation that gets smarter
    for _ in 1:times
        datum = startswith(datum, "a") ? datum[2:end] : datum
    end
    return datum
end
edgecase(::ReductionOperator{String}, value::String) = value == ""

struct StringExtensionOperator <: ExtensionOperator{String} end
function apply(::StringExtensionOperator, datum::String, times::Integer=1)
    for _ in 1:times
        datum = startswith(datum, "a") ? datum * "a" : datum
    end
    return datum
end
edgecase(::ExtensionOperator{String}, value::String) = false

BasicStringMutationOperators = [ StringShorteningOperator(), StringExtensionOperator() ]

function singlechangecopy(i::T, index::Int64, value)::T where {T <: Tuple}
    updated = i[1:index-1] # before index
    updated = (updated..., value) # index
    return index ≥ length(i) ? updated :
            (updated..., i[index+1:length(i)]...) # after index
end

function significant_neighborhood_boundariness(sut::SUT, metric::RelationalMetric, mos, τ::Real, i::Tuple)
    o = call(sut, i)

    for dim in 1:numargs(sut)
        for mo in mos[dim]
            if edgecase(mo, i[dim])
                continue
            end

            iₙ = singlechangecopy(i, dim, apply(mo, i[dim]))
            oₙ = call(sut, iₙ)
            if evaluate(metric, stringified(o), string(value(oₙ)), i, iₙ) > τ # significant boundariness test
                return true
            end
        end
    end

    return false
end

function significant_neighbor(sut::SUT, mos::Vector{Vector{MutationOperator}}, metric::RelationalMetric, τ::Real, i::Tuple)
    o = call(sut, i)

    local most_significant_neighbor = i
    local significance = 0.0
    local most_significant_output = o

    for dim in 1:numargs(sut)
        for mo in mos[dim]
            if edgecase(mo, i[dim])
                continue
            end

            iₙ = singlechangecopy(i, dim, apply(mo, i[dim]))
            oₙ = call(sut, iₙ)
            significanceₙ = evaluate(metric, stringified(o), stringified(oₙ), i, iₙ)
            if significanceₙ > τ && significanceₙ > significance
                most_significant_neighbor = iₙ
                significance = significanceₙ
                most_significant_output = oₙ
            end
        end
    end

    return most_significant_neighbor, significance, most_significant_output
end
