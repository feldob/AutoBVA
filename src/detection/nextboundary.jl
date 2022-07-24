abstract type BoundarySearch end

struct NextBoundary <: BoundarySearch
    sut::SUT
end

function next(nb::NextBoundary, i::Tuple, dim::Int, operator::Function)
    return i
end