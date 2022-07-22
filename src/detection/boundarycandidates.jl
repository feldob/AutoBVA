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

#function add(bca::BoundaryCandidateArchive{T}, i::T) where T
function add(bca::BoundaryCandidateArchive, i::Tuple) # TODO check how to ensure compatibility here, but still allow for other types.
    iₛ = string(i)
    if haskey(bca.candidates, iₛ)
        bca.candidates[iₛ] += 1
    else
        bca.candidates[iₛ] = 1
    end
end