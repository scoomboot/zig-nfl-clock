// test_error_handling.zig — Simplified error handling tests
//
// This file tests the actual error handling implementation that exists
// in the codebase, not the hypothetical extended API.

const std = @import("std");
const testing = std.testing;

// Import modules
const game_clock = @import("lib/game_clock.zig");
const GameClock = game_clock.GameClock;
const GameClockError = game_clock.GameClockError;

test "GameClock: error handling basics" {
    const allocator = testing.allocator;
    var clock = GameClock.init(allocator);
    
    // Test ClockAlreadyRunning error
    try clock.start();
    try testing.expectError(GameClockError.ClockAlreadyRunning, clock.start());
    
    // Test ClockNotRunning error
    try clock.stop();
    try testing.expectError(GameClockError.ClockNotRunning, clock.stop());
    
    // Test InvalidPlayClock error
    try testing.expectError(GameClockError.InvalidPlayClock, clock.setPlayClock(50));
    
    // Test InvalidQuarter error for overtime
    clock.quarter = .Q3; // Not Q4
    clock.time_remaining = 100;
    try testing.expectError(GameClockError.InvalidQuarter, clock.startOvertime());
}

test "GameClock: state validation" {
    const allocator = testing.allocator;
    var clock = GameClock.init(allocator);
    
    // Put clock in invalid state
    clock.time_remaining = 5000; // Way over quarter length
    clock.play_clock = 100; // Over max
    
    // Validate should fail
    try testing.expectError(GameClockError.InvalidConfiguration, clock.validateState());
    
    // Reset to valid state
    clock.resetToValidState();
    
    // Should pass now
    try clock.validateState();
}

test "GameClock: recovery functions" {
    const allocator = testing.allocator;
    var clock = GameClock.init(allocator);
    
    // Test resetToValidState
    clock.time_remaining = 5000;
    clock.play_clock = 100;
    clock.resetToValidState();
    try testing.expect(clock.time_remaining <= 900);
    try testing.expect(clock.play_clock <= 40);
    
    // Test syncClocks
    clock.time_remaining = 5;
    clock.play_clock = 40;
    clock.syncClocks();
    try testing.expect(clock.play_clock <= clock.time_remaining);
    
    // Test recoverFromError
    clock.is_running = true;
    clock.recoverFromError(GameClockError.ClockAlreadyRunning);
    try testing.expect(!clock.is_running);
}

test "RulesEngine: basic error handling" {
    const rules_engine = @import("lib/game_clock/utils/rules_engine.zig");
    const RulesEngine = rules_engine.RulesEngine;
    
    var engine = RulesEngine.init();
    
    // Test NoTimeoutsRemaining error
    engine.situation.home_timeouts = 0;
    try testing.expectError(error.NoTimeoutsRemaining, engine.useTimeout(.home));
    
    // Test validation
    engine.situation.down = 5; // Invalid
    try testing.expectError(error.InvalidSituation, engine.validateSituation());
    
    // Fix and continue
    engine.situation.down = 1;
    try engine.validateSituation();
}

test "PlayHandler: basic error handling" {
    const play_handler = @import("lib/game_clock/utils/play_handler.zig");
    const PlayHandler = play_handler.PlayHandler;
    
    var handler = PlayHandler.init(12345);
    
    // Test validation
    handler.game_state.down = 0; // Invalid
    try testing.expectError(error.InvalidGameState, handler.validateGameState());
    
    // Fix and validate
    handler.game_state.down = 1;
    try handler.validateGameState();
    
    // Test statistics validation
    handler.home_stats.turnovers = 100;
    handler.home_stats.plays_run = 10; // Can't have more turnovers than plays
    try testing.expectError(error.InvalidStatistics, handler.validateStatistics());
}

test "TimeFormatter: basic error handling" {
    const time_formatter = @import("lib/game_clock/utils/time_formatter.zig");
    const TimeFormatter = time_formatter.TimeFormatter;
    const WarningThresholds = time_formatter.WarningThresholds;
    
    const allocator = testing.allocator;
    var formatter = TimeFormatter.init(allocator);
    
    // Test threshold validation
    const bad_thresholds = WarningThresholds{
        .play_clock_warning = 50, // Over max
        .quarter_warning = 120,
        .critical_time = 10,
    };
    
    try testing.expectError(error.InvalidThresholds, formatter.validateThresholds(bad_thresholds));
    
    // Test with valid thresholds
    const good_thresholds = WarningThresholds{
        .play_clock_warning = 5,
        .quarter_warning = 120,
        .critical_time = 3,
    };
    
    try formatter.validateThresholds(good_thresholds);
}