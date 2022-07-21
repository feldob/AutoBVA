# Compatible Type Sampling (CTS) is a sampling feature that allows to cover predefined subspaces more efficiently. Instead of covering only large numbers in Int64, more often smaller numbers are selected. It requires the definition of the compatibletypes implementation for each supported type.

concreteargtype(dt::DataType) = isconcretetype(dt) ? dt : throw(InexactError(:type, dt,"must add concreteargtype impl for type $dt"))
concreteargtype(::Type{Integer}) = Int128
concreteargtype(::Type{Signed}) = Int128
concreteargtype(::Type{Unsigned}) = UInt128

compatibletypes(x::Type{Any}) = DomainError(typeof(x), "No implementation for type $(typeof(x)) available, must implement before use.") |> throw

compatibletypes(::Type{Bool}) = Set([Bool])

compatibletypes(::Type{UInt8}) = compatibletypes(Bool) ∪ Set([UInt8])
compatibletypes(::Type{UInt16}) = compatibletypes(UInt8) ∪ Set([UInt16])
compatibletypes(::Type{UInt32}) = compatibletypes(UInt16) ∪ Set([UInt32])
compatibletypes(::Type{UInt64}) = compatibletypes(UInt32) ∪ Set([UInt64])
compatibletypes(::Type{UInt128}) = compatibletypes(UInt64) ∪ Set([UInt128])

# unsigned of smaller bitsize are compatible to signed of larger bitsize -> incorporate
compatibletypes(::Type{Int8}) = compatibletypes(Bool) ∪ Set([Int8])
compatibletypes(::Type{Int16}) = compatibletypes(Int8) ∪ compatibletypes(UInt8) ∪ Set([Int16])
compatibletypes(::Type{Int32}) = compatibletypes(Int16) ∪ compatibletypes(UInt16) ∪ Set([Int32])
compatibletypes(::Type{Int64}) = compatibletypes(Int32) ∪ compatibletypes(UInt32) ∪ Set([Int64])
compatibletypes(::Type{Int128}) = compatibletypes(Int64) ∪ compatibletypes(UInt64) ∪ Set([Int128])
compatibletypes(::Type{BigInt}) = compatibletypes(Int128) ∪ Set([BigInt])

# lists all the types that are currently compatible with CTS in the runtime, i.e. there is an available implementation of compatibletypes
function cts_supportedtypes()
    return  map(m -> m.sig.parameters[2].parameters[1], filter(m -> m.nargs == 2 && m.sig.parameters[2] != Type{Any}, methods(compatibletypes)))
end

cts_supportedtypes(type::DataType) = filter(t -> t ∈ cts_supportedtypes(), subtypes(type))

function concretetypes(type::DataType)
    if isconcretetype(type)
        return compatibletypes(type)
    end

    return reduce((e,n) -> e ∪ concretetypes(n), cts_supportedtypes(type), init=Set{DataType}())
end

concretetypes(types::Tuple) = concretetypes.(types)