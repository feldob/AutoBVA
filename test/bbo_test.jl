#myidentity_sut2 = SUT("identity2", (x::Union{Int8, Bool}) -> x) # TODO union support not implemented yet

# activate once taken care of the misterium of algs disappearing for each build
# @testset "alg availability test" begin

#     @test isdefined(BlackBoxOptim, :SingleObjectiveMethods)
#     @test :lns ∈ keys(BlackBoxOptim.SingleObjectiveMethods)
#     @test :bcs ∈ keys(BlackBoxOptim.SingleObjectiveMethods)
# end

@testset "local neighbor search LNS test" begin

    params = ParamsDict(:Method => :lns,
                        :SamplingStrategy => UniformSampling,
                        :MaxTime => 1)
    res = bboptimize(SUTProblem(myidentity_sut); params...)

    @test res.method_output isa BCDOutput

    ranked_candidates = rank_unique(res.method_output; output=true, incl_metric=true, filter=true, tosort=true)

    @test nrow(ranked_candidates) > 0
end

@testset "boundary crossing search BCS test" begin

    params = ParamsDict(:Method => :bcs,
                        :SamplingStrategy => BituniformSampling,
                        :CTS => true,
                        :MaxTime => 1)
    res = bboptimize(SUTProblem(myidentity_sut); params...)

    @test res.method_output isa BCDOutput

    ranked_candidates = rank_unique(res.method_output; output=true, incl_metric=true, filter=true, tosort=true)

    @test nrow(ranked_candidates) > 0
end

@testset "unsigned issue with dataframe grouping" begin
    df = DataFrame(:a => Integer[UInt64(1), -1], :n_a => Integer[UInt64(2), -2])

    @test_throws InexactError DataFrames.groupby(df, [:a, :n_a])

    df = AutoBVA.avoidInexactErrorWhenGrouping(df, ["a"])

    DataFrames.groupby(df, [:a, :n_a])
    @test true
end