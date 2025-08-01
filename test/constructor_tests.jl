@testset "Constructor Tests" begin
    @testset "Default constructor" begin
        node_id = 123
        generator = SnowflakeIdGenerator(node_id)
        
        @test SnowflakeId.node_id(generator) == node_id
        @test SnowflakeId.timestamp_offset_ms(generator) == 0
        @test SnowflakeId.max_node_id(generator) == 2^10 - 1  # Default NODE_ID_BITS_DEFAULT = 10
        @test SnowflakeId.max_sequence(generator) == 2^12 - 1  # Default SEQUENCE_BITS_DEFAULT = 12
    end
    
    @testset "Constructor with clock" begin
        node_id = 456
        clock = EpochClock()
        generator = SnowflakeIdGenerator(node_id, clock)
        
        @test SnowflakeId.node_id(generator) == node_id
        @test SnowflakeId.timestamp_offset_ms(generator) == 0
        @test SnowflakeId.max_node_id(generator) == 2^10 - 1
        @test SnowflakeId.max_sequence(generator) == 2^12 - 1
    end
    
    @testset "Full constructor with custom bits" begin
        node_id_bits = 8
        sequence_bits = 14
        node_id = 100
        timestamp_offset_ms = 1000
        clock = EpochClock()
        
        generator = SnowflakeIdGenerator(node_id_bits, sequence_bits, node_id, timestamp_offset_ms, clock)
        
        @test SnowflakeId.node_id(generator) == node_id
        @test SnowflakeId.timestamp_offset_ms(generator) == timestamp_offset_ms
        @test SnowflakeId.max_node_id(generator) == 2^node_id_bits - 1
        @test SnowflakeId.max_sequence(generator) == 2^sequence_bits - 1
    end
    
    @testset "Constructor validation - negative node_id_bits" begin
        @test_throws ArgumentError SnowflakeIdGenerator(-1, 12, 1, 0, EpochClock())
    end
    
    @testset "Constructor validation - negative sequence_bits" begin
        @test_throws ArgumentError SnowflakeIdGenerator(10, -1, 1, 0, EpochClock())
    end
    
    @testset "Constructor validation - too many bits" begin
        # MAX_NODE_ID_AND_SEQUENCE_BITS = 22
        @test_throws ArgumentError SnowflakeIdGenerator(15, 10, 1, 0, EpochClock())  # 15 + 10 = 25 > 22
    end
    
    @testset "Constructor validation - negative node_id" begin
        @test_throws ArgumentError SnowflakeIdGenerator(10, 12, -1, 0, EpochClock())
    end
    
    @testset "Constructor validation - node_id too large" begin
        # With 8 bits, max node_id is 2^8 - 1 = 255
        @test_throws ArgumentError SnowflakeIdGenerator(8, 12, 256, 0, EpochClock())
    end
    
    @testset "Constructor validation - negative timestamp_offset_ms" begin
        @test_throws ArgumentError SnowflakeIdGenerator(10, 12, 1, -1, EpochClock())
    end
    
    @testset "Constructor validation - timestamp_offset_ms in future" begin
        clock = EpochClock()
        future_offset = time_millis(clock) + 10000  # 10 seconds in future
        @test_throws ArgumentError SnowflakeIdGenerator(10, 12, 1, future_offset, clock)
    end
    
    @testset "Boundary values" begin
        # Test boundary values that should work
        @test_nowarn SnowflakeIdGenerator(0, 22, 0, 0, EpochClock())  # Min node_id_bits, max sequence_bits
        @test_nowarn SnowflakeIdGenerator(22, 0, 0, 0, EpochClock())  # Max node_id_bits, min sequence_bits
        @test_nowarn SnowflakeIdGenerator(11, 11, 2^11-1, 0, EpochClock())  # Max node_id for 11 bits
    end
end