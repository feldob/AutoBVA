# Date
datesut = SUT("Julia Date",
                (year::Int64, month::Int64, day::Int64) -> Date(year, month, day))

# bytecount Julia

bytecountjuliasut = SUT("ByteCount Julia",
                (bytes::Integer) -> Base.format_bytes(bytes))

# bytecount, most copied code snippet on Stackoverflow which happens to be buggy (from Java, adjusted to Julia)
function byte_count_bug(bytes::Integer, si::Bool = true)
    unit = si ? 1000 : 1024
    if bytes < unit
        return string(bytes) * "B"
    end
    exp = floor(Int, log(bytes) / log(unit))
    pre = (si ? "kMGTPE" : "KMGTPE")[exp] * (si ? "" : "i")
    @sprintf("%.1f %sB", bytes / (unit^exp), pre)
end

bytecountbugsut = SUT("ByteCount Buggy",
                (bytes::Integer) -> byte_count_bug(bytes))