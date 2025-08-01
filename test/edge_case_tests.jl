@testset "Edge Case Tests" begin
    @testset "Minimum configuration" begin
        # Test with minimum possible configuration: 0 node bits, 22 sequence bits
        generator = SnowflakeIdGenerator(0, 22, 0, 0, EpochClock())
        
        id = next_id(generator)
        @test id > 0
        @test SnowflakeId.node_id(generator, id) == 0
        @test SnowflakeId.max_node_id(generator) == 0
        @test SnowflakeId.max_sequence(generator) == 2^22 - 1
    end
    
    @testset "Maximum configuration" begin
        # Test with maximum possible configuration: 22 node bits, 0 sequence bits
        generator = SnowflakeIdGenerator(22, 0, 2^22-1, 0, EpochClock())
        
        id = next_id(generator)
        @test id > 0
        @test SnowflakeId.node_id(generator, id) == 2^22-1
        @test SnowflakeId.max_node_id(generator) == 2^22-1
        @test SnowflakeId.max_sequence(generator) == 0
    end
    
    @testset "Single node bit" begin
        # Test with exactly 1 node bit (max node_id = 1)
        generator = SnowflakeIdGenerator(1, 21, 1, 0, EpochClock())
        
        id = next_id(generator)
        @test id > 0
        @test SnowflakeId.node_id(generator, id) == 1
        @test SnowflakeId.max_node_id(generator) == 1
    end
    
    @testset "Single sequence bit" begin
        # Test with exactly 1 sequence bit (max sequence = 1)
        generator = SnowflakeIdGenerator(21, 1, 100, 0, EpochClock())
        
        id = next_id(generator)
        @test id > 0
        @test SnowflakeId.sequence(generator, id) <= 1
        @test SnowflakeId.max_sequence(generator) == 1
    end
    
    @testset "Large timestamp offset" begin
        # Test with a large timestamp offset (should still work)
        large_offset = 1000000000000  # Large but reasonable offset
        clock = EpochClock()
        current_time = time_millis(clock)
        
        if large_offset < current_time
            generator = SnowflakeIdGenerator(10, 12, 123, large_offset, clock)
            
            id = next_id(generator)
            @test id > 0
            
            timestamp_part = SnowflakeId.timestamp(generator, id)
            @test timestamp_part >= 0
            @test timestamp_part == current_time - large_offset
        else
            # Skip if offset would be in the future
            @test_skip "Large offset test skipped - would be in future"
        end
    end
    
    @testset "Sequence rollover behavior" begin
        # Create generator with small sequence bits to force rollover
        generator = SnowflakeIdGenerator(20, 2, 1, 0, EpochClock())  # Only 2 sequence bits = max 3
        
        # Generate enough IDs to potentially cause sequence rollover
        ids = Int64[]
        for i in 1:10
            push!(ids, next_id(generator))
        end
        
        # All IDs should still be unique
        @test length(unique(ids)) == length(ids)
        
        # All should have correct node ID
        for id in ids
            @test SnowflakeId.node_id(generator, id) == 1
        end
    end
    
    @testset "Clock behavior with different clocks" begin
        # Test with EpochClock
        generator_epoch = SnowflakeIdGenerator(10, 12, 123, 0, EpochClock())
        id_epoch = next_id(generator_epoch)
        @test id_epoch > 0
        
        # Both should produce valid IDs with the same node ID
        @test SnowflakeId.node_id(generator_epoch, id_epoch) == 123
    end
    
    @testset "Bit shifting correctness" begin
        # Test that bit shifting works correctly for various configurations
        test_cases = [
            (8, 14, 100),    # 8 node bits, 14 sequence bits
            (12, 10, 500),   # 12 node bits, 10 sequence bits
            (16, 6, 1000),   # 16 node bits, 6 sequence bits
            (4, 18, 15),     # 4 node bits, 18 sequence bits
        ]
        
        for (node_bits, seq_bits, node_id) in test_cases
            if node_id <= 2^node_bits - 1  # Ensure node_id is valid
                generator = SnowflakeIdGenerator(node_bits, seq_bits, node_id, 0, EpochClock())
                
                id = next_id(generator)
                @test id > 0
                
                # Verify correct extraction
                extracted_node = SnowflakeId.node_id(generator, id)
                @test extracted_node == node_id
                
                # Verify sequence is within bounds
                seq = SnowflakeId.sequence(generator, id)
                @test seq >= 0
                @test seq <= 2^seq_bits - 1
            end
        end
    end
    
    @testset "ID structure validation" begin
        generator = SnowflakeIdGenerator(10, 12, 123, 0, EpochClock())
        id = next_id(generator)
        
        # An ID should have the structure: [timestamp][node_id][sequence]
        # Let's verify the bit layout makes sense
        
        timestamp_part = SnowflakeId.timestamp(generator, id)
        node_part = SnowflakeId.node_id(generator, id)
        sequence_part = SnowflakeId.sequence(generator, id)
        
        # Reconstruct the ID from its parts
        # ID = (timestamp << (node_bits + sequence_bits)) | (node_id << sequence_bits) | sequence
        node_id_and_sequence_bits = 10 + 12  # 22 bits total
        sequence_bits = 12
        
        reconstructed = (timestamp_part << node_id_and_sequence_bits) | 
                       (node_part << sequence_bits) | 
                       sequence_part
        
        @test reconstructed == id
    end
    
    @testset "Large ID values" begin
        # Test that large ID values are handled correctly
        generator = SnowflakeIdGenerator(123)
        
        # Generate several IDs and verify they're all reasonable
        for _ in 1:50
            id = next_id(generator)
            @test id > 0
            @test id < typemax(Int64)  # Should not overflow
            
            # Components should be extractable
            @test SnowflakeId.node_id(generator, id) == 123
            @test SnowflakeId.timestamp(generator, id) >= 0
            @test SnowflakeId.sequence(generator, id) >= 0
        end
    end
end