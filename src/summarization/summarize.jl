#==============================================================#
# --------------Boundary Candidate Summarization Method---------
#==============================================================#

include("features.jl")

@enum ValidityGroup VV VE EE

abstract type BoundaryCandidateSummarization end

loadsummary(path) = CSV.read(path, DataFrame; type = String)

abstract type BoundaryResult end

struct BoundarySummary{R<:BoundaryResult}
    results::Dict{ValidityGroup,R}

    BoundarySummary{R}() where R = new{R}(Dict{ValidityGroup,R}())
end

result(cs::BoundarySummary, VG::ValidityGroup) = cs.results[VG]
add(cs::BoundarySummary, VG::ValidityGroup, result::BoundaryResult) = cs.results[VG] = result
asone(cs::BoundarySummary) = vcat(collect(map(r -> r.df, values(cs.results)))...)

filtervaliditygroup(::Type{Val{VV}}, df::DataFrame) = subset(df, :outputtype => ByRow(==("valid")), :n_outputtype => ByRow(==("valid")))
filtervaliditygroup(::Type{Val{VE}}, df::DataFrame) = subset(df, :outputtype => ByRow(==("valid")), :n_outputtype => ByRow(==("error")))
filtervaliditygroup(::Type{Val{EE}}, df::DataFrame) = subset(df, :outputtype => ByRow(==("error")), :n_outputtype => ByRow(==("error")))

# reduces the frame to the shortest inputs that produce the same outputs (this might not be appropriate for all SUTS, but here it allows to reduce complexity).
function reduce_to_shortest_entries_per_same_output(df::DataFrame)

    args = names(df)[1:findfirst(x -> x == "output", names(df))-1]

    gdfs = groupby(df, [:output, :n_output])

    "number of BC's after reduction (engage): $(length(gdfs))" |> println

    local df_new
    for gdf in gdfs
        df_sub = DataFrame(gdf)

        df_sub.mini = map(r -> sum(length.(Tuple(r[args]))), eachrow(df_sub))
        sort!(df_sub, :mini)
        select!(df_sub, Not(:mini))

        representative = df_sub[1:1,:]
        if @isdefined(df_new)
            df_new = vcat(df_new, representative)
        else
            df_new = representative
        end
    end

    return df_new
end

include("clustering.jl")