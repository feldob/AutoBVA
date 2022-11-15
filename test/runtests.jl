using Test
using AutoBVA
using DataFrames
using BlackBoxOptim
using Dates # for datesut
using Printf # bytecount sut
using CSV # summarize i/o
using Combinatorics # summarize

# Date (for some tests)
datesut = SUT((year::Int64, month::Int64, day::Int64) -> Date(year, month, day), "Julia Date")

# bytecount
function byte_count_bug(bytes::Integer, si::Bool = true)
    unit = si ? 1000 : 1024
    if bytes < unit
        return string(bytes) * "B"
    end
    exp = floor(Int, log(bytes) / log(unit))
    pre = (si ? "kMGTPE" : "KMGTPE")[exp] * (si ? "" : "i")
    @sprintf("%.1f %sB", bytes / (unit^exp), pre)
end

bcsut = SUT((x::Integer) -> byte_count_bug(x), "bytecount (buggy)")

include("summarize_test.jl")
include("cts_test.jl")
include("sampling_test.jl")
include("distances_test.jl")
include("sut_test.jl")
include("boundarycandidates_test.jl")
include("nextboundary_test.jl")
include("bbo_test.jl")