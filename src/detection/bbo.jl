#==============================================================#
# --------------BBO OPTIMIZATION PROBLEM DEFINITION ------------
#==============================================================#
# the detection is not a global optimization problem, but uses the framework offered by bbo faking the optimization process while recording boundary candidates according to the chosen detection strategy (see below).
# TODO refactor to have the mutationoperators not be a (set of) functions, but an object with forward and backward action

struct SUTProblem{FS} <: OptimizationProblem{FS}
    sut::SUT
    mos::Vector{Vector{MutationOperator}}

    SUTProblem(name::String, sut::Function, mos) = SUTProblem(SUT(sut, name), mos)
    function SUTProblem(sut::SUT, mos)
        @assert numargs(sut) == length(mos) "The mutation operator args must match the sut in number and type."
        # TODO add check that types in mos and sut match
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
    ss::Vector{SamplingStrategy}
    evaluator::BlackBoxOptim.Evaluator
    bca::BoundaryCandidateArchive

    BoundaryCandidateDetectionSetup(problem::SUTProblem; opts...) = BoundaryCandidateDetectionSetup(problem, ParamsDict(opts))
    function BoundaryCandidateDetectionSetup(problem::SUTProblem, params)
        params[:MaxNumStepsWithoutFuncEvals] = 0
        params[:MaxStepsWithoutProgress] = 0
        params[:PopulationSize] = 1
        params[:TraceMode] = :silent
        evaluator = BlackBoxOptim.ProblemEvaluator(problem)
        ss = get(params, :SamplingStrategy)
        BlackBoxOptim.fitness([0.0], evaluator) # initial fake result to not break BBO.
        bca = BoundaryCandidateArchive(sut(problem))
        return new(problem, ss, evaluator, bca)
    end
end

mutationoperators(bcds::BoundaryCandidateDetectionSetup) = bcds.problem.mos

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
mutationoperators(bcd::BoundaryCandidateDetector) = mutationoperators(bcd.setup)

# TODO adjust to forward the mutation operator too
function significant_neighborhood_boundariness(bcd::BoundaryCandidateDetector, i::Tuple)
    return significant_neighborhood_boundariness(sut(bcd), metric(bcd), mutationoperators(bcd), τ(bcd), i)
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
        #"exists $i" |> println
        add_known(archive(bcs), iₛ)
    elseif significant_neighborhood_boundariness(bcs, i)
        #"significant_neighbor $i" |> println
        add_new(archive(bcs), iₛ)
    else
        #"search $i" |> println
        dim = rand(1:numargs(sut(bcs)))
        mo = rand(mutationoperators(bcs)[dim])
        inext = apply(nb(bcs), mo, i, dim)
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

# copied over from BBO as a hook to ensure the algs are added!
# from : https://github.com/robertfeldt/BlackBoxOptim.jl/blob/c5fb5815de43f6ad9991efdd473138c4d0a459c9/src/bboptimize.jl#L91
function BlackBoxOptim.bboptimize(functionOrProblem::SUTProblem, parameters::Parameters = BlackBoxOptim.EMPTY_PARAMS; kwargs...)
    if :lns ∉ BlackBoxOptim.SingleObjectiveMethodNames
        add_autobva_so_methods_to_bbo()
    end
    optctrl = BlackBoxOptim.bbsetup(functionOrProblem, parameters; kwargs...)
    BlackBoxOptim.run!(optctrl)
end