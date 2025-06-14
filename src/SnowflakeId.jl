module SnowflakeId

using Clocks
using Hwloc
using LibUV_jll

export SnowflakeIdGenerator,
    node_id,
    timestamp_offset_ms,
    max_node_id,
    max_sequence,
    next_id,
    extract_timestamp,
    extract_node_id,
    extract_sequence

const CACHE_LINE_SIZE::Int = maximum(cachelinesize())
const CACHE_LINE_PAD::Int = CACHE_LINE_SIZE - sizeof(Int64)
# Number of bits used for the timestamp, allowing for 69 years from `timestamp_offset_ms()`.
const EPOCH_BITS::Int = 41
# Total number of bits used to represent the distributed node and the sequence within a millisecond.
const MAX_NODE_ID_AND_SEQUENCE_BITS::Int = 22
# Default number of bits used to represent the distributed node or application, allowing for 1024 nodes (0-1023).
const NODE_ID_BITS_DEFAULT::Int = 10
# Default number of bits used to represent the sequence within a millisecond, supporting 4,096,000 ids per second per node.
const SEQUENCE_BITS_DEFAULT::Int = 12

"""
    Generate unique identifiers based on the Twitter
    [Snowflake](https://github.com/twitter-archive/snowflake/tree/snowflake-2010) algorithm.

This implementation is lock-less resulting in greater throughput plus less contention and latency jitter.

!!! note
    ntpd, or alternative clock source, should be setup correctly to ensure the clock does not go backwards.
"""
mutable struct SnowflakeIdGenerator{C<:AbstractClock}
    const pad1::NTuple{CACHE_LINE_PAD,Int8}
    @atomic timestamp_sequence::Int64
    const pad2::NTuple{CACHE_LINE_PAD,Int8}
    const node_id_and_sequence_bits::Int32
    const sequence_bits::Int32
    const max_node_id::Int64
    const max_sequence::Int64
    const node_bits::Int64
    const timestamp_offset_ms::Int64
    const clock::C

    function SnowflakeIdGenerator(node_id_bits::Int,
        sequence_bits::Int,
        node_id::Int64,
        timestamp_offset_ms::Int64,
        clock::C) where {C<:AbstractClock}

        if node_id_bits < 0
            throw(ArgumentError("must be >= 0: node_id_bits=$node_id_bits"))
        end
        if sequence_bits < 0
            throw(ArgumentError("must be >= 0: sequence_bits=$sequence_bits"))
        end

        node_id_and_sequence_bits = node_id_bits + sequence_bits
        if node_id_and_sequence_bits > MAX_NODE_ID_AND_SEQUENCE_BITS
            throw(ArgumentError("too many bits used: node_id_bits=$node_id_bits + sequence_bits=$sequence_bits > $MAX_NODE_ID_AND_SEQUENCE_BITS"))
        end

        max_node_id = 2^node_id_bits - 1
        if node_id < 0 || node_id > max_node_id
            throw(ArgumentError("must be >= 0 && <= $max_node_id: node_id=$node_id"))
        end

        if timestamp_offset_ms < 0
            throw(ArgumentError("must be >= 0: timestamp_offset_ms=$timestamp_offset_ms"))
        end

        now_ms = time_millis(clock)
        if timestamp_offset_ms > now_ms
            throw(ArgumentError("timestamp_offset_ms=$timestamp_offset_ms > now_ms=$now_ms"))
        end

        max_sequence = 2^sequence_bits - 1
        node_bits = node_id << sequence_bits

        new{C}(ntuple(x -> Int8(0), CACHE_LINE_PAD),
            0,
            ntuple(x -> Int8(0), CACHE_LINE_PAD),
            node_id_and_sequence_bits,
            sequence_bits,
            max_node_id,
            max_sequence,
            node_bits,
            timestamp_offset_ms,
            clock)
    end
end

SnowflakeIdGenerator(node_id::Int64) = SnowflakeIdGenerator(NODE_ID_BITS_DEFAULT, SEQUENCE_BITS_DEFAULT, node_id, 0, EpochClock())
SnowflakeIdGenerator(node_id::Int64, clock::AbstractClock) = SnowflakeIdGenerator(NODE_ID_BITS_DEFAULT, SEQUENCE_BITS_DEFAULT, node_id, 0, clock)

"""
    node_id(g::SnowflakeIdGenerator) -> Int

Returns the node ID of the given `SnowflakeIdGenerator` instance.
"""
node_id(g::SnowflakeIdGenerator) = g.node_bits >>> g.sequence_bits

"""
    timestamp_offset_ms(g::SnowflakeIdGenerator) -> Int

Returns the timestamp offset in milliseconds of the given `SnowflakeIdGenerator` instance.
"""
timestamp_offset_ms(g::SnowflakeIdGenerator) = g.timestamp_offset_ms

"""
    max_node_id(g::SnowflakeIdGenerator) -> Int

Returns the maximum node ID of the given `SnowflakeIdGenerator` instance.
"""
max_node_id(g::SnowflakeIdGenerator) = g.max_node_id

"""
    max_sequence(g::SnowflakeIdGenerator) -> Int

Returns the maximum sequence number of the given `SnowflakeIdGenerator` instance.
"""
max_sequence(g::SnowflakeIdGenerator) = g.max_sequence

"""
    next_id(g::SnowflakeIdGenerator) -> Int

Generate the next id in sequence. If `maxSequence()` is reached within the same millisecond, 
this implementation will busy spin until the next millisecond.

# Arguments
- `g::SnowflakeIdGenerator`: The generator instance.

# Returns
- The next unique id for this node.
"""
function next_id(g::SnowflakeIdGenerator)
    while true
        old_timestamp_sequence = @atomic g.timestamp_sequence
        timestamp_ms = time_millis(g.clock) - g.timestamp_offset_ms
        old_timestamp_ms = old_timestamp_sequence >>> g.node_id_and_sequence_bits

        if timestamp_ms > old_timestamp_ms
            new_timestamp_sequence = timestamp_ms << g.node_id_and_sequence_bits
            (_, success) = @atomicreplace g.timestamp_sequence old_timestamp_sequence => new_timestamp_sequence
            if success
                return new_timestamp_sequence | g.node_bits
            end
        else
            old_sequence = old_timestamp_sequence & g.max_sequence
            if old_sequence < g.max_sequence
                new_timestamp_sequence = old_timestamp_sequence + 1
                (_, success) = @atomicreplace g.timestamp_sequence old_timestamp_sequence => new_timestamp_sequence
                if success
                    return new_timestamp_sequence | g.node_bits
                end
            end
        end
        ccall(:jl_cpu_pause, Cvoid, ())
    end
end

extract_timestamp(g::SnowflakeIdGenerator, id::Int64) = id >>> g.node_id_and_sequence_bits
extract_node_id(g::SnowflakeIdGenerator, id::Int64) = (id >>> g.sequence_bits) & g.max_node_id
extract_sequence(g::SnowflakeIdGenerator, id::Int64) = id & g.max_sequence

end # module SnowflakeId
