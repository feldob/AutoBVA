#==============================================================#
# ------Mutation Operator Tooling for Numbers-------------------
#==============================================================#

# datatype specific that must be implemented
# ------------------------------------------
# isatomic(t::MyType)
#-------------------------------------------
isatomic(x::Integer) = x ≤ 1
isatomic(x::String) = isempty(x)

# mutation operator specific that must be implemented
# ------------------------------------------
# struct MyTypeReductionOperator <: ReductionOperator{MyType} end
# struct MyTypeExtensionOperator <: ExtensionOperator{MyType} end
# rightdirection(::MyTypeReductionOperator, currentvalue::MyType, nextvalue::MyType)
# rightdirection(::MyTypeExtensionOperator, currentvalue::MyType, nextvalue::MyType)
# edgecase(::ReductionOperator{MyType}, value::MyType)                               is extreme minimal value
# edgecase(::ExtensionOperator{MyType}, value::MyType)                               is extreme maximal value
# withinbounds(ro::ReductionOperator{MyType}, current::MyType, next::MyType)
# withinbounds(eo::ExtensionOperator{MyType}, current::MyType, next::MyType)
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
apply(::IntAdditionOperator, datum::Bool, times::Integer=1) where {I <: Integer} =  Bool(times % 2) ? !datum : datum
apply(::IntSubtractionOperator, datum::Bool, times::Integer=1) where {I <: Integer} =  Bool(times % 2) ? !datum : datum

IntMutationOperators = [ IntSubtractionOperator(), IntAdditionOperator() ]

# -----------------------------------------------
# withinbounds(eo::ExtensionOperator{MyType}, current::MyType, next::MyType)

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
