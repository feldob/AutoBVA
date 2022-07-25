function empty_candidates_table(sut::SUT)

    df = DataFrame()

    inputnames = argnames(sut)
    for (idx, T) in enumerate(argtypes(sut))
        df[!, "$(inputnames[idx])"] = T[]
    end

    return df
end

function results(sut::SUT, a::BoundaryCandidateArchive)
    df = empty_candidates_table(sut)
    df[!, "count"] = Integer[]

    for cand in keys(a.candidates)
        parsedcand = eval(Meta.parse(cand))
        entry = (parsedcand..., a.candidates[cand])
        push!(df, entry)
    end

    return df
end

results(d::BoundaryCandidateDetector) = results(sut(d), d.setup.bca)

mutable struct BCDOutput <: BlackBoxOptim.MethodOutput
    sut::SUT
    metric::RelationalMetric
    candidates::DataFrame
    τ::Real

    BCDOutput(d::BoundaryCandidateDetector)= new(sut(d), metric(d), results(d), τ(d))
end

BlackBoxOptim.MethodOutput(d::BoundaryCandidateDetector) = BCDOutput(d)

candidates(c::BCDOutput) = c.candidates
metric(c::BCDOutput) = c.metric
sut(c::BCDOutput) = c.sut
τ(c::BCDOutput) = c.τ

# ------------------------------------------------------

# OBS passed candidates expected to start with the input args first
function append_outputs!(candidates::DataFrame, sut::SUT)

    output_column = Vector{String}(undef, nrow(candidates))
    type_column = Vector{DataType}(undef, nrow(candidates))

    for (idx, candidate) in enumerate(eachrow(candidates))
        input = candidate[1:numargs(sut)]
        _output = call(sut, tuple(input...))[1]
        output_column[idx] = _output |> string # TODO for multiple output dims in future, this has to be adjusted
        type_column[idx] = _output |> typeof
    end

    candidates[!, :output] = output_column
    candidates[!, :type] = type_column

    return candidates
end

# OBS assumes that count is part of the inputs
# OBS so far, only including the first and generic naming of "metric"
function append_significant_neighbor!(candidates::DataFrame, sut::SUT, metric::RelationalMetric, τ::Real; output::Bool=false)

    metric_column = Vector{Float64}(undef, nrow(candidates))
    n_output = Vector{String}(undef, nrow(candidates))
    n_type = Vector{DataType}(undef, nrow(candidates))

    n_args_df = DataFrame()
    for (idx, arg) in enumerate(argnames(sut))
        n_args_df[!, "n_$arg"] = argtypes(sut)[idx][]
    end

    for (idx, candidate) in enumerate(eachrow(candidates))
        input = candidate[1:numargs(sut)]
        iₙ, metric_column[idx], oₙ = significant_neighbor(sut, metric, τ, tuple(input...))

        n_output[idx] = oₙ |> string
        n_type[idx] = oₙ |> typeof

        push!(n_args_df, iₙ)
    end

    candidates[!, "metric"] = metric_column

    if output
        candidates = hcat(candidates, n_args_df)
        candidates[!, :n_output] = n_output
        candidates[!, :n_type] = n_type
    end

    return candidates
end

function ensure_row_order!(df::DataFrame, argnames::Vector{String})

    argnames_n = map(x -> "n_$x", argnames)

    for r in eachrow(df)
        input_left = r[argnames]
        input_right = r[argnames_n]

        tl = tuple(input_left...)
        tr = tuple(input_right...)
        if tl > tr
            df[rownumber(r), argnames_n] = tl
            df[rownumber(r), argnames] = tr

            tmp = r[:output]
            r[:output] = r[:n_output]
            r[:n_output] = tmp

            tmp = r[:type]
            r[:type] = r[:n_type]
            r[:n_type] = tmp
        end
    end
end

# boundaries that are present both ways should be folded into one (two rows reduced to one).
# OBS we assume the df to have a count column, and thus that each row is unique
function merge_twins_for(df::DataFrame, sut::SUT)
    ensure_row_order!(df, argnames(sut))

    fieldnames = setdiff(names(df), ["count"])

    combine(DataFrames.groupby(df, fieldnames), :count => sum, renamecols=false)
end

function rank_unique(df::DataFrame, sut::SUT, metric::RelationalMetric, τ; output::Bool=false, tosort::Bool=true, incl_metric::Bool=false, filter::Bool=true)

    if output
        append_outputs!(df, sut)
    end

    if incl_metric
        df = append_significant_neighbor!(df, sut, metric, τ; output)
        if filter
            filter!(r -> r.metric > 0, df)
        end
    end

    if output
        df = merge_twins_for(df, sut)
    end

    if tosort
        sort!(df, :count, rev = true)
    end

    return df
end

function rank_unique(results::BCDOutput; output::Bool=false, tosort::Bool=true, incl_metric::Bool=false, filter::Bool=true)
    rank_unique(candidates(results), sut(results), metric(results), τ(results); output, tosort, incl_metric, filter)
end