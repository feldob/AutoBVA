# TODO copy this and use as template for your own type compatibility. See an example under string_input_extension.jl.

# datatype specific that must be implemented
# ------------------------------------------
# isatomic(t::MyType)
#-------------------------------------------

# Type/SUT specific that must be implemented
# struct MySamplingStrategy <: SamplingStrategy{MyType} end
# nextinput(mss::MySamplingStrategy) 
#-------------------------------------------

# mutation operator specific that must be implemented
# ------------------------------------------
# struct MyTypeReductionOperator <: ReductionOperator{MyType} end
# struct MyTypeExtensionOperator <: ExtensionOperator{MyType} end
# rightdirection(::MyTypeReductionOperator, currentvalue::MyType, nextvalue::MyType)
# rightdirection(::MyTypeExtensionOperator, currentvalue::MyType, nextvalue::MyType)
# edgecase(::ReductionOperator{MyType}, value::MyType)                               is extreme minimal value
# edgecase(::ExtensionOperator{MyType}, value::MyType)                               is extreme maximal value
# withinbounds(ro::ReductionOperator{MyType}, current::MyType, next::MyType)
# withinbounds(eo::ExtensionOperator{MyType}, current::MyType, next::MyType)
#-------------------------------------------
