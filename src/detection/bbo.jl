#==============================================================#
# --------------BBO OPTIMIZATION PROBLEM DEFINITION ------------
#==============================================================#
# the detection is not a global optimization problem, but uses the framework offered by bbo faking the optimization process while recording boundary candidates according to the chosen detection strategy (see below).

struct SUTProblem{FS, C} <: OptimizationProblem{FS}
    sut::SUT

    function SUTProblem(sut::SUT)
        @assert reduce(*, map(t -> t <: Real, argtypes(sut))) "BBO currently only supports real valued inputs."
        return new{typeof(fake_fitness_scheme()), Float64}(sut)
    end
end

sut(problem::SUTProblem) = problem.sut

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

archive(bcd::BoundaryCandidateDetector) = bcd.bca

function BlackBoxOptim.step!(lns::LocalNeighborSearch)
    input = nextinput(samplingstrategy(lns))

    add(archive(lns), input)
    
    return lns
end


# ----------------BCS -------------------------



# ------------CONNECT ALGS WITH BBO -----------

function lns(problem::SUTProblem, options::Parameters = EMPTY_PARAMS)
    opts = chain(BlackBoxOptim.EMPTY_PARAMS, options)
    return LocalNeighborSearch(problem, opts)
end

BlackBoxOptim.add_mo_method_to_bbo(:lns, lns)