#myidentity_sut2 = SUT("identity2", (x::Union{Int8, Bool}) -> x) # TODO union support not implemented yet

@testset "local neighbor search LNS test" begin

    params = ParamsDict(:Method => :lns,
                        :SamplingStrategy => UniformSampling,
                        :MaxTime => 1)
    res = bboptimize(SUTProblem(myidentity_sut); params...)

    @test res.method_output isa BCDOutput

    ranked_candidates = rank_unique(res.method_output; output=true, incl_metric=true, filter=true, tosort=true)
    ranked_candidates |> println

    @test nrow(ranked_candidates) > 0
end

@testset "boundary crossing search BCS test" begin

    params = ParamsDict(:Method => :bcs,
                        :SamplingStrategy => BituniformSampling,
                        :CTS => true,
                        :MaxTime => 1)
    res = bboptimize(SUTProblem(bytecountbugsut); params...)

    @test res.method_output isa BCDOutput

    ranked_candidates = rank_unique(res.method_output; output=true, incl_metric=true, filter=true, tosort=true)
    ranked_candidates |> println

    @test nrow(ranked_candidates) > 0
end