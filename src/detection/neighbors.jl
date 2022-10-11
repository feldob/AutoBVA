#==============================================================#
# ------Mutation Operator Tooling for Numbers-------------------
#==============================================================#

# required for each supported datatype
isatomic(x::Integer, T::DataType) = x ≤ one(T)
isatomic(x::String, ::DataType) = isempty(x)

abstract type MutationOperator{T} end

abstract type ReductionOperator{T} <: MutationOperator{T} end
abstract type ExtensionOperator{T} <: MutationOperator{T} end

rightdirection(::ReductionOperator{Integer}, current::I1, next::I2) where {I1 <: Integer, I2 <: Integer} = current > next
rightdirection(::ExtensionOperator{Integer}, current::I1, next::I2) where {I1 <: Integer, I2 <: Integer} = current < next

struct IntSubtractionOperator <: ReductionOperator{Integer} end
apply(::IntSubtractionOperator, datum::Integer, times::Integer=one(datum)) = datum - times

struct IntAdditionOperator <: ExtensionOperator{Integer} end
apply(::IntAdditionOperator, datum::Integer, times::Integer=one(datum)) = datum + times

IntMutationOperators = [ IntSubtractionOperator(), IntAdditionOperator()]

#cond_shorten(s::String, l::Integer=1) = startswith(s, "a") ? s[2:end] : s
#cond_extend(s::String, l::Integer=1) = startswith(s, "a") ? s * "a" : s

function singlechangecopy(i::T, index::Int64, value)::T where {T <: Tuple}
    updated = i[1:index-1] # before index
    updated = (updated..., value) # index
    return index ≥ length(i) ? updated :
            (updated..., i[index+1:length(i)]...) # after index
end

edgecase(::ReductionOperator, value::String) = value == ""
edgecase(::ExtensionOperator, value::String) = false

edgecase(::ReductionOperator, value::Integer, type=typeof(value)) = value == typemin(type)
edgecase(::ExtensionOperator, value::Integer, type=typeof(value)) = value == typemax(type)

withinbounds(::ReductionOperator, current::Integer, incumbent::Integer) = current > incumbent && incumbent > typemin(current)
withinbounds(::ExtensionOperator, current::Integer, incumbent::Integer) = current < incumbent && incumbent < typemax(current)

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
