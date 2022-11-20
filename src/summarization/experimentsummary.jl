function summarize_per_sutname(expdir, sutname; wtd=false)
    summary_files = filter(f -> occursin(sutname * r"_\d*_all.csv", f) ,readdir(expdir)) # filenames
    summary_files |> println
    all_dfs = map(f -> CSV.read(joinpath(expdir, f), DataFrame; types = String), summary_files)
    all_dfs = vcat(all_dfs...)
    all_dfs.count = parse.(Int64, all_dfs.count)
    gr = groupby(all_dfs, setdiff(names(all_dfs), ["count"]))
    df = combine(gr, :count => sum => :count)

    if wtd
        CSV.write("$(joinpath(expdir, sutname))_all.csv", df)
    end
end

function summarize_per_sutname_time(expdir, sutname, time; wtd=false)
    summary_files = filter(f -> startswith(f, "$(sutname)_") && endswith(f, "_$(time)_all.csv") ,readdir(expdir)) # filenames
    all_dfs = map(f -> CSV.read(joinpath(expdir, f), DataFrame; types = String), summary_files)
    global all_dfs = vcat(all_dfs...)

    local df
    if isempty(all_dfs)
        df = all_dfs
    else
        all_dfs.count = parse.(Int64, all_dfs.count)
        gr = groupby(all_dfs, setdiff(names(all_dfs), ["count"]))
        df = combine(gr, :count => sum => :count)
    end

    if wtd
        CSV.write("$(joinpath(expdir, sutname))_$(time)_all.csv", df)
    end
end

function reduce_if_noisy!(df::DataFrame, expfile::String)
    if isempty(df)
        return df
    end

    "reduce: $expfile" |> println
    gfs = groupby(df, [:outputtype, :n_outputtype])
    df_new = similar(df, 0)

    for gf in gfs
        gf_interesting = filter(x -> x.count > 1, gf)
        append!(df_new, gf_interesting)

        if nrow(gf_interesting) < 1000
            n_space = 1000 - nrow(gf_interesting)
            gf_boring = filter(x -> x.count == 1, gf)

            if n_space < nrow(gf_boring)
                idxs_boring = sample(1:nrow(gf_boring), n_space, replace = false)
                gf_boring = gf_boring[idxs_boring, :]
            end

            append!(df_new, gf_boring)
        end
    end

    # permanently use
    CSV.write(expfile, df_new)
    CSV.write(expfile * "_ORIGINAL", df)

    return df_new
end

function singlefilesummary(expdir::String; wtd=false)
    expfiles = filter(x -> isfile(joinpath(expdir, x)) && endswith(x, ".csv") && x != "results.csv" && !endswith(x, "clustering.csv") && !endswith(x, "_all.csv"), readdir(expdir))

    sutnames, algs, times = [], [], []
    for expfile in expfiles
        extra_underscores = count(i->(i=='_'), expfile) - 6 # 6 is the expected number
        cut_idxs = [1,3,6] .+ extra_underscores
        splitted = split(expfile, "_")

        push!(sutnames, join(splitted[1:cut_idxs[1]], '_'))
        push!(algs, splitted[cut_idxs[2]])
        push!(times, splitted[cut_idxs[3]])
    end

    sutnames, algs, times = unique(sutnames), unique(algs), unique(times)

    for sutname in sutnames
        for time in times
            for alg in algs
                local df
                expfiles_sut = map(x -> "$(joinpath(expdir, x))", filter(x -> startswith(x, "$(sutname)_") &&  endswith(x, ".csv") && contains(x, "_$(time)_") && contains(x, "_$(alg)_") && !endswith(x, "_all.csv") && !endswith(x, "clustering.csv"), readdir(expdir)))
                for expfile in expfiles_sut
                    res_frame = CSV.read(expfile, DataFrame; types = String)

                    res_frame.count = parse.(Int64, res_frame.count)
                    res_frame = reduce_if_noisy!(res_frame, expfile)

                    if @isdefined(df)
                        df = vcat(df, res_frame)    # append
                    else
                        df = res_frame              # init
                    end

                    if isempty(res_frame)
                        continue
                    end

                    gr = groupby(df, setdiff(names(df), ["count"]))
                    df = combine(gr, :count => sum => :count)
                end

                if !@isdefined(df)
                    continue
                end

                args = names(df)[1:findfirst(x -> x == "output", names(df))-1]

                sort!(df, args)
                if wtd
                    CSV.write("$(joinpath(expdir, sutname))_$(alg)_$(time)_all.csv", df)
                end
            end
            # summmarize per sutname + time
            summarize_per_sutname_time(expdir, sutname, time; wtd)
        end
        
        summarize_per_sutname(expdir, sutname; wtd)
    end
end
