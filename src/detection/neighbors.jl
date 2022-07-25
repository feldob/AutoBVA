#==============================================================#
# ------Mutation Operator Tooling for Numbers-------------------
#==============================================================#

# defaults for Integers only
mutationoperators(::Type{<:Integer}) = (+,-)
mutationoperators(::Integer) = mutationoperators(Integer)
mutationoperators(sut::SUT) = map(mutationoperators, argtypes(sut))
mutationoperators(sut::SUT, dim::Integer) = mutationoperators(sut)[dim]

function singlechangecopy(i::T, index::Int64, value)::T where {T <: Tuple}
    updated = i[1:index-1] # before index
    updated = (updated..., value) # index
    return index ≥ length(i) ? updated :
            (updated..., i[index+1:length(i)]...) # after index
end

function edgecase(operator::Function, value::Integer) # TODO get the comparison below right to ensure none inexact errors
    if operator == (-)
        return value == typemin(value)
    elseif operator == (+)
        return value == typemax(value)
    else
        throw(ArgumentError("The operator is unknown, make sure to handle"))
    end
end

function significant_neighborhood_boundariness(sut::SUT, metric::RelationalMetric, τ::Real, i::Tuple)
    o = call(sut, i)
    oₛ = string(o)

    for dim in 1:numargs(sut)
        for mo in mutationoperators(sut, dim)
            if edgecase(mo, i[dim])
                continue
            end

            iₙ = singlechangecopy(i, dim, mo(i[dim], 1))
            oₙ = call(sut, iₙ)
            if evaluate(metric, oₛ, string(oₙ), i, iₙ) > τ # significant boundariness test
                return true
            end
        end
    end

    return false
end

function significant_neighbor(sut::SUT, metric::RelationalMetric, τ::Real, i::Tuple)
    o = call(sut, i)
    oₛ = string(o)

    local most_significant_neighbor = i
    local significance = 0.0
    local most_significant_output = oₛ

    for dim in 1:numargs(sut)
        for mo in mutationoperators(sut, dim)
            if edgecase(mo, i[dim])
                continue
            end

            iₙ = singlechangecopy(i, dim, mo(i[dim], 1))
            oₙ = call(sut, iₙ)
            significanceₙ = evaluate(metric, oₛ, string(oₙ), i, iₙ)
            if significanceₙ > τ && significanceₙ > significance
                most_significant_neighbor = iₙ
                significance = significanceₙ
                most_significant_output = oₙ
            end
        end
    end

    return most_significant_neighbor, significance, most_significant_output
end
