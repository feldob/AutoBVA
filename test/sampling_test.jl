@testset "Sampling abstract types" begin
    @test UniformSampling(Integer) isa SamplingStrategy
    @test Set([Int128]) == types(UniformSampling(Integer))
    @test Set([UInt128]) == types(UniformSampling(Unsigned))
end

@testset "UniformSampling tests" begin

    @test UniformSampling(Int64) isa SamplingStrategy

    @test_throws MethodError UniformSampling(String) # types must be compatible with the outline

    foreach(_ -> (@test nextinput(UniformSampling(Int64)) isa Int64), 1:5)
    foreach(_ -> (@test nextinput(UniformSampling(Bool)) isa Bool), 1:5)

    # FIXME union types not supported yet
    # foreach(_ -> (@test nextinput(UniformSampling(Union{Int8, Bool})) isa Union{Int8, Bool}), 1:10)
end

@testset "BituniformSampling tests with cts" begin

    @test BituniformSampling(Int64, true) isa SamplingStrategy

    for _ in 1:10
        x = nextinput(BituniformSampling(Int64, true))
        @test typeof(x) ∈ compatibletypes(Int64)
    end
end