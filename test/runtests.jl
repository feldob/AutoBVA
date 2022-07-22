using Test
using AutoBVA
using DataFrames
using BlackBoxOptim

BlackBoxOptim.add_mo_method_to_bbo(:lns, lns)

include("cts_test.jl")
include("sampling_test.jl")
include("distances_test.jl")
include("sut_test.jl")
include("boundarycandidates_test.jl")
include("bbo_test.jl")