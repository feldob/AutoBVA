@testset "local neighbor search LNS test" begin

    params = ParamsDict(:Method => :lns,
                        :SamplingStrategy => BituniformSampling,
                        :MaxTime => 1)
    res = bboptimize(SUTProblem(myidentity_sut); params...)

    @test true
end

@testset "local neighbor search BCS test" begin

    params = ParamsDict(:Method => :bcs,
                        :SamplingStrategy => UniformSampling,
                        :MaxTime => 1)
    res = bboptimize(SUTProblem(myidentity_sut); params...)

    @test true
end