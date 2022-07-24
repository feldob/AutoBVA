using Test
using AutoBVA
using DataFrames
using BlackBoxOptim
using Dates # for datesut
using Printf # for bytecountsut

AutoBVA.add_autobva_so_methods_to_bbo()

include("cts_test.jl")
include("sampling_test.jl")
include("distances_test.jl")
include("sut_test.jl")
include("boundarycandidates_test.jl")
include("suts.jl")
include("nextboundary_test.jl")
include("bbo_test.jl")