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
    all_dfs = vcat(all_dfs...)
    all_dfs.count = parse.(Int64, all_dfs.count)
    gr = groupby(all_dfs, setdiff(names(all_dfs), ["count"]))
    df = combine(gr, :count => sum => :count)

    if wtd
        CSV.write("$(joinpath(expdir, sutname))_$(time)_all.csv", df)
    end
end

function singlefilesummary(expdir::String; wtd=false)
    expfiles = filter(x -> isfile(joinpath(expdir, x)) && endswith(x, ".csv") && x != "results.csv" && !endswith(x, "_all.csv"), readdir(expdir))
    sutnames = unique(map(x -> split(x, "_")[1], expfiles))
    algs = unique(map(x -> split(x, "_")[3], expfiles))
    times = unique(map(x -> split(x, "_")[6], expfiles))
    
    for sutname in sutnames
        for time in times
            for alg in algs
                local df
                expfiles_sut = map(x -> "$(joinpath(expdir, x))", filter(x -> startswith(x, "$(sutname)_") && contains(x, "_$(time)_") && contains(x, "_$(alg)_") && !endswith(x, "_all.csv"), readdir(expdir)))
                for expfile in expfiles_sut
                    res_frame = CSV.read(expfile, DataFrame; types = String)

                    res_frame.count = parse.(Int64, res_frame.count)
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
