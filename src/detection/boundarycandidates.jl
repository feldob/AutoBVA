#==============================================================#
# ------Boundary Candidate Tooling for storage and I/O----------
#==============================================================#

struct BoundaryCandidateArchive{T}
    sut::SUT{T}
    candidates::Dict{String, Integer}

    BoundaryCandidateArchive(sut::SUT{T}, candidates=Dict{String, Integer}()) where T = new{T}(sut, candidates)
end

sut(bca::BoundaryCandidateArchive) = bca.sut
Base.size(bca::BoundaryCandidateArchive) = length(bca.candidates)

exists(bca::BoundaryCandidateArchive, iₛ::AbstractString) = haskey(bca.candidates, iₛ)

add_known(bca::BoundaryCandidateArchive, iₛ::AbstractString) = bca.candidates[iₛ] += 1
add_new(bca::BoundaryCandidateArchive, iₛ::AbstractString) = bca.candidates[iₛ] = 1

function add(bca::BoundaryCandidateArchive, iₛ::AbstractString)
    if exists(bca, iₛ)
        add_known(bca, iₛ)
    else
        add_new(bca, iₛ)
    end
end

add(bca::BoundaryCandidateArchive, i::Tuple) = add(bca, string(i))