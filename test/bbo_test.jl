@testset "local neighbor search LNS test" begin

    params = ParamsDict(:Method => :lns,
                        :SamplingStrategy => BituniformSampling,
                        :MaxTime => 1)
    res = bboptimize(SUTProblem(myidentity_sut); params...)

    @test res.method_output isa BCDOutput

    ranked_candidates = rank_unique(res.method_output; output=true, incl_metric=true, filter=true)

    @test nrow(ranked_candidates) > 0
    sort!(ranked_candidates, 1:numargs(myidentity_sut), rev = true) |> println
end

@testset "local neighbor search BCS test" begin

    params = ParamsDict(:Method => :bcs,
                        :SamplingStrategy => UniformSampling,
                        :CTS => true,
                        :MaxTime => 1)
    res = bboptimize(SUTProblem(myidentity_sut); params...)

    @test res.method_output isa BCDOutput

    ranked_candidates = rank_unique(res.method_output; output=true, incl_metric=true, filter=true)

    @test nrow(ranked_candidates) > 0
    sort!(ranked_candidates, 1:numargs(myidentity_sut), rev = true) |> println
end