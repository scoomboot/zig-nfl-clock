// game_clock.zig — Main entry point for the NFL game clock library
//
// repo   : https://github.com/zig-nfl-clock
// docs   : https://zig-nfl-clock.github.io/docs/lib/game_clock
// author : https://github.com/maysara-elshewehy
//
// Vibe coded by Scoom.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");

    // Re-export the core game clock implementation
    pub const GameClock = @import("game_clock/game_clock.zig").GameClock;
    pub const GameClockError = @import("game_clock/game_clock.zig").GameClockError;
    pub const Quarter = @import("game_clock/game_clock.zig").Quarter;
    pub const GameState = @import("game_clock/game_clock.zig").GameState;

    // Re-export utility functions if any
    // Note: formatTime is not available in the current implementation

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    /// Create a new game clock instance with default NFL settings.
    ///
    /// Initializes a game clock with standard NFL timing rules.
    ///
    /// __Parameters__
    ///
    /// - `allocator`: Memory allocator for dynamic allocations
    ///
    /// __Return__
    ///
    /// - GameClock instance or error if initialization fails
    pub fn createGameClock(allocator: std.mem.Allocator) !GameClock {
        return GameClock.init(allocator);
    }

    /// Get the version of the game clock library.
    ///
    /// Returns the current semantic version of the library.
    ///
    /// __Parameters__
    ///
    /// - None
    ///
    /// __Return__
    ///
    /// - Version string in semantic versioning format
    pub fn version() []const u8 {
        return "0.1.0";
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "unit: game_clock: library exports" {
        const testing = std.testing;

        // Verify that all expected exports are available
        _ = GameClock;
        _ = GameClockError;
        _ = Quarter;
        _ = GameState;
        _ = createGameClock;
        _ = version;

        // Basic version check
        try testing.expect(version().len > 0);
    }

    test "unit: game_clock: create instance" {
        const testing = std.testing;
        const allocator = testing.allocator;

        // Test that we can create a game clock instance through the public API
        const clock = try createGameClock(allocator);
        defer clock.deinit();

        // Verify initial state - using actual available fields/methods
        try testing.expectEqual(Quarter.Q1, clock.quarter);
        try testing.expectEqual(GameState.PreGame, clock.state);
    }

    // Import all test files to ensure they run with `zig build test`
    test {
        _ = @import("game_clock/game_clock.test.zig");
        _ = @import("game_clock/utils/time_formatter/time_formatter.test.zig");
        _ = @import("game_clock/utils/rules_engine/rules_engine.test.zig");
        _ = @import("game_clock/utils/play_handler/play_handler.test.zig");
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝