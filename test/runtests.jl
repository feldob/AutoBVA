using Test
using AutoBVA
using DataFrames
using BlackBoxOptim

AutoBVA.add_autobva_mo_methods_to_bbo()

include("cts_test.jl")
include("sampling_test.jl")
include("distances_test.jl")
include("sut_test.jl")
include("boundarycandidates_test.jl")
include("bbo_test.jl")