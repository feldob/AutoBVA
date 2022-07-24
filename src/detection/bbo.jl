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
dims(p::SUTProblem) = numargs(sut(p))

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

function significant_neighborhood_boundariness(bcd::BoundaryCandidateDetector, i::Tuple)
    return significant_neighborhood_boundariness(sut(bcd), metric(bcd), τ(bcd), i)
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