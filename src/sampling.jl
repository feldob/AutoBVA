abstract type SamplingStrategy{T} end

include("input_types/integer_input_extension.jl")

nextinput(sss::Vector{SamplingStrategy}) = tuple(nextinput.(sss)...)