@testset "UniformSampling tests" begin

    @test UniformSampling((Int64,)) isa SamplingStrategy
    @test UniformSampling((Int64, Signed, Bool)) isa SamplingStrategy

    @test_throws AssertionError UniformSampling(()) # at least one arg
    @test_throws AssertionError UniformSampling((String,)) # types must be compatible with the outline

    foreach(_ -> (@test nextinput(UniformSampling((Int64,))) isa Tuple{Int64}), 1:5)
    foreach(_ -> (@test nextinput(UniformSampling((Int64,Bool))) isa Tuple{Int64, Bool}), 1:5)
end

@testset "BituniformSampling tests with cts" begin

    @test BituniformSampling((Int64,), true) isa SamplingStrategy

    @test_throws AssertionError BituniformSampling((), true) # at least one arg

    for _ in 1:10
        x = nextinput(BituniformSampling((Int64,Bool), true))
        foreach(i -> (@test typeof(x[i]) ∈ compatibletypes((Int64,Bool)[i])), eachindex(x))
    end
end