#myidentity_sut2 = SUT("identity2", (x::Union{Int8, Bool}) -> x) # TODO union support not implemented yet

@testset "local neighbor search LNS test" begin

    params = ParamsDict(:Method => :lns,
                        :SamplingStrategy => UniformSampling,
                        :MaxTime => 1)
    res = bboptimize(SUTProblem(myidentity_sut, [ IntMutationOperators ]); params...)

    @test res.method_output isa BCDOutput

    ranked_candidates = rank_unique(res.method_output; output=true, incl_metric=true, filter=true, tosort=true)

    @test nrow(ranked_candidates) > 0
end

@testset "boundary crossing search BCS test" begin

    params = ParamsDict(:Method => :bcs,
                        :SamplingStrategy => BituniformSampling,
                        :CTS => true,
                        :MaxTime => 1)
    res = bboptimize(SUTProblem(myidentity_sut, [ IntMutationOperators ]); params...)

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

# @testset "string search test" begin

#     doublestringsut = SUT("string double", (x::String) -> x)

#     params = ParamsDict(:Method => :lns,
#                         :SamplingStrategy => ABCStringSamplingStrategy(),
#                         :MaxTime => 1)
#     res = bboptimize(SUTProblem(doublestringsut); params...)

#     params = ParamsDict(:Method => :bcs,
#                         :SamplingStrategy => ABCStringSamplingStrategy(),
#                         :MaxTime => 1)
#     res = bboptimize(SUTProblem(doublestringsut); params...)

#     @test true
# end