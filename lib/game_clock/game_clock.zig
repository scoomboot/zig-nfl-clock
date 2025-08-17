// game_clock.zig — Core implementation of the NFL game clock
//
// repo   : https://github.com/zig-nfl-clock
// docs   : https://zig-nfl-clock.github.io/docs/lib/game_clock/game_clock
// author : https://github.com/maysara-elshewehy
//
// Vibe coded by Scoom.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const Allocator = std.mem.Allocator;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    /// NFL game quarter periods
    pub const Quarter = enum(u8) {
        Q1 = 1,
        Q2 = 2,
        Q3 = 3,
        Q4 = 4,
        Overtime = 5,

        /// Returns the display string for the quarter.
        ///
        /// Provides human-readable quarter names.
        ///
        /// __Parameters__
        ///
        /// - `self`: The quarter enum value
        ///
        /// __Return__
        ///
        /// - String representation of the quarter
        pub fn toString(self: Quarter) []const u8 {
            return switch (self) {
                .Q1 => "1st Quarter",
                .Q2 => "2nd Quarter",
                .Q3 => "3rd Quarter",
                .Q4 => "4th Quarter",
                .Overtime => "Overtime",
            };
        }
    };

    /// Game state transitions
    pub const GameState = enum {
        PreGame,
        InProgress,
        Halftime,
        EndGame,

        /// Checks if the game is active.
        ///
        /// Determines if the game clock should be running.
        ///
        /// __Parameters__
        ///
        /// - `self`: The game state enum value
        ///
        /// __Return__
        ///
        /// - Boolean indicating if game is active
        pub fn isActive(self: GameState) bool {
            return self == .InProgress;
        }
    };

    /// Error set for game clock operations
    pub const GameClockError = error{
        InvalidQuarter,
        InvalidTimeRemaining,
        InvalidPlayClock,
        ClockAlreadyRunning,
        ClockNotRunning,
        GameNotStarted,
        GameAlreadyEnded,
        TimeExpired,
    };

    /// Constants for NFL game timing
    pub const QUARTER_LENGTH_SECONDS: u32 = 15 * 60; // 15 minutes
    pub const PLAY_CLOCK_SECONDS: u8 = 40; // 40 seconds standard
    pub const OVERTIME_LENGTH_SECONDS: u32 = 10 * 60; // 10 minutes

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    /// NFL Game Clock implementation
    pub const GameClock = struct {
        /// Time remaining in current quarter (in seconds)
        time_remaining: u32,
        
        /// Current quarter
        quarter: Quarter,
        
        /// Clock running state
        is_running: bool,
        
        /// Play clock time (in seconds)
        play_clock: u8,
        
        /// Current game state
        game_state: GameState,
        
        /// Total elapsed game time (in seconds)
        total_elapsed: u64,
        
        /// Allocator for dynamic memory (if needed)
        allocator: Allocator,

        /// Initialize a new game clock.
        ///
        /// Creates a new game clock with default NFL settings.
        ///
        /// __Parameters__
        ///
        /// - `allocator`: Memory allocator for dynamic allocations
        ///
        /// __Return__
        ///
        /// - Initialized GameClock instance
        pub fn init(allocator: Allocator) GameClock {
            return GameClock{
                .time_remaining = QUARTER_LENGTH_SECONDS,
                .quarter = .Q1,
                .is_running = false,
                .play_clock = PLAY_CLOCK_SECONDS,
                .game_state = .PreGame,
                .total_elapsed = 0,
                .allocator = allocator,
            };
        }

        /// Start the game clock.
        ///
        /// Begins the game clock countdown and transitions from PreGame state.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to GameClock
        ///
        /// __Return__
        ///
        /// - Error if clock already running or game ended
        pub fn start(self: *GameClock) GameClockError!void {
            if (self.is_running) {
                return GameClockError.ClockAlreadyRunning;
            }
            
            if (self.game_state == .EndGame) {
                return GameClockError.GameAlreadyEnded;
            }
            
            if (self.game_state == .PreGame) {
                self.game_state = .InProgress;
            }
            
            self.is_running = true;
        }

        /// Stop the game clock.
        ///
        /// Pauses the game clock countdown.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to GameClock
        ///
        /// __Return__
        ///
        /// - Error if clock not running
        pub fn stop(self: *GameClock) GameClockError!void {
            if (!self.is_running) {
                return GameClockError.ClockNotRunning;
            }
            
            self.is_running = false;
        }

        /// Advance the clock by one second.
        ///
        /// Updates both game clock and play clock, handles quarter transitions.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to GameClock
        ///
        /// __Return__
        ///
        /// - Error if quarter transition fails
        pub fn tick(self: *GameClock) GameClockError!void {
            if (!self.is_running) {
                return;
            }
            
            // Decrement play clock
            if (self.play_clock > 0) {
                self.play_clock -= 1;
            }
            
            // Decrement game clock
            if (self.time_remaining > 0) {
                self.time_remaining -= 1;
                self.total_elapsed += 1;
            }
            
            // Handle quarter transitions
            if (self.time_remaining == 0) {
                try self.advanceQuarter();
            }
        }

        /// Reset the game clock to initial state.
        ///
        /// Restores all clock values to their defaults.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to GameClock
        ///
        /// __Return__
        ///
        /// - void
        pub fn reset(self: *GameClock) void {
            self.time_remaining = QUARTER_LENGTH_SECONDS;
            self.quarter = .Q1;
            self.is_running = false;
            self.play_clock = PLAY_CLOCK_SECONDS;
            self.game_state = .PreGame;
            self.total_elapsed = 0;
        }

        /// Reset the play clock.
        ///
        /// Restores play clock to default 40 seconds.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to GameClock
        ///
        /// __Return__
        ///
        /// - void
        pub fn resetPlayClock(self: *GameClock) void {
            self.play_clock = PLAY_CLOCK_SECONDS;
        }

        /// Set play clock to specific value.
        ///
        /// Updates play clock with validation.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to GameClock
        /// - `seconds`: New play clock value in seconds
        ///
        /// __Return__
        ///
        /// - Error if value exceeds maximum play clock time
        pub fn setPlayClock(self: *GameClock, seconds: u8) GameClockError!void {
            if (seconds > PLAY_CLOCK_SECONDS) {
                return GameClockError.InvalidPlayClock;
            }
            self.play_clock = seconds;
        }

        // ┌──────────────────────────── Private Methods ────────────────────────────┐

            /// Advance to the next quarter
            fn advanceQuarter(self: *GameClock) GameClockError!void {
                self.is_running = false;
                
                switch (self.quarter) {
                    .Q1 => {
                        self.quarter = .Q2;
                        self.time_remaining = QUARTER_LENGTH_SECONDS;
                    },
                    .Q2 => {
                        self.quarter = .Q3;
                        self.time_remaining = QUARTER_LENGTH_SECONDS;
                        self.game_state = .Halftime;
                    },
                    .Q3 => {
                        self.quarter = .Q4;
                        self.time_remaining = QUARTER_LENGTH_SECONDS;
                        if (self.game_state == .Halftime) {
                            self.game_state = .InProgress;
                        }
                    },
                    .Q4 => {
                        // Game ends or goes to overtime
                        // This would typically check the score
                        self.game_state = .EndGame;
                    },
                    .Overtime => {
                        self.game_state = .EndGame;
                    },
                }
            }

        // └──────────────────────────────────────────────────────────────────────────┘

        /// Start overtime period.
        ///
        /// Transitions game to overtime after regulation.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to GameClock
        ///
        /// __Return__
        ///
        /// - Error if not at end of regulation
        pub fn startOvertime(self: *GameClock) GameClockError!void {
            if (self.quarter != .Q4 or self.time_remaining != 0) {
                return GameClockError.InvalidQuarter;
            }
            
            self.quarter = .Overtime;
            self.time_remaining = OVERTIME_LENGTH_SECONDS;
            self.game_state = .InProgress;
            self.is_running = false;
        }

        /// Get formatted time string (MM:SS).
        ///
        /// Formats remaining time for display.
        ///
        /// __Parameters__
        ///
        /// - `self`: Const reference to GameClock
        /// - `buffer`: Output buffer for formatted string
        ///
        /// __Return__
        ///
        /// - Formatted time string
        pub fn getTimeString(self: *const GameClock, buffer: []u8) []u8 {
            const minutes = self.time_remaining / 60;
            const seconds = self.time_remaining % 60;
            return std.fmt.bufPrint(buffer, "{d:0>2}:{d:0>2}", .{ minutes, seconds }) catch "00:00";
        }

        /// Get current quarter string.
        ///
        /// Returns human-readable quarter name.
        ///
        /// __Parameters__
        ///
        /// - `self`: Const reference to GameClock
        ///
        /// __Return__
        ///
        /// - Quarter display string
        pub fn getQuarterString(self: *const GameClock) []const u8 {
            return self.quarter.toString();
        }

        /// Check if play clock has expired.
        ///
        /// Determines if delay of game penalty should be called.
        ///
        /// __Parameters__
        ///
        /// - `self`: Const reference to GameClock
        ///
        /// __Return__
        ///
        /// - Boolean indicating play clock expiration
        pub fn isPlayClockExpired(self: *const GameClock) bool {
            return self.play_clock == 0;
        }

        /// Check if quarter has ended.
        ///
        /// Determines if current quarter time has expired.
        ///
        /// __Parameters__
        ///
        /// - `self`: Const reference to GameClock
        ///
        /// __Return__
        ///
        /// - Boolean indicating quarter end
        pub fn isQuarterEnded(self: *const GameClock) bool {
            return self.time_remaining == 0;
        }

        /// Get total game time elapsed.
        ///
        /// Returns cumulative time since game start.
        ///
        /// __Parameters__
        ///
        /// - `self`: Const reference to GameClock
        ///
        /// __Return__
        ///
        /// - Total elapsed seconds
        pub fn getTotalElapsedTime(self: *const GameClock) u64 {
            return self.total_elapsed;
        }
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "unit: GameClock: initialization" {
        const allocator = testing.allocator;
        const clock = GameClock.init(allocator);
        
        try testing.expectEqual(QUARTER_LENGTH_SECONDS, clock.time_remaining);
        try testing.expectEqual(Quarter.Q1, clock.quarter);
        try testing.expectEqual(false, clock.is_running);
        try testing.expectEqual(PLAY_CLOCK_SECONDS, clock.play_clock);
        try testing.expectEqual(GameState.PreGame, clock.game_state);
    }

    test "unit: GameClock: start and stop" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Start the clock
        try clock.start();
        try testing.expectEqual(true, clock.is_running);
        try testing.expectEqual(GameState.InProgress, clock.game_state);
        
        // Try to start again (should error)
        try testing.expectError(GameClockError.ClockAlreadyRunning, clock.start());
        
        // Stop the clock
        try clock.stop();
        try testing.expectEqual(false, clock.is_running);
        
        // Try to stop again (should error)
        try testing.expectError(GameClockError.ClockNotRunning, clock.stop());
    }

    test "unit: GameClock: tick functionality" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        try clock.start();
        const initial_time = clock.time_remaining;
        const initial_play_clock = clock.play_clock;
        
        try clock.tick();
        
        try testing.expectEqual(initial_time - 1, clock.time_remaining);
        try testing.expectEqual(initial_play_clock - 1, clock.play_clock);
        try testing.expectEqual(@as(u64, 1), clock.total_elapsed);
    }

    test "unit: GameClock: play clock operations" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Reset play clock
        clock.play_clock = 10;
        clock.resetPlayClock();
        try testing.expectEqual(PLAY_CLOCK_SECONDS, clock.play_clock);
        
        // Set play clock
        try clock.setPlayClock(25);
        try testing.expectEqual(@as(u8, 25), clock.play_clock);
        
        // Invalid play clock value
        try testing.expectError(GameClockError.InvalidPlayClock, clock.setPlayClock(50));
    }

    test "unit: GameClock: quarter transitions" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        try clock.start();
        
        // Simulate end of Q1
        clock.time_remaining = 1;
        try clock.tick();
        try testing.expectEqual(Quarter.Q2, clock.quarter);
        try testing.expectEqual(QUARTER_LENGTH_SECONDS, clock.time_remaining);
        try testing.expectEqual(false, clock.is_running);
    }

    test "unit: GameClock: time formatting" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        var buffer: [16]u8 = undefined;
        
        // Test initial time (15:00)
        const time_str = clock.getTimeString(&buffer);
        try testing.expectEqualStrings("15:00", time_str);
        
        // Test with different time
        clock.time_remaining = 125; // 2:05
        const time_str2 = clock.getTimeString(&buffer);
        try testing.expectEqualStrings("02:05", time_str2);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝