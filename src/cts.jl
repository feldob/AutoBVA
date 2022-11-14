# Compatible Type Sampling (CTS) is a sampling feature that allows to cover predefined subspaces more efficiently. Instead of covering only large numbers in Int64, more often smaller numbers are selected. It requires the definition of the compatibletypes implementation for each supported type.

concreteargtype(dt::Type) = isconcretetype(dt) ? dt : throw(InexactError(typeof(dt), dt,"must add concreteargtype impl for type $dt"))
concreteargtype(::Type{Integer}) = Int128
concreteargtype(::Type{Signed}) = Int128
concreteargtype(::Type{Unsigned}) = UInt128

makeconcrete(t::Type) = isconcretetype(t) ? t : concreteargtype(t)

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
compatibletypes(::Type{Integer}) = compatibletypes(Int128) # TODO this is now limited, as it does not consider BigInt -> change?!
compatibletypes(::Type{BigInt}) = compatibletypes(Int128) ∪ compatibletypes(UInt128) ∪ Set([BigInt])
compatibletypes(t::Type{Union}) = Set(compatibletypes.(Base.uniontypes(t)))

compatibletypes(types::Tuple) = compatibletypes.(types)