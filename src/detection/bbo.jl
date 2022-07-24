#==============================================================#
# --------------BBO OPTIMIZATION PROBLEM DEFINITION ------------
#==============================================================#
# the detection is not a global optimization problem, but uses the framework offered by bbo faking the optimization process while recording boundary candidates according to the chosen detection strategy (see below).

# defaults for Integers only
mutationoperators(::Type{<:Integer}) = (+,-)
mutationoperators(sut::SUT) = map(mutationoperators, argtypes(sut))
mutationoperators(sut::SUT, dim::Integer) = mutationoperators(sut)[dim]

struct SUTProblem{FS} <: OptimizationProblem{FS}
    sut::SUT
    mos::Tuple{Vararg{Tuple{Vararg{Function}}}}

    SUTProblem(name::String, sut::Function) = SUTProblem(SUT(name, sut))
    function SUTProblem(sut::SUT, mos=mutationoperators(sut))
        @assert reduce(*, map(t -> t <: Real, argtypes(sut))) "BBO currently only supports real valued inputs."
        return new{typeof(fake_fitness_scheme())}(sut, mos)
    end
end

sut(p::SUTProblem) = p.sut
dims(p::SUTProblem) = length(argtypes(sut(p)))

fake_fitness_scheme() = ScalarFitnessScheme{false}()
BlackBoxOptim.search_space(::SUTProblem) = ContinuousRectSearchSpace([0.0], [1.0]) # fake
BlackBoxOptim.fitness_scheme(::SUTProblem) = fake_fitness_scheme() # fake
BlackBoxOptim.fitness(input::AbstractVector{<:Real}, ::SUTProblem) = 0.0 # fake

#==============================================================#
# ------------------------DETECTION ALGORITHMS -----------------
#==============================================================#

# -----------------Framework Glue -----------------

abstract type BoundaryCandidateDetector <: SteppingOptimizer end

popsize(::BoundaryCandidateDetector) = 1 # fake to comply with bbo
samplingstrategy(bcd::BoundaryCandidateDetector) = bcd.ss
τ(bcd::BoundaryCandidateDetector) = 0 # threshold for neighborhood significance
metric(::BoundaryCandidateDetector) = ProgramDerivative() # here, PD is a fixed default, open up for change in future

function init_bcd(problem::SUTProblem, params)
    params[:MaxNumStepsWithoutFuncEvals] = 0
    params[:MaxStepsWithoutProgress] = 0
    params[:PopulationSize] = 1
    evaluator = BlackBoxOptim.ProblemEvaluator(problem)
    ss = get(params, :SamplingStrategy, UniformSampling)(sut(problem)) # as default, use uniform sampling suitable 
    BlackBoxOptim.fitness(collect(nextinput(ss)), evaluator) # initial fake result to not break BBO.
    bca = BoundaryCandidateArchive(sut(problem))
    return ss, evaluator, bca
end

problem(bcd::BoundaryCandidateDetector) = bcd.problem
sut(bcd::BoundaryCandidateDetector) = sut(problem(bcd))
archive(bcd::BoundaryCandidateDetector) = bcd.bca

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

function significant_neighborhood_boundariness(bcd::BoundaryCandidateDetector, i::Tuple)
    o = call(sut(bcd), i)
    oₛ = string(o)

    for dim in 1:dims(problem(bcd))
        for mo in mutationoperators(sut(problem(bcd)), dim)
            if edgecase(mo, i[dim])
                continue
            end

            iₙ = singlechangecopy(i, dim, mo(i[dim], one(1)))
            oₙ = call(sut(bcd), iₙ)
            if evaluate(metric(bcd), oₛ, string(oₙ), i, iₙ) > τ(bcd) # significant boundariness test
                return true
            end
        end
    end

    return false
end

# -------------------LNS -----------------
struct LocalNeighborSearch <: BoundaryCandidateDetector
    problem::SUTProblem
    ss::SamplingStrategy
    evaluator::BlackBoxOptim.Evaluator
    bca::BoundaryCandidateArchive

    LocalNeighborSearch(problem::SUTProblem; opts...) = LocalNeighborSearch(problem, ParamsDict(opts))
    function LocalNeighborSearch(problem::SUTProblem, params)
        ss, evaluator, bca = init_bcd(problem, params)
        return new(problem, ss, evaluator, bca)
    end
end

function BlackBoxOptim.step!(lns::LocalNeighborSearch)
    i = nextinput(samplingstrategy(lns))

    if significant_neighborhood_boundariness(lns, i)
        add(archive(lns), i)
    end

    return lns
end


# ----------------BCS -------------------------
struct BoundaryCrossingSearch <: BoundaryCandidateDetector
    problem::SUTProblem
    ss::SamplingStrategy
    evaluator::BlackBoxOptim.Evaluator
    bca::BoundaryCandidateArchive

    BoundaryCrossingSearch(problem::SUTProblem; opts...) = BoundaryCrossingSearch(problem, ParamsDict(opts))
    function BoundaryCrossingSearch(problem::SUTProblem, params)
        ss, evaluator, bca = init_bcd(problem, params)
        return new(problem, ss, evaluator, bca)
    end
end

function BlackBoxOptim.step!(bcs::BoundaryCrossingSearch)
    # TODO
    return bcs
end

# ------------CONNECT ALGS WITH BBO -----------

function alg_instantiator(BCD::Type{<:BoundaryCandidateDetector}, problem::SUTProblem, options::Parameters)
    opts = chain(BlackBoxOptim.EMPTY_PARAMS, options)
    return BCD(problem, opts)
end

lns(p::SUTProblem, opts::Parameters = EMPTY_PARAMS) = alg_instantiator(LocalNeighborSearch, p, opts)
bcs(p::SUTProblem, opts::Parameters = EMPTY_PARAMS) = alg_instantiator(BoundaryCrossingSearch, p, opts)

function add_autobva_mo_methods_to_bbo()
    BlackBoxOptim.add_mo_method_to_bbo(:lns, lns)
    BlackBoxOptim.add_mo_method_to_bbo(:bcs, bcs)
end

add_autobva_mo_methods_to_bbo()