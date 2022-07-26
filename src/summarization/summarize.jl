#==============================================================#
# --------------Boundary Candidate Summarization Method---------
#==============================================================#

struct ClusteringFeature
    id::String
    ffunctions::Vector{Function}
    function ClusteringFeature(id, metric, ffunctions::Vector{Function})
        ffunctions_mapped = map(f -> (x) -> f(metric,x), ffunctions)
        return new(id, ffunctions_mapped)
    end
end

id(cf::ClusteringFeature) = cf.id
nfeatures(cf::ClusteringFeature) = length(cf.ffunctions)
call(cf::ClusteringFeature, df::DataFrame) = map(f -> f(df), cf.ffunctions)

withindistance(m, df) = [ m(df[i, "output"], df[i, "n_output"]) for i in 1:nrow(df) ]

function uniqueness(distmetric, vector::AbstractVector{<:AbstractString})
    uniq_pw = pairwise(distmetric, vector)
    sum(uniq_pw, dims = 2)
end

function uniqueness(distmetric, v::AbstractString, vs::AbstractVector{<:AbstractString})
    return sum(x -> distmetric(x,v), vs)
end

sl_d = ClusteringFeature("sl_d", Strlendist(), Function[(m,df) -> withindistance(m, df)])     # index 1, SELECTED
jc_d = ClusteringFeature("jc_d",StringDistances.Overlap(2), Function[(m,df) -> withindistance(m, df)]) # index 2, SELECTED
lv_d = ClusteringFeature("lv_d",NMD(2), Function[(m,df) -> withindistance(m, df)])

sl_u = ClusteringFeature("sl_u", Strlendist(), Function[(m,df) -> uniqueness(m, df[:,"output"]), (m,df) -> uniqueness(m, df[:,"n_output"])])
jc_u = ClusteringFeature("jc_u", StringDistances.Overlap(2), Function[(m,df) -> uniqueness(m, df[:,"output"]), (m,df) -> uniqueness(m, df[:,"n_output"])]) # index 5, SELECTED
lv_u = ClusteringFeature("lv_u", NMD(2), Function[(m,df) -> uniqueness(m, df[:,"output"]), (m,df) -> uniqueness(m, df[:,"n_output"])])

clusteringfeatures = [ sl_d, jc_d, lv_d, sl_u, jc_u, lv_u ]

@enum BoundaryType vv ve ee

abstract type BoundaryCandidateSummarization end

loadsummary(path) = CSV.read(path, DataFrame; type = String)

struct ClusteringSummarization <: BoundaryCandidateSummarization
    expdir::AbstractString
    df::DataFrame
    sutname::AbstractString
    features::AbstractVector{<:ClusteringFeature}
    rounds::Integer
    bts::Tuple{Vararg{BoundaryType}}
    usecache::Bool
    highdiv::Bool

    function ClusteringSummarization(expdir, df, sutname, features, rounds=1, bts=instances(BoundaryType), usecache=false, highdiv=false)
        new(expdir, df, sutname, features, rounds, bts, usecache, highdiv)
    end

    function ClusteringSummarization(expdir, sutname, features, rounds=1, bts=instances(BoundaryType), usecache=false, highdiv=false)
        expfiles = filter(x -> startswith(x, "$(sutname)_") && endswith(x, "_all.csv") && length(collect(eachmatch(r"_", x))) == 1, readdir(setup.expdir))
        @assert length(expfiles) == 1 "There shall be exactly one file for clustering."

        df = loadsummary(joinpath(expdir, expfiles[1]))

        ClusteringSummarization(expdir, df, sutname, features, rounds, bts, usecache, highdiv)
    end
end

function clusterings(setup::ClusteringSummarization,
                        bt::BoundaryType)
    #TODO implement clustering!
    return setup.df
end

function summarize(setup::ClusteringSummarization)
    result_path = setup.expdir * "_clusterings"
    mkpath(result_path)
    df_c = vcat(map(bt -> clusterings(setup, bt), setup.bts)...)
    CSV.write(joinpath(result_path, setup.sutname * "_clustering.csv"), df_c)
end
