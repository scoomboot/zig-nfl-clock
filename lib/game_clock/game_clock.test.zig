// game_clock.test.zig — Game clock unit tests
//
// repo   : https://github.com/zig-nfl-clock
// docs   : https://zig-nfl-clock.github.io/docs/lib/game_clock/game_clock.test
// author : https://github.com/fisty
//
// Vibe coded by Scoom.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const GameClock = @import("game_clock.zig").GameClock;
    const Quarter = @import("game_clock.zig").Quarter;
    const GameState = @import("game_clock.zig").GameState;
    const GameClockError = @import("game_clock.zig").GameClockError;

    const QUARTER_LENGTH_SECONDS = @import("game_clock.zig").QUARTER_LENGTH_SECONDS;
    const PLAY_CLOCK_SECONDS = @import("game_clock.zig").PLAY_CLOCK_SECONDS;
    const OVERTIME_LENGTH_SECONDS = @import("game_clock.zig").OVERTIME_LENGTH_SECONDS;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    /// Test data for clock state validation
    const TestClockState = struct {
        time_remaining: u32,
        quarter: Quarter,
        is_running: bool,
        play_clock: u8,
        game_state: GameState,
        total_elapsed: u64,
    };

    /// Test scenarios for game situations
    const TestScenario = struct {
        name: []const u8,
        initial_state: TestClockState,
        actions: []const TestAction,
        expected_state: TestClockState,
    };

    /// Test action types
    const TestAction = union(enum) {
        start: void,
        stop: void,
        tick: u32, // number of ticks
        reset_play_clock: void,
        set_play_clock: u8,
        start_overtime: void,
        reset: void,
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    // ┌──────────────────────────── Unit Tests ────────────────────────────┐

    test "unit: GameClock: initializes with correct default values" {
        const allocator = testing.allocator;
        const clock = GameClock.init(allocator);
        
        try testing.expectEqual(QUARTER_LENGTH_SECONDS, clock.time_remaining);
        try testing.expectEqual(Quarter.Q1, clock.quarter);
        try testing.expectEqual(false, clock.is_running);
        try testing.expectEqual(PLAY_CLOCK_SECONDS, clock.play_clock);
        try testing.expectEqual(GameState.PreGame, clock.game_state);
        try testing.expectEqual(@as(u64, 0), clock.total_elapsed);
    }

    test "unit: GameClock: starts clock from pregame state" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        try clock.start();
        try testing.expectEqual(true, clock.is_running);
        try testing.expectEqual(GameState.InProgress, clock.game_state);
    }

    test "unit: GameClock: prevents double start" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        try clock.start();
        try testing.expectError(GameClockError.ClockAlreadyRunning, clock.start());
    }

    test "unit: GameClock: stops running clock" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        try clock.start();
        try clock.stop();
        try testing.expectEqual(false, clock.is_running);
    }

    test "unit: GameClock: prevents stopping non-running clock" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        try testing.expectError(GameClockError.ClockNotRunning, clock.stop());
    }

    test "unit: GameClock: tick decrements time correctly" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        try clock.start();
        clock.startPlayClock(); // Start play clock for it to tick
        const initial_time = clock.time_remaining;
        const initial_play_clock = clock.play_clock;
        
        try clock.tick();
        
        try testing.expectEqual(initial_time - 1, clock.time_remaining);
        try testing.expectEqual(initial_play_clock - 1, clock.play_clock);
        try testing.expectEqual(@as(u64, 1), clock.total_elapsed);
    }

    test "unit: GameClock: tick does nothing when clock stopped" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        const initial_time = clock.time_remaining;
        try clock.tick();
        try testing.expectEqual(initial_time, clock.time_remaining);
    }

    test "unit: GameClock: handles play clock expiration" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        try clock.start();
        clock.startPlayClock(); // Start play clock for it to tick
        clock.play_clock = 1;
        try clock.tick();
        
        try testing.expectEqual(@as(u8, 0), clock.play_clock);
        try testing.expect(clock.isPlayClockExpired());
    }

    test "unit: GameClock: resets play clock to default value" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        clock.play_clock = 10;
        clock.resetPlayClock();
        try testing.expectEqual(PLAY_CLOCK_SECONDS, clock.play_clock);
    }

    test "unit: GameClock: sets play clock to valid value" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        try clock.setPlayClock(25);
        try testing.expectEqual(@as(u8, 25), clock.play_clock);
    }

    test "unit: GameClock: rejects invalid play clock value" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        try testing.expectError(GameClockError.InvalidPlayClock, clock.setPlayClock(50));
    }

    test "unit: GameClock: formats time string correctly" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        var buffer: [16]u8 = undefined;
        
        // Test 15:00
        const time_str1 = clock.getTimeString(&buffer);
        try testing.expectEqualStrings("15:00", time_str1);
        
        // Test 02:05
        clock.time_remaining = 125;
        const time_str2 = clock.getTimeString(&buffer);
        try testing.expectEqualStrings("02:05", time_str2);
        
        // Test 00:09
        clock.time_remaining = 9;
        const time_str3 = clock.getTimeString(&buffer);
        try testing.expectEqualStrings("00:09", time_str3);
    }

    test "unit: Quarter: returns correct display strings" {
        try testing.expectEqualStrings("1st Quarter", Quarter.Q1.toString());
        try testing.expectEqualStrings("2nd Quarter", Quarter.Q2.toString());
        try testing.expectEqualStrings("3rd Quarter", Quarter.Q3.toString());
        try testing.expectEqualStrings("4th Quarter", Quarter.Q4.toString());
        try testing.expectEqualStrings("Overtime", Quarter.Overtime.toString());
    }

    test "unit: GameState: correctly identifies active state" {
        try testing.expect(!GameState.PreGame.isActive());
        try testing.expect(GameState.InProgress.isActive());
        try testing.expect(!GameState.Halftime.isActive());
        try testing.expect(!GameState.EndGame.isActive());
    }

    // └──────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Integration Tests ────────────────────────────┐

    test "integration: GameClock: handles quarter transitions correctly" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        try clock.start();
        
        // End of Q1 -> Q2
        clock.time_remaining = 1;
        try clock.tick();
        try testing.expectEqual(Quarter.Q2, clock.quarter);
        try testing.expectEqual(QUARTER_LENGTH_SECONDS, clock.time_remaining);
        try testing.expectEqual(false, clock.is_running);
        
        // End of Q2 -> Halftime
        try clock.start();
        clock.time_remaining = 1;
        try clock.tick();
        try testing.expectEqual(Quarter.Q3, clock.quarter);
        try testing.expectEqual(GameState.Halftime, clock.game_state);
        
        // End of Q3 -> Q4
        clock.game_state = .InProgress;
        try clock.start();
        clock.time_remaining = 1;
        try clock.tick();
        try testing.expectEqual(Quarter.Q4, clock.quarter);
        try testing.expectEqual(GameState.InProgress, clock.game_state);
        
        // End of Q4 -> Game End
        try clock.start();
        clock.time_remaining = 1;
        try clock.tick();
        try testing.expectEqual(GameState.EndGame, clock.game_state);
    }

    test "integration: GameClock: manages overtime correctly" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Set up end of regulation
        clock.quarter = .Q4;
        clock.time_remaining = 0;
        clock.game_state = .InProgress;
        
        try clock.startOvertime();
        try testing.expectEqual(Quarter.Overtime, clock.quarter);
        try testing.expectEqual(OVERTIME_LENGTH_SECONDS, clock.time_remaining);
        try testing.expectEqual(GameState.InProgress, clock.game_state);
        try testing.expectEqual(false, clock.is_running);
    }

    test "integration: GameClock: prevents invalid overtime start" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Not at end of Q4
        clock.quarter = .Q3;
        try testing.expectError(GameClockError.InvalidQuarter, clock.startOvertime());
        
        // Q4 but time remaining
        clock.quarter = .Q4;
        clock.time_remaining = 10;
        try testing.expectError(GameClockError.InvalidQuarter, clock.startOvertime());
    }

    test "integration: GameClock: reset returns to initial state" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Modify state
        try clock.start();
        clock.quarter = .Q3;
        clock.time_remaining = 500;
        clock.play_clock = 10;
        clock.total_elapsed = 1000;
        
        // Reset
        clock.reset();
        
        // Verify initial state
        try testing.expectEqual(QUARTER_LENGTH_SECONDS, clock.time_remaining);
        try testing.expectEqual(Quarter.Q1, clock.quarter);
        try testing.expectEqual(false, clock.is_running);
        try testing.expectEqual(PLAY_CLOCK_SECONDS, clock.play_clock);
        try testing.expectEqual(GameState.PreGame, clock.game_state);
        try testing.expectEqual(@as(u64, 0), clock.total_elapsed);
    }

    test "integration: GameClock: tracks total elapsed time across quarters" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        try clock.start();
        
        // Simulate 10 seconds in Q1
        for (0..10) |_| {
            try clock.tick();
    }
        try testing.expectEqual(@as(u64, 10), clock.total_elapsed);
        
        // Move to Q2 and simulate more time
        clock.quarter = .Q2;
        for (0..5) |_| {
            try clock.tick();
    }
        try testing.expectEqual(@as(u64, 15), clock.total_elapsed);
    }

    // └──────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── End-to-End Tests ────────────────────────────┐

    test "e2e: GameClock: simulates complete quarter with play clock management" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        try clock.start();
        
        // Simulate several plays
        for (0..5) |play_num| {
            // Run play clock down
            for (0..35) |_| {
                try clock.tick();
        }
            
            // Reset play clock for next play
            clock.resetPlayClock();
            
            // Verify state
            try testing.expect(clock.time_remaining < QUARTER_LENGTH_SECONDS);
            try testing.expectEqual(PLAY_CLOCK_SECONDS, clock.play_clock);
            try testing.expectEqual(@as(u64, (play_num + 1) * 35), clock.total_elapsed);
    }
    }

    test "e2e: GameClock: handles two-minute drill scenario" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Set up two-minute scenario
        clock.quarter = .Q4;
        clock.time_remaining = 120; // 2 minutes
        clock.game_state = .InProgress;
        
        try clock.start();
        
        // Simulate hurry-up offense
        for (0..4) |_| {
            // Quick play - only 15 seconds
            for (0..15) |_| {
                try clock.tick();
        }
            
            // Stop clock (incomplete pass)
            try clock.stop();
            
            // Reset play clock and restart
            clock.resetPlayClock();
            try clock.start();
    }
        
        // Verify we used 60 seconds (4 plays * 15 seconds)
        try testing.expectEqual(@as(u32, 60), clock.time_remaining);
    }

    test "e2e: GameClock: complete game simulation" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Start game
        try clock.start();
        try testing.expectEqual(GameState.InProgress, clock.game_state);
        
        // Simulate Q1
        clock.time_remaining = 1;
        try clock.tick();
        try testing.expectEqual(Quarter.Q2, clock.quarter);
        
        // Simulate Q2
        try clock.start();
        clock.time_remaining = 1;
        try clock.tick();
        try testing.expectEqual(GameState.Halftime, clock.game_state);
        
        // Resume for second half
        clock.game_state = .InProgress;
        try clock.start();
        
        // Simulate Q3
        clock.time_remaining = 1;
        try clock.tick();
        try testing.expectEqual(Quarter.Q4, clock.quarter);
        
        // Simulate Q4
        try clock.start();
        clock.time_remaining = 1;
        try clock.tick();
        try testing.expectEqual(GameState.EndGame, clock.game_state);
    }

    // └──────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Performance Tests ────────────────────────────┐

    test "performance: GameClock: handles rapid tick operations efficiently" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        try clock.start();
        
        const start_time = std.time.milliTimestamp();
        
        // Simulate 1000 ticks
        for (0..1000) |_| {
            try clock.tick();
            if (clock.time_remaining == 0) {
                clock.time_remaining = QUARTER_LENGTH_SECONDS;
        }
    }
        
        const elapsed = std.time.milliTimestamp() - start_time;
        
        // Should complete in under 10ms
        try testing.expect(elapsed < 10);
    }

    test "performance: GameClock: time string formatting is fast" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        var buffer: [16]u8 = undefined;
        
        const start_time = std.time.milliTimestamp();
        
        // Format time 10000 times
        for (0..10000) |i| {
            clock.time_remaining = @intCast(i % 3600);
            _ = clock.getTimeString(&buffer);
    }
        
        const elapsed = std.time.milliTimestamp() - start_time;
        
        // Should complete in under 50ms
        try testing.expect(elapsed < 50);
    }

    // └──────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Stress Tests ────────────────────────────┐

    test "stress: GameClock: handles maximum game duration" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        try clock.start();
        
        // Simulate maximum possible game (4 quarters + multiple overtimes)
        for (0..6) |quarter_num| {
            if (quarter_num == 5) {
                // Start overtime
                clock.quarter = .Q4;
                clock.time_remaining = 0;
                try clock.startOvertime();
        }
            
            // Run entire period
            const period_length = if (quarter_num >= 4) OVERTIME_LENGTH_SECONDS else QUARTER_LENGTH_SECONDS;
            for (0..period_length) |_| {
                if (clock.is_running) {
                    try clock.tick();
            }
                if (clock.time_remaining == 0 and quarter_num < 3) {
                    try clock.start(); // Restart after quarter end
            }
        }
    }
        
        // Verify we tracked all the time
        try testing.expect(clock.total_elapsed > 0);
        try testing.expect(clock.game_state == .EndGame or clock.quarter == .Overtime);
    }

    test "stress: GameClock: handles rapid state changes" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Rapidly change states
        for (0..100) |i| {
            if (i % 2 == 0) {
                if (!clock.is_running and clock.game_state != .EndGame) {
                    try clock.start();
            }
        } else {
                if (clock.is_running) {
                    try clock.stop();
            }
        }
            
            // Random play clock changes
            const new_play_clock = @as(u8, @intCast((i * 7) % 40 + 1));
            try clock.setPlayClock(new_play_clock);
            
            // Tick occasionally
            if (i % 3 == 0) {
                try clock.tick();
        }
            
            // Reset play clock occasionally
            if (i % 5 == 0) {
                clock.resetPlayClock();
        }
    }
        
        // Clock should still be in valid state
        try testing.expect(clock.play_clock <= PLAY_CLOCK_SECONDS);
        try testing.expect(clock.time_remaining <= QUARTER_LENGTH_SECONDS or 
                        (clock.quarter == .Overtime and clock.time_remaining <= OVERTIME_LENGTH_SECONDS));
    }

    test "stress: GameClock: handles edge case time values" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Test with 0 time remaining
        clock.time_remaining = 0;
        try testing.expect(clock.isQuarterEnded());
        
        // Test with 1 second remaining
        clock.time_remaining = 1;
        try testing.expect(!clock.isQuarterEnded());
        const initial_quarter = clock.quarter;
        try clock.start();
        try clock.tick();
        // After tick, quarter should have advanced due to automatic quarter transition
        try testing.expect(clock.quarter != initial_quarter);
        try testing.expectEqual(QUARTER_LENGTH_SECONDS, clock.time_remaining);
        
        // Test play clock at boundary
        clock.play_clock = 0;
        try testing.expect(clock.isPlayClockExpired());
        
        clock.play_clock = 1;
        try testing.expect(!clock.isPlayClockExpired());
        
        // Test maximum values
        clock.time_remaining = QUARTER_LENGTH_SECONDS;
        clock.play_clock = PLAY_CLOCK_SECONDS;
        try testing.expect(!clock.isQuarterEnded());
        try testing.expect(!clock.isPlayClockExpired());
    }

    // └──────────────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════╝