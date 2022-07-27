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

@enum ValidityGroup VV VE EE

abstract type BoundaryCandidateSummarization end

loadsummary(path) = CSV.read(path, DataFrame; type = String)

struct ClusteringSummarization <: BoundaryCandidateSummarization
    df::DataFrame
    sutname::AbstractString
    features::AbstractVector{<:ClusteringFeature}
    rounds::Integer
    expdir::AbstractString
    VGs::Tuple{Vararg{ValidityGroup}}
    usecache::Bool
    highdiv::Bool

    #TODO make sure to convert df into "String only".
    function ClusteringSummarization(df::DataFrame, sutname, features, rounds=1, expdir="", VGs=instances(ValidityGroup), usecache=false, highdiv=false)
        new(df, sutname, features, rounds, expdir, VGs, usecache, highdiv)
    end

    function ClusteringSummarization(expdir::AbstractString, sutname, features, rounds=1, VGs=instances(ValidityGroup), usecache=false, highdiv=false)
        ClusteringSummarization(loadsummary(expdir), sutname, features, rounds, expdir, VGs, usecache, highdiv)
    end
end

abstract type BoundarySummary end

struct ClusteringSummary <: BoundarySummary
    summaries::Dict{ValidityGroup,DataFrame}

    ClusteringSummary() = new(Dict{ValidityGroup,DataFrame}())
end

add(cs::ClusteringSummary, VG::ValidityGroup, summary::DataFrame) = cs.summaries[VG] = summary
asone(cs::ClusteringSummary) = vcat(collect(values(cs.summaries))...)

filtervaliditygroup(::Type{Val{VV}}, df::DataFrame) = subset(df, :outputtype => ByRow(==("valid")), :n_outputtype => ByRow(==("valid")))
filtervaliditygroup(::Type{Val{VE}}, df::DataFrame) = subset(df, :outputtype => ByRow(==("valid")), :n_outputtype => ByRow(==("error")))
filtervaliditygroup(::Type{Val{EE}}, df::DataFrame) = subset(df, :outputtype => ByRow(==("error")), :n_outputtype => ByRow(==("error")))

# reduces the frame to the shortest inputs that produce the same outputs (this might not be appropriate for all SUTS, but here it allows to reduce complexity).
function reduce_to_shortest_entries_per_same_output(df::DataFrame)

    args = names(df)[1:findfirst(x -> x == "output", names(df))-1]

    local df_new

    gdfs = groupby(df, [:output, :n_output])

    "number of BC's after reduction (engage): $(length(gdfs))" |> println

    for gdf in gdfs
        df_sub = DataFrame(gdf)

        df_sub.mini = map(r -> sum(length.(Tuple(r[args]))), eachrow(df_sub))
        sort!(df_sub, :mini)
        select!(df_sub, Not(:mini))

        representative = df_sub[1:1,:]
        if @isdefined(df_new)
            df_new = representative
        else
            df_new = vcat(df_new, representative)
        end
    end

    return df_new
end

function single_clustering(df_o::DataFrame, df::DataFrame, VG::ValidityGroup)
    df_n = DataFrame(df)
    df_n.clustering = fill!(Vector{String}(undef, nrow(df_n)), string(VG))
    df_n.cluster = 1:nrow(df_n)  # individual clusters

    if nrow(df_o) != nrow(df) # reduced, so classify all!
        df_o.clustering = fill!(Vector{String}(undef, nrow(df_o)), string(VG))

        d = Dict{String, Int}()
        foreach(r -> d[string(r[:output], r[:n_output])] = r.cluster, eachrow(df_n))
        df_o.cluster = map(r -> d[string(r[:output], r[:n_output])], eachrow(df_o))

        df_n = df_o
    end

    @assert nrow(df_n) == nrow(df_o)

    return df_n
end

empty_clustering(df::DataFrame) = hcat(df, DataFrame(clustering = String[], cluster = Int[]))

function clustering(setup::ClusteringSummarization,
                        VG::ValidityGroup)
    df_s = filtervaliditygroup(Val{VG}, setup.df)

    "number of BC's for $VG: $(nrow(df_s))" |> println

    if isempty(df_s)
        return empty_clustering(df_s) # extend by columns to match other clusterings
    end

    df_f = nrow(df_s) > MAX_CLUSTERING_SIZE ? reduce_to_shortest_entries_per_same_output(df_s) : df_s # if too many risks out of memory -> reduce outputs

    return nrow(df_f) < 10 ? single_clustering(df_s, df_f, VG) : empty_clustering(DataFrame(Dict(map(x -> (x, String[]), names(df_s))))) # regular_clustering(setup.sutname, df_s, df_f, VG, setup.features, setup.rounds, setup.usecache, setup.highdiv) # if too small for clustering, return indiv values as cluster
end

function summarize(setup::ClusteringSummarization, tofile::Bool=false)
    summary = ClusteringSummary()
    for VG in setup.VGs
        singlesummary = clustering(setup, VG)
        add(summary, VG, singlesummary)
    end

    if tofile
        result_path = setup.expdir * "_clusterings"
        mkpath(result_path)
        CSV.write(joinpath(result_path, setup.sutname * "_clustering.csv"), asone(summary))
    end

    return summary
end
