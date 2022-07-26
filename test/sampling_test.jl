@testset "Sampling abstract types" begin
    @test UniformSampling((Integer,)) isa SamplingStrategy
    @test (Set([Int128]),) == types(UniformSampling((Integer,)))
    @test (Set([Int128]),Set([UInt128])) == types(UniformSampling((Integer,Unsigned)))
end

@testset "UniformSampling tests" begin

    @test UniformSampling((Int64,)) isa SamplingStrategy
    @test UniformSampling((Int64, Signed, Bool)) isa SamplingStrategy

    @test_throws AssertionError UniformSampling(()) # at least one arg
    @test_throws AssertionError UniformSampling((String,)) # types must be compatible with the outline

    foreach(_ -> (@test nextinput(UniformSampling((Int64,))) isa Tuple{Int64}), 1:5)
    foreach(_ -> (@test nextinput(UniformSampling((Int64,Bool))) isa Tuple{Int64, Bool}), 1:5)

    # FIXME union types not supported yet
    # foreach(_ -> (@test nextinput(UniformSampling((Union{Int8, Bool},))) isa Union{Int8, Bool}), 1:10)
end

@testset "BituniformSampling tests with cts" begin

    @test BituniformSampling((Int64,), true) isa SamplingStrategy

    @test_throws AssertionError BituniformSampling((), true) # at least one arg

    for _ in 1:10
        x = nextinput(BituniformSampling((Int64,Bool), true))
        foreach(i -> (@test typeof(x[i]) ∈ compatibletypes((Int64,Bool)[i])), eachindex(x))
    end
end