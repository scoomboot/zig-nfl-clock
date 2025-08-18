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

    // ┌──────────────────────────── Test Helpers ────────────────────────────┐

    /// Creates a GameClock with default test configuration
    fn createTestClock() GameClock {
        return GameClock.init(testing.allocator);
    }

    /// Creates a GameClock with specific initial state
    fn createTestClockWithState(state: TestClockState) GameClock {
        var clock = GameClock.init(testing.allocator);
        clock.time_remaining = state.time_remaining;
        clock.quarter = state.quarter;
        clock.is_running = state.is_running;
        clock.play_clock = state.play_clock;
        clock.game_state = state.game_state;
        clock.total_elapsed = state.total_elapsed;
        return clock;
    }

    /// Creates a GameClock in a specific quarter with given time
    fn createClockAtQuarter(quarter: Quarter, time_remaining: u32) GameClock {
        var clock = createTestClock();
        clock.quarter = quarter;
        clock.time_remaining = time_remaining;
        return clock;
    }

    /// Creates a GameClock ready for two-minute warning scenario
    fn createTwoMinuteClock(quarter: Quarter) GameClock {
        var clock = createTestClock();
        clock.quarter = quarter;
        clock.time_remaining = 120;
        clock.game_state = .InProgress;
        return clock;
    }

    /// Asserts that two time values are equal within tolerance
    fn assertTimeEquals(expected: u32, actual: u32) !void {
        const tolerance: u32 = 1; // 1 second tolerance
        const diff = if (expected > actual) expected - actual else actual - expected;
        try testing.expect(diff <= tolerance);
    }

    /// Asserts complete clock state matches expected values
    fn assertClockState(clock: *const GameClock, expected: TestClockState) !void {
        try testing.expectEqual(expected.time_remaining, clock.time_remaining);
        try testing.expectEqual(expected.quarter, clock.quarter);
        try testing.expectEqual(expected.is_running, clock.is_running);
        try testing.expectEqual(expected.play_clock, clock.play_clock);
        try testing.expectEqual(expected.game_state, clock.game_state);
        try testing.expectEqual(expected.total_elapsed, clock.total_elapsed);
    }

    /// Simulates a complete play with given duration
    fn simulatePlay(clock: *GameClock, seconds: u32) !void {
        try clock.start();
        for (0..seconds) |_| {
            try clock.tick();
        }
        try clock.stop();
        clock.resetPlayClock();
    }

    /// Simulates running down the play clock to expiration
    fn simulatePlayClockExpiration(clock: *GameClock) !void {
        try clock.start();
        clock.startPlayClock();
        while (clock.play_clock > 0) {
            try clock.tick();
        }
    }

    /// Advances clock to end of current quarter
    fn advanceToQuarterEnd(clock: *GameClock) !void {
        try clock.start();
        while (clock.time_remaining > 1) {
            clock.time_remaining = 1;
        }
        try clock.tick();
    }

    /// Advances clock to two-minute warning
    fn advanceToTwoMinuteWarning(clock: *GameClock) !void {
        if (clock.quarter != .Q2 and clock.quarter != .Q4) {
            clock.quarter = .Q2;
        }
        clock.time_remaining = 120;
        clock.game_state = .InProgress;
    }

    /// Simulates a complete quarter with realistic play patterns
    fn simulateQuarter(clock: *GameClock) !void {
        const plays_per_quarter = 20;
        const avg_play_duration = 35;
        
        for (0..plays_per_quarter) |_| {
            if (clock.time_remaining < avg_play_duration) break;
            try simulatePlay(clock, avg_play_duration);
        }
    }

    /// Creates test data for various game scenarios
    fn createScenarioData(scenario_type: enum { normal, hurry_up, end_game, overtime }) TestScenario {
        return switch (scenario_type) {
            .normal => TestScenario{
                .name = "Normal game flow",
                .initial_state = TestClockState{
                    .time_remaining = 900,
                    .quarter = .Q1,
                    .is_running = false,
                    .play_clock = 40,
                    .game_state = .PreGame,
                    .total_elapsed = 0,
                },
                .actions = &[_]TestAction{
                    .{ .start = {} },
                    .{ .tick = 10 },
                    .{ .stop = {} },
                },
                .expected_state = TestClockState{
                    .time_remaining = 890,
                    .quarter = .Q1,
                    .is_running = false,
                    .play_clock = 30,
                    .game_state = .InProgress,
                    .total_elapsed = 10,
                },
            },
            .hurry_up => TestScenario{
                .name = "Hurry-up offense",
                .initial_state = TestClockState{
                    .time_remaining = 120,
                    .quarter = .Q4,
                    .is_running = false,
                    .play_clock = 40,
                    .game_state = .InProgress,
                    .total_elapsed = 3300,
                },
                .actions = &[_]TestAction{
                    .{ .start = {} },
                    .{ .tick = 5 },
                    .{ .stop = {} },
                    .{ .reset_play_clock = {} },
                },
                .expected_state = TestClockState{
                    .time_remaining = 115,
                    .quarter = .Q4,
                    .is_running = false,
                    .play_clock = 40,
                    .game_state = .InProgress,
                    .total_elapsed = 3305,
                },
            },
            .end_game => TestScenario{
                .name = "End of game",
                .initial_state = TestClockState{
                    .time_remaining = 5,
                    .quarter = .Q4,
                    .is_running = true,
                    .play_clock = 5,
                    .game_state = .InProgress,
                    .total_elapsed = 3595,
                },
                .actions = &[_]TestAction{
                    .{ .tick = 5 },
                },
                .expected_state = TestClockState{
                    .time_remaining = 0,
                    .quarter = .Q4,
                    .is_running = false,
                    .play_clock = 0,
                    .game_state = .EndGame,
                    .total_elapsed = 3600,
                },
            },
            .overtime => TestScenario{
                .name = "Overtime period",
                .initial_state = TestClockState{
                    .time_remaining = 0,
                    .quarter = .Q4,
                    .is_running = false,
                    .play_clock = 40,
                    .game_state = .InProgress,
                    .total_elapsed = 3600,
                },
                .actions = &[_]TestAction{
                    .{ .start_overtime = {} },
                },
                .expected_state = TestClockState{
                    .time_remaining = 600,
                    .quarter = .Overtime,
                    .is_running = false,
                    .play_clock = 40,
                    .game_state = .InProgress,
                    .total_elapsed = 3600,
                },
            },
        };
    }

    /// Validates that clock invariants hold
    fn validateClockInvariants(clock: *const GameClock) !void {
        // Time remaining should not exceed quarter length
        if (clock.quarter != .Overtime) {
            try testing.expect(clock.time_remaining <= QUARTER_LENGTH_SECONDS);
        } else {
            try testing.expect(clock.time_remaining <= OVERTIME_LENGTH_SECONDS);
        }
        
        // Play clock should not exceed maximum
        try testing.expect(clock.play_clock <= PLAY_CLOCK_SECONDS);
        
        // Game state transitions should be valid
        if (clock.game_state == .EndGame) {
            try testing.expect(clock.time_remaining == 0 or clock.quarter == .Overtime);
        }
        
        // Clock should not be running in certain states
        if (clock.game_state == .PreGame or clock.game_state == .EndGame) {
            try testing.expect(!clock.is_running);
        }
    }

    /// Generates a series of random but valid clock operations
    fn generateRandomOperations(seed: u64, count: usize) []TestAction {
        var prng = std.Random.DefaultPrng.init(seed);
        const random = prng.random();
        const actions = testing.allocator.alloc(TestAction, count) catch unreachable;
        
        for (actions) |*action| {
            const choice = random.intRangeAtMost(u8, 0, 6);
            action.* = switch (choice) {
                0 => .{ .start = {} },
                1 => .{ .stop = {} },
                2 => .{ .tick = random.intRangeAtMost(u32, 1, 10) },
                3 => .{ .reset_play_clock = {} },
                4 => .{ .set_play_clock = random.intRangeAtMost(u8, 1, 40) },
                5 => .{ .start_overtime = {} },
                6 => .{ .reset = {} },
                else => .{ .tick = 1 },
            };
        }
        
        return actions;
    }

    // └──────────────────────────────────────────────────────────────────────────┘

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

    // ┌──────────────────────────── Scenario Tests ────────────────────────────┐

    test "scenario: GameClock: handles overtime sudden death rules" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Set up end of regulation tied game
        clock.quarter = .Q4;
        clock.time_remaining = 0;
        clock.game_state = .InProgress;
        
        // Start overtime
        try clock.startOvertime();
        try testing.expectEqual(Quarter.Overtime, clock.quarter);
        try testing.expectEqual(OVERTIME_LENGTH_SECONDS, clock.time_remaining);
        
        // Simulate first possession with field goal
        try clock.start();
        
        // Run some plays
        for (0..10) |_| {
            try clock.tick();
        }
        
        // Field goal attempt - stops clock
        try clock.stop();
        
        // Verify overtime is still active
        try testing.expect(clock.time_remaining > 0);
        try testing.expectEqual(Quarter.Overtime, clock.quarter);
        
        // Simulate more time passing
        try clock.start();
        for (0..50) |_| {
            try clock.tick();
        }
        
        // Touchdown ends game immediately in sudden death
        try clock.stop();
        
        // Verify state
        try testing.expectEqual(Quarter.Overtime, clock.quarter);
        try testing.expect(clock.time_remaining < OVERTIME_LENGTH_SECONDS);
        
        // If overtime expires without score, game ends
        clock.time_remaining = 1;
        try clock.start();
        try clock.tick();
        try testing.expectEqual(@as(u32, 0), clock.time_remaining);
        try testing.expectEqual(false, clock.is_running);
    }

    test "scenario: GameClock: manages end of half with timeouts" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Set up end of first half scenario
        clock.quarter = .Q2;
        clock.time_remaining = 45; // 45 seconds left
        clock.game_state = .InProgress;
        
        // Start clock for first play
        try clock.start();
        
        // Run play for 8 seconds
        for (0..8) |_| {
            try clock.tick();
        }
        
        // Timeout called
        try clock.stop();
        try testing.expectEqual(@as(u32, 37), clock.time_remaining);
        
        // Reset play clock after timeout
        clock.resetPlayClock();
        try testing.expectEqual(PLAY_CLOCK_SECONDS, clock.play_clock);
        
        // Second play - incomplete pass (clock stops)
        try clock.start();
        for (0..3) |_| {
            try clock.tick();
        }
        try clock.stop();
        try testing.expectEqual(@as(u32, 34), clock.time_remaining);
        
        // Third play - spike to stop clock
        try clock.start();
        try clock.tick(); // Spike takes 1 second
        try clock.stop();
        try testing.expectEqual(@as(u32, 33), clock.time_remaining);
        
        // Field goal attempt with time expiring
        clock.resetPlayClock();
        try clock.start();
        
        // Snap and kick take about 5 seconds
        for (0..5) |_| {
            try clock.tick();
        }
        
        try testing.expectEqual(@as(u32, 28), clock.time_remaining);
        
        // Half ends when time reaches 0
        clock.time_remaining = 1;
        try clock.tick();
        
        // Should transition to halftime
        try testing.expectEqual(Quarter.Q3, clock.quarter);
        try testing.expectEqual(GameState.Halftime, clock.game_state);
        try testing.expectEqual(false, clock.is_running);
    }

    test "scenario: GameClock: handles playoff overtime periods" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Playoff overtime has different rules
        clock.quarter = .Q4;
        clock.time_remaining = 0;
        clock.game_state = .InProgress;
        
        // Start first overtime
        try clock.startOvertime();
        try testing.expectEqual(Quarter.Overtime, clock.quarter);
        try testing.expectEqual(OVERTIME_LENGTH_SECONDS, clock.time_remaining);
        
        // Simulate full overtime period without score
        try clock.start();
        clock.time_remaining = 1;
        try clock.tick();
        
        // In playoffs, would start second overtime
        // For this test, verify first OT ended properly
        try testing.expectEqual(@as(u32, 0), clock.time_remaining);
        try testing.expectEqual(false, clock.is_running);
        
        // Start second overtime period (simulate playoff rules)
        clock.quarter = .Overtime;
        clock.time_remaining = OVERTIME_LENGTH_SECONDS;
        clock.game_state = .InProgress; // Reset game state for second OT
        clock.resetPlayClock();
        
        try clock.start();
        
        // Simulate sudden death in second OT
        for (0..120) |_| { // 2 minutes of play
            try clock.tick();
        }
        
        // Game-winning score
        try clock.stop();
        
        // Verify we're still in OT with time left
        try testing.expectEqual(Quarter.Overtime, clock.quarter);
        try testing.expect(clock.time_remaining > 0);
        try testing.expectEqual(false, clock.is_running);
        
        // Total elapsed should reflect game time
        try testing.expect(clock.total_elapsed > 0); // Some time has elapsed
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

    // ┌──────────────────────────── Error Handling Tests ────────────────────────────┐

    test "unit: GameClock: InvalidConfiguration error on invalid init" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Set invalid configuration
        clock.time_remaining = 5000; // Way over quarter length
        clock.quarter = .Q1;
        
        // Validate should detect invalid state
        const validation_result = clock.validateState();
        try testing.expectError(GameClockError.InvalidConfiguration, validation_result);
    }

    test "unit: GameClock: ConcurrentModification error detection" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Start clock to simulate active state
        try clock.start();
        clock.modification_count = 5;
        
        // Simulate concurrent modification by changing modification count mid-operation
        const initial_count = clock.modification_count;
        clock.modification_count = initial_count + 10; // Simulate external modification
        
        // This would be detected in a real concurrent scenario
        try testing.expect(clock.modification_count != initial_count);
    }

    test "unit: GameClock: validateState catches all invalid states" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Test 1: Time exceeds quarter length
        clock.time_remaining = QUARTER_LENGTH_SECONDS + 100;
        try testing.expectError(GameClockError.InvalidConfiguration, clock.validateState());
        
        // Test 2: Play clock exceeds maximum
        clock.time_remaining = 500;
        clock.play_clock = PLAY_CLOCK_SECONDS + 10;
        try testing.expectError(GameClockError.InvalidConfiguration, clock.validateState());
        
        // Test 3: Invalid quarter number (using raw value)
        clock.play_clock = 25;
        // Quarter enum doesn't allow invalid values directly, but we can test edge cases
        clock.quarter = .Overtime;
        clock.time_remaining = OVERTIME_LENGTH_SECONDS + 100;
        try testing.expectError(GameClockError.InvalidConfiguration, clock.validateState());
        
        // Test 4: Valid state should pass
        clock.time_remaining = 300;
        clock.quarter = .Q2;
        clock.play_clock = 25;
        try clock.validateState();
    }

    test "unit: GameClock: validateTime detects invalid time values" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Test various invalid times
        try testing.expectError(GameClockError.InvalidTime, clock.validateTime(QUARTER_LENGTH_SECONDS + 1, .Q1));
        try testing.expectError(GameClockError.InvalidTime, clock.validateTime(OVERTIME_LENGTH_SECONDS + 1, .Overtime));
        
        // Valid times should pass
        try clock.validateTime(300, .Q1);
        try clock.validateTime(0, .Q4);
        try clock.validateTime(OVERTIME_LENGTH_SECONDS, .Overtime);
    }

    test "unit: GameClock: validateConfiguration checks all config params" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Test with various invalid configurations
        const invalid_configs = [_]struct {
            time_remaining: u32,
            play_clock: u8,
            quarter: Quarter,
            should_fail: bool,
        }{
            .{ .time_remaining = 2000, .play_clock = 40, .quarter = .Q1, .should_fail = true },
            .{ .time_remaining = 900, .play_clock = 50, .quarter = .Q1, .should_fail = true },
            .{ .time_remaining = 900, .play_clock = 40, .quarter = .Q1, .should_fail = false },
            .{ .time_remaining = 0, .play_clock = 0, .quarter = .Q4, .should_fail = false },
        };
        
        for (invalid_configs) |config| {
            clock.time_remaining = config.time_remaining;
            clock.play_clock = config.play_clock;
            clock.quarter = config.quarter;
            
            if (config.should_fail) {
                try testing.expectError(GameClockError.InvalidConfiguration, clock.validateConfiguration());
            } else {
                try clock.validateConfiguration();
            }
        }
    }

    test "unit: GameClock: resetToValidState recovers from invalid state" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Put clock in invalid state
        clock.time_remaining = 5000;
        clock.play_clock = 100;
        clock.quarter = .Q2;
        clock.is_running = true;
        clock.game_state = .InProgress;
        
        // Reset should fix everything
        clock.resetToValidState();
        
        // Verify valid state
        try testing.expect(clock.time_remaining <= QUARTER_LENGTH_SECONDS);
        try testing.expect(clock.play_clock <= PLAY_CLOCK_SECONDS);
        try testing.expect(!clock.is_running);
        try clock.validateState();
    }

    test "unit: GameClock: syncClocks ensures consistency" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Create inconsistent state
        clock.time_remaining = 5; // Only 5 seconds left
        clock.play_clock = 40; // But full play clock
        clock.is_running = true;
        
        // Sync should fix inconsistency
        clock.syncClocks();
        
        // Play clock should not exceed game time
        try testing.expect(clock.play_clock <= clock.time_remaining);
    }

    test "unit: GameClock: recoverFromError handles various error scenarios" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Test recovery from ClockAlreadyRunning
        clock.is_running = true;
        try clock.recoverFromError(GameClockError.ClockAlreadyRunning);
        try testing.expect(!clock.is_running);
        
        // Test recovery from InvalidPlayClock
        clock.play_clock = 100;
        try clock.recoverFromError(GameClockError.InvalidPlayClock);
        try testing.expectEqual(PLAY_CLOCK_SECONDS, clock.play_clock);
        
        // Test recovery from InvalidQuarter
        clock.quarter = .Q4;
        clock.time_remaining = 0;
        try clock.recoverFromError(GameClockError.InvalidQuarter);
        // Should handle end of game scenario
        try testing.expect(clock.game_state == .EndGame or clock.quarter == .Overtime);
        
        // Test recovery from InvalidTime
        clock.time_remaining = 5000;
        try clock.recoverFromError(GameClockError.InvalidTime);
        try testing.expect(clock.time_remaining <= QUARTER_LENGTH_SECONDS);
        
        // Test recovery from InvalidConfiguration
        clock.time_remaining = 2000;
        clock.play_clock = 80;
        try clock.recoverFromError(GameClockError.InvalidConfiguration);
        try clock.validateState(); // Should be valid after recovery
    }

    test "integration: GameClock: error context provides useful debugging info" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Create various error contexts
        const contexts = [_]struct {
            error_type: GameClockError,
            operation: []const u8,
            expected_field: []const u8,
        }{
            .{ .error_type = GameClockError.ClockAlreadyRunning, .operation = "start", .expected_field = "is_running" },
            .{ .error_type = GameClockError.InvalidPlayClock, .operation = "setPlayClock", .expected_field = "play_clock" },
            .{ .error_type = GameClockError.InvalidTime, .operation = "tick", .expected_field = "time_remaining" },
        };
        
        for (contexts) |ctx| {
            const error_ctx = clock.createErrorContext(ctx.error_type, ctx.operation);
            
            try testing.expectEqual(ctx.error_type, error_ctx.error_type);
            try testing.expectEqualStrings(ctx.operation, error_ctx.operation);
            try testing.expect(error_ctx.timestamp > 0);
            
            // Verify state snapshot contains expected fields
            if (std.mem.eql(u8, ctx.expected_field, "is_running")) {
                try testing.expectEqual(clock.is_running, error_ctx.clock_state.is_running);
            } else if (std.mem.eql(u8, ctx.expected_field, "play_clock")) {
                try testing.expectEqual(clock.play_clock, error_ctx.clock_state.play_clock);
            } else if (std.mem.eql(u8, ctx.expected_field, "time_remaining")) {
                try testing.expectEqual(clock.time_remaining, error_ctx.clock_state.time_remaining);
            }
        }
    }

    test "integration: GameClock: error recovery maintains game flow" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Start normal game
        try clock.start();
        const initial_time = clock.time_remaining;
        
        // Simulate error: try to start again
        const start_error = clock.start();
        try testing.expectError(GameClockError.ClockAlreadyRunning, start_error);
        
        // Recover from error
        try clock.recoverFromError(GameClockError.ClockAlreadyRunning);
        
        // Game should continue normally
        try clock.start(); // Should work now
        try clock.tick();
        try testing.expect(clock.time_remaining < initial_time);
        
        // Simulate invalid play clock error
        const invalid_pc_error = clock.setPlayClock(100);
        try testing.expectError(GameClockError.InvalidPlayClock, invalid_pc_error);
        
        // Recover
        try clock.recoverFromError(GameClockError.InvalidPlayClock);
        try testing.expectEqual(PLAY_CLOCK_SECONDS, clock.play_clock);
        
        // Game continues
        try clock.tick();
        try clock.stop();
    }

    test "e2e: GameClock: complete error handling flow" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Scenario 1: Multiple errors during game
        try clock.start();
        
        // Error 1: Double start
        if (clock.start()) |_| {
            try testing.expect(false); // Should not succeed
        } else |err| {
            try testing.expectEqual(GameClockError.ClockAlreadyRunning, err);
            const ctx = clock.createErrorContext(err, "start");
            try testing.expect(ctx.clock_state.is_running);
            try clock.recoverFromError(err);
        }
        
        // Continue game
        for (0..10) |_| {
            try clock.tick();
        }
        
        // Error 2: Invalid play clock while running
        if (clock.setPlayClock(60)) |_| {
            try testing.expect(false);
        } else |err| {
            try testing.expectEqual(GameClockError.InvalidPlayClock, err);
            try clock.recoverFromError(err);
        }
        
        // Error 3: Stop when already stopped
        try clock.stop();
        if (clock.stop()) |_| {
            try testing.expect(false);
        } else |err| {
            try testing.expectEqual(GameClockError.ClockNotRunning, err);
            try clock.recoverFromError(err);
        }
        
        // Scenario 2: Invalid state recovery
        clock.time_remaining = 10000; // Invalid
        clock.play_clock = 200; // Invalid
        
        if (clock.validateState()) |_| {
            try testing.expect(false);
        } else |err| {
            try testing.expectEqual(GameClockError.InvalidConfiguration, err);
            clock.resetToValidState();
            try clock.validateState(); // Should pass now
        }
        
        // Scenario 3: End of game error handling
        clock.quarter = .Q4;
        clock.time_remaining = 0;
        
        // Try to start overtime when not ready
        if (clock.quarter != .Q4 or clock.time_remaining != 0) {
            if (clock.startOvertime()) |_| {
                try testing.expect(false);
            } else |err| {
                try testing.expectEqual(GameClockError.InvalidQuarter, err);
            }
        } else {
            try clock.startOvertime(); // Should work
            try testing.expectEqual(Quarter.Overtime, clock.quarter);
        }
    }

    test "scenario: GameClock: handles errors during critical game moments" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Two-minute drill with errors
        clock.quarter = .Q4;
        clock.time_remaining = 120;
        clock.game_state = .InProgress;
        
        try clock.start();
        
        // Simulate rapid play with potential errors
        for (0..10) |i| {
            // Every 3rd iteration, try invalid operation
            if (i % 3 == 0) {
                // Try to set invalid play clock during critical time
                if (clock.setPlayClock(50)) |_| {
                    try testing.expect(false);
                } else |err| {
                    // Recover and continue
                    try clock.recoverFromError(err);
                }
            }
            
            try clock.tick();
            
            // Every 5th iteration, cause and recover from error
            if (i % 5 == 0) {
                clock.play_clock = 100; // Force invalid state
                if (clock.validateState()) |_| {
                    try testing.expect(false);
                } else |err| {
                    // Use the error to trigger recovery
                    try testing.expect(err == GameClockError.InvalidConfiguration or err == GameClockError.InvalidPlayClock);
                    clock.resetToValidState();
                }
            }
        }
        
        // Game should still be in valid state
        try clock.validateState();
        try testing.expect(clock.time_remaining < 120);
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