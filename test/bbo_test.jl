@testset "local neighbor search LNS test" begin

    params = ParamsDict(:Method => :lns,
                        :SamplingStrategy => BituniformSampling,
                        :MaxTime => 2)
    res = bboptimize(SUTProblem(myidentity_sut); params...)

end