#==============================================================#
# --------------BBO OPTIMIZATION PROBLEM DEFINITION ------------
#==============================================================#
# the detection is not a global optimization problem, but uses the framework offered by bbo faking the optimization process while recording boundary candidates according to the chosen detection strategy (see below).

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

struct BoundaryCandidateDetectionSetup
    problem::SUTProblem
    ss::SamplingStrategy
    evaluator::BlackBoxOptim.Evaluator
    bca::BoundaryCandidateArchive

    BoundaryCandidateDetectionSetup(problem::SUTProblem; opts...) = BoundaryCandidateDetectionSetup(problem, ParamsDict(opts))
    function BoundaryCandidateDetectionSetup(problem::SUTProblem, params)
        params[:MaxNumStepsWithoutFuncEvals] = 0
        params[:MaxStepsWithoutProgress] = 0
        params[:PopulationSize] = 1
        params[:TraceMode] = :silent
        evaluator = BlackBoxOptim.ProblemEvaluator(problem)
        cts = get(params, :CTS, false)
        ss = get(params, :SamplingStrategy, UniformSampling)(sut(problem), cts) # as default, use uniform sampling suitable
        BlackBoxOptim.fitness([0.0], evaluator) # initial fake result to not break BBO.
        bca = BoundaryCandidateArchive(sut(problem))
        return new(problem, ss, evaluator, bca)
    end
end

τ(::BoundaryCandidateDetectionSetup) = 0

abstract type BoundaryCandidateDetector <: SteppingOptimizer end

popsize(::BoundaryCandidateDetector) = 1 # fake to comply with bbo
samplingstrategy(bcd::BoundaryCandidateDetector) = bcd.setup.ss
τ(bcd::BoundaryCandidateDetector) = τ(bcd.setup) # threshold for neighborhood significance
metric(::BoundaryCandidateDetector) = ProgramDerivative() # here, PD is a fixed default, open up for change in future
problem(bcd::BoundaryCandidateDetector) = bcd.setup.problem
sut(bcd::BoundaryCandidateDetector) = sut(problem(bcd))
archive(bcd::BoundaryCandidateDetector) = bcd.setup.bca
BlackBoxOptim.evaluator(bcd::BoundaryCandidateDetector) = bcd.setup.evaluator

function significant_neighborhood_boundariness(bcd::BoundaryCandidateDetector, i::Tuple)
    return significant_neighborhood_boundariness(sut(bcd), metric(bcd), τ(bcd), i)
end

# -------------------LNS -----------------
struct LocalNeighborSearch <: BoundaryCandidateDetector
    setup::BoundaryCandidateDetectionSetup

    LocalNeighborSearch(problem, params) = new(BoundaryCandidateDetectionSetup(problem, params))
end

function BlackBoxOptim.step!(lns::LocalNeighborSearch)
    i = nextinput(samplingstrategy(lns))
    iₛ = string(i)

    if exists(archive(lns), iₛ)
        add_known(archive(lns), iₛ)
    elseif significant_neighborhood_boundariness(lns, i)
        add_new(archive(lns), iₛ)
    end

    return lns
end

# ----------------BCS -------------------------
struct BoundaryCrossingSearch <: BoundaryCandidateDetector
    setup::BoundaryCandidateDetectionSetup
    nb::NextBoundary

    function BoundaryCrossingSearch(problem, params)
        setup = BoundaryCandidateDetectionSetup(problem, params)
        nb = NextBoundary(sut(problem), OutputDelta(τ(setup)))
        return new(setup, nb)
    end
end

nb(bcs::BoundaryCrossingSearch) = bcs.nb

function BlackBoxOptim.step!(bcs::BoundaryCrossingSearch)
    i = nextinput(samplingstrategy(bcs))
    iₛ = string(i)

    if exists(archive(bcs), iₛ)
        add_known(archive(bcs), iₛ)
    elseif significant_neighborhood_boundariness(bcs, i)
        add_new(archive(bcs), iₛ)
    else
        dim = rand(1:numargs(sut(bcs)))
        operator = rand(mutationoperators(i[dim]))
        inext = next(nb(bcs), i, dim, operator)
        if inext != i
            inextₛ = string(inext)
            if exists(archive(bcs), inextₛ)
                add_known(archive(bcs), inextₛ)
            else
                add_new(archive(bcs), inextₛ)
            end
        end
    end

    return bcs
end

# ------------ OUTPUT TYPE-----------------

include("bbo_io.jl")

# ------------CONNECT ALGS WITH BBO -----------

function alg_instantiator(BCD::Type{<:BoundaryCandidateDetector}, problem::SUTProblem, options::Parameters)
    opts = chain(BlackBoxOptim.EMPTY_PARAMS, options)
    return BCD(problem, opts)
end

lns(p::SUTProblem, opts::Parameters = EMPTY_PARAMS) = alg_instantiator(LocalNeighborSearch, p, opts)
bcs(p::SUTProblem, opts::Parameters = EMPTY_PARAMS) = alg_instantiator(BoundaryCrossingSearch, p, opts)

add_so_method_to_bbo(id::Symbol, method::Function) = BlackBoxOptim.SingleObjectiveMethods[id] = method

function add_autobva_so_methods_to_bbo()
    add_so_method_to_bbo(:lns, lns)
    add_so_method_to_bbo(:bcs, bcs)

    push!(BlackBoxOptim.SingleObjectiveMethodNames, :lns)
    push!(BlackBoxOptim.SingleObjectiveMethodNames, :bcs)
    sort!(BlackBoxOptim.SingleObjectiveMethodNames)

    push!(BlackBoxOptim.MethodNames, :lns)
    push!(BlackBoxOptim.MethodNames, :bcs)
    sort!(BlackBoxOptim.MethodNames)
end

# entirely copied from BlackBoxOptim (" last function in default_parameters.jl"), and extended to ensure algs are in place.

function BlackBoxOptim.check_valid!(params::Parameters)
    if :lns ∉ BlackBoxOptim.SingleObjectiveMethodNames
        add_autobva_so_methods_to_bbo()
    end

    # Check that max_time is larger than zero if it has been specified.
    if haskey(params, :MaxTime)
        if !isa(params[:MaxTime], Number) || params[:MaxTime] < 0.0
            throw(ArgumentError("MaxTime parameter must be a non-negative number"))
        elseif params[:MaxTime] > 0.0
            params[:MaxTime] = convert(Float64, params[:MaxTime])
            params[:MaxFuncEvals] = 0
            params[:MaxSteps] = 0
        end
    end

    # Check that a valid number of fevals has been specified. Print warning if higher than 1e8.
    if haskey(params,:MaxFuncEvals)
        if !isa(params[:MaxFuncEvals], Integer) || params[:MaxFuncEvals] < 0.0
            throw(ArgumentError("MaxFuncEvals parameter MUST be a non-negative integer"))
        elseif params[:MaxFuncEvals] > 0.0
            if params[:MaxFuncEvals] >= 1e8
                @warn("Number of allowed function evals is $(params[:MaxFuncEvals]); this can take a LONG time")
            end
            params[:MaxFuncEvals] = convert(Int, params[:MaxFuncEvals])
            params[:MaxSteps] = 0
        end
    end

    # Check that a valid number of iterations has been specified. Print warning if higher than 1e8.
    if haskey(params, :MaxSteps)
        if !isa(params[:MaxSteps], Number) || params[:MaxSteps] < 0.0
            throw(ArgumentError("The number of iterations (MaxSteps) MUST be a non-negative number"))
        elseif params[:MaxSteps] > 0.0
            if params[:MaxSteps] >= 1e8
                @warn("Number of allowed iterations is $(params[:MaxSteps]); this can take a LONG time")
            end
            params[:MaxSteps] = convert(Int, params[:MaxSteps])
        end
    end

    # Check that a valid population size has been given.
    if params[:PopulationSize] < 2
        # FIXME why? What if we use popsize of 1 for optimizers that improve on one solution?
        throw(ArgumentError("The population size MUST be at least 2"))
    end

    method = params[:Method]
    # Check that a valid method has been specified and then set up the optimizer
    if !isa(method, Symbol) || method ∉ BlackBoxOptim.MethodNames
        throw(ArgumentError("The method specified, $(method), is NOT among the valid methods:   $(MethodNames)"))
    end
end