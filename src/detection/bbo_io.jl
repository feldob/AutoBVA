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
    outputtype_column = Vector{OutputType}(undef, nrow(candidates))
    datatype_column = Vector{DataType}(undef, nrow(candidates))

    for (idx, candidate) in enumerate(eachrow(candidates))
        input = candidate[1:numargs(sut)]
        output = call(sut, tuple(input...))
        output_column[idx] = stringified(output)
        outputtype_column[idx] = outputtype(output)
        datatype_column[idx] = datatype(output)
    end

    candidates[!, :output] = output_column
    candidates[!, :datatype] = datatype_column
    candidates[!, :outputtype] = outputtype_column

    return candidates
end

# OBS assumes that count is part of the inputs
# OBS so far, only including the first and generic naming of "metric"
function append_significant_neighbor!(candidates::DataFrame, sut::SUT, metric::RelationalMetric, τ::Real; output::Bool=false)

    metric_column = Vector{Float64}(undef, nrow(candidates))
    n_output = Vector{String}(undef, nrow(candidates))
    n_datatype = Vector{DataType}(undef, nrow(candidates))
    n_outputtype = Vector{OutputType}(undef, nrow(candidates))

    n_args_df = DataFrame()
    for (idx, arg) in enumerate(argnames(sut))
        n_args_df[!, "n_$arg"] = argtypes(sut)[idx][]
    end

    for (idx, candidate) in enumerate(eachrow(candidates))
        input = candidate[1:numargs(sut)]
        iₙ, metric_column[idx], oₙ = significant_neighbor(sut, metric, τ, tuple(input...))

        n_output[idx] = string(value(oₙ))
        n_datatype[idx] = datatype(oₙ)
        n_outputtype[idx] = outputtype(oₙ)

        push!(n_args_df, iₙ)
    end

    candidates[!, "metric"] = metric_column

    if output
        candidates = hcat(candidates, n_args_df)
        candidates[!, :n_output] = n_output
        candidates[!, :n_outputtype] = n_outputtype
        candidates[!, :n_datatype] = n_datatype
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

            tmp = r[:outputtype]
            r[:outputtype] = r[:n_outputtype]
            r[:n_outputtype] = tmp

            tmp = r[:datatype]
            r[:datatype] = r[:n_datatype]
            r[:n_datatype] = tmp
        end
    end
end

# avoids : LoadError: InexactError: check_top_bit(UInt64, -1) for unsigned
function avoidInexactErrorWhenGrouping(df::DataFrame, argnames::AbstractVector{<:AbstractString})
    argnames_n = map(x -> "n_$x", argnames)

    for arg in vcat(argnames, argnames_n)
        col = df[!,arg]
        # get all indices where there are unsigned ints
        idxs = findall(x -> x isa Unsigned, col)
        # in-place, substitute them by BigInts.
        col[idxs] = convert.(BigInt, col[idxs])
    end

    return df
end

# boundaries that are present both ways should be folded into one (two rows reduced to one).
# OBS we assume the df to have a count column, and thus that each row is unique

function merge_twins_for(df::DataFrame, sut::SUT)
    ensure_row_order!(df, argnames(sut))

    fieldnames = setdiff(names(df), ["count"])

    # else triggers : LoadError: InexactError: check_top_bit(UInt64, -1) for unsigned
    df = avoidInexactErrorWhenGrouping(df, argnames(sut))

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
        sort!(df, 1:numargs(sut), rev = true)
    end

    return df
end

function rank_unique(results::BCDOutput; output::Bool=false, tosort::Bool=true, incl_metric::Bool=false, filter::Bool=true)
    rank_unique(candidates(results), sut(results), metric(results), τ(results); output, tosort, incl_metric, filter)
end