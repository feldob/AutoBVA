#==============================================================#
# ------Boundary Candidate Tooling for storage and I/O----------
#==============================================================#

# TODO the default now is to set a limit at 20_000, that might be changed in future
struct BoundaryCandidateArchive{T}
    sut::SUT{T}
    candidates::Dict{String, Integer}
    max_entries::Integer

    function BoundaryCandidateArchive(sut::SUT{T}, candidates=Dict{String, Integer}(), max_entries = 20_000) where T
        new{T}(sut, candidates, max_entries)
    end
end

sut(bca::BoundaryCandidateArchive) = bca.sut
max_entries(bca::BoundaryCandidateArchive) = bca.max_entries
Base.size(bca::BoundaryCandidateArchive) = length(bca.candidates)

exists(bca::BoundaryCandidateArchive, iₛ::AbstractString) = haskey(bca.candidates, iₛ)

add_known(bca::BoundaryCandidateArchive, iₛ::AbstractString) = bca.candidates[iₛ] += 1
function add_new(bca::BoundaryCandidateArchive, iₛ::AbstractString)
    if size(bca) < max_entries(bca)
        bca.candidates[iₛ] = 1
    end # ignore those that come in after. For smart search that learns this should be adapted to consider new entries and remove rate existing ones.
end

function add(bca::BoundaryCandidateArchive, iₛ::AbstractString)
    if exists(bca, iₛ)
        add_known(bca, iₛ)
    else
        add_new(bca, iₛ)
    end
end

add(bca::BoundaryCandidateArchive, i::Tuple) = add(bca, string(i))