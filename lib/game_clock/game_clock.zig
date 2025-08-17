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

    /// Clock running state
    pub const ClockState = enum {
        stopped,
        running,
        expired,

        /// Check if clock is actively running.
        ///
        /// Determines if clock is in a running state.
        ///
        /// __Parameters__
        ///
        /// - `self`: The clock state enum value
        ///
        /// __Return__
        ///
        /// - Boolean indicating if clock is running
        pub fn isRunning(self: ClockState) bool {
            return self == .running;
        }
    };

    /// Play clock state tracking
    pub const PlayClockState = enum {
        inactive,
        active,
        warning,
        expired,

        /// Check if play clock is actively counting down.
        ///
        /// Determines if play clock should be ticking.
        ///
        /// __Parameters__
        ///
        /// - `self`: The play clock state enum value
        ///
        /// __Return__
        ///
        /// - Boolean indicating if play clock is active
        pub fn isActive(self: PlayClockState) bool {
            return self == .active or self == .warning;
        }
    };

    /// Play clock duration options
    pub const PlayClockDuration = enum {
        normal_40,
        short_25,

        /// Get the duration in seconds.
        ///
        /// Returns the number of seconds for this duration.
        ///
        /// __Parameters__
        ///
        /// - `self`: The play clock duration enum value
        ///
        /// __Return__
        ///
        /// - Duration in seconds
        pub fn toSeconds(self: PlayClockDuration) u8 {
            return switch (self) {
                .normal_40 => 40,
                .short_25 => 25,
            };
        }
    };

    /// Clock stopping reasons for NFL rules
    pub const ClockStoppingReason = enum {
        timeout,
        out_of_bounds,
        incomplete_pass,
        penalty,
        injury,
        change_of_possession,
        two_minute_warning,
        quarter_end,
        first_down,
        score,
        manual,
        official_timeout,

        /// Check if this reason stops the game clock.
        ///
        /// Determines if game clock should stop for this reason.
        ///
        /// __Parameters__
        ///
        /// - `self`: The stopping reason enum value
        ///
        /// __Return__
        ///
        /// - Boolean indicating if clock should stop
        pub fn stopsGameClock(self: ClockStoppingReason) bool {
            return switch (self) {
                .timeout, .out_of_bounds, .incomplete_pass, .penalty,
                .injury, .change_of_possession, .two_minute_warning,
                .quarter_end, .first_down, .score, .manual, .official_timeout => true,
            };
        }
    };

    /// Clock speed options for simulation
    pub const ClockSpeed = enum {
        real_time,
        accelerated_2x,
        accelerated_5x,
        accelerated_10x,
        accelerated_30x,
        accelerated_60x,
        custom,

        /// Get the speed multiplier.
        ///
        /// Returns the time acceleration factor.
        ///
        /// __Parameters__
        ///
        /// - `self`: The clock speed enum value
        ///
        /// __Return__
        ///
        /// - Speed multiplier factor
        pub fn getMultiplier(self: ClockSpeed) u32 {
            return switch (self) {
                .real_time => 1,
                .accelerated_2x => 2,
                .accelerated_5x => 5,
                .accelerated_10x => 10,
                .accelerated_30x => 30,
                .accelerated_60x => 60,
                .custom => 1, // Default, actual value stored separately
            };
        }
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
        
        /// Clock running state (for backward compatibility)
        is_running: bool,
        
        /// New clock state enum
        clock_state: ClockState,
        
        /// Play clock time (in seconds)
        play_clock: u8,
        
        /// Play clock state tracking
        play_clock_state: PlayClockState,
        
        /// Play clock duration type
        play_clock_duration: PlayClockDuration,
        
        /// Current game state
        game_state: GameState,
        
        /// Clock speed for simulation
        clock_speed: ClockSpeed,
        
        /// Custom speed multiplier for custom speed mode
        custom_speed_multiplier: u32,
        
        /// Two-minute warning tracking per quarter
        two_minute_warning_given: [4]bool,
        
        /// Total elapsed game time (in seconds)
        total_elapsed: u64,
        
        /// Thread safety mutex
        mutex: std.Thread.Mutex,
        
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
                .clock_state = .stopped,
                .play_clock = PLAY_CLOCK_SECONDS,
                .play_clock_state = .inactive,
                .play_clock_duration = .normal_40,
                .game_state = .PreGame,
                .clock_speed = .real_time,
                .custom_speed_multiplier = 1,
                .two_minute_warning_given = [_]bool{false} ** 4,
                .total_elapsed = 0,
                .mutex = std.Thread.Mutex{},
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
            self.mutex.lock();
            defer self.mutex.unlock();
            
            if (self.is_running or self.clock_state == .running) {
                return GameClockError.ClockAlreadyRunning;
            }
            
            if (self.game_state == .EndGame) {
                return GameClockError.GameAlreadyEnded;
            }
            
            if (self.game_state == .PreGame) {
                self.game_state = .InProgress;
            }
            
            // Update both fields for backward compatibility
            self.is_running = true;
            self.clock_state = .running;
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
            self.mutex.lock();
            defer self.mutex.unlock();
            
            if (!self.is_running and self.clock_state != .running) {
                return GameClockError.ClockNotRunning;
            }
            
            // Update both fields for backward compatibility
            self.is_running = false;
            self.clock_state = .stopped;
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
            self.mutex.lock();
            defer self.mutex.unlock();
            
            if (!self.is_running or self.clock_state != .running) {
                return;
            }
            
            // Decrement play clock with state tracking
            if (self.play_clock > 0 and self.play_clock_state.isActive()) {
                self.play_clock -= 1;
                
                // Update play clock state based on time remaining
                if (self.play_clock == 0) {
                    self.play_clock_state = .expired;
                } else if (self.play_clock <= 5) {
                    self.play_clock_state = .warning;
                }
            }
            
            // Decrement game clock with speed multiplier
            const speed_multiplier = if (self.clock_speed == .custom) 
                self.custom_speed_multiplier 
            else 
                self.clock_speed.getMultiplier();
                
            const time_to_subtract = @min(speed_multiplier, self.time_remaining);
            
            if (self.time_remaining > 0) {
                self.time_remaining -= time_to_subtract;
                self.total_elapsed += time_to_subtract;
            }
            
            // Handle quarter transitions
            if (self.time_remaining == 0) {
                self.clock_state = .expired;
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
            self.mutex.lock();
            defer self.mutex.unlock();
            
            self.time_remaining = QUARTER_LENGTH_SECONDS;
            self.quarter = .Q1;
            self.is_running = false;
            self.clock_state = .stopped;
            self.play_clock = PLAY_CLOCK_SECONDS;
            self.play_clock_state = .inactive;
            self.play_clock_duration = .normal_40;
            self.game_state = .PreGame;
            self.clock_speed = .real_time;
            self.custom_speed_multiplier = 1;
            self.two_minute_warning_given = [_]bool{false} ** 4;
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
            self.mutex.lock();
            defer self.mutex.unlock();
            
            self.play_clock = self.play_clock_duration.toSeconds();
            self.play_clock_state = .inactive;
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
            self.mutex.lock();
            defer self.mutex.unlock();
            
            if (seconds > PLAY_CLOCK_SECONDS) {
                return GameClockError.InvalidPlayClock;
            }
            
            self.play_clock = seconds;
            
            // Update play clock state based on new value
            if (seconds == 0) {
                self.play_clock_state = .expired;
            } else if (seconds <= 5) {
                self.play_clock_state = .warning;
            } else {
                self.play_clock_state = .active;
            }
        }

        // ┌──────────────────────────── Private Methods ────────────────────────────┐

            /// Advance to the next quarter
            fn advanceQuarter(self: *GameClock) GameClockError!void {
                // Update both fields for backward compatibility
                self.is_running = false;
                self.clock_state = .stopped;
                
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
                        self.clock_state = .expired;
                    },
                    .Overtime => {
                        self.game_state = .EndGame;
                        self.clock_state = .expired;
                    },
                }
                
                // Reset play clock state
                self.play_clock_state = .inactive;
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
            return std.fmt.bufPrint(buffer, "{d:0>2}:{d:0>2}", .{ minutes, seconds }) catch {
                if (buffer.len >= 5) {
                    @memcpy(buffer[0..5], "00:00");
                    return buffer[0..5];
                }
                return buffer[0..0];
            };
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

        /// Set clock speed for simulation.
        ///
        /// Changes the clock speed multiplier for game simulation.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to GameClock
        /// - `speed`: New clock speed setting
        ///
        /// __Return__
        ///
        /// - void
        pub fn setClockSpeed(self: *GameClock, speed: ClockSpeed) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            
            self.clock_speed = speed;
        }

        /// Set custom clock speed multiplier.
        ///
        /// Sets a custom speed multiplier for simulation.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to GameClock
        /// - `multiplier`: Speed multiplier (minimum 1)
        ///
        /// __Return__
        ///
        /// - void
        pub fn setCustomClockSpeed(self: *GameClock, multiplier: u32) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            
            self.clock_speed = .custom;
            self.custom_speed_multiplier = @max(1, multiplier);
        }

        /// Get current clock speed.
        ///
        /// Returns the current clock speed setting.
        ///
        /// __Parameters__
        ///
        /// - `self`: Const reference to GameClock
        ///
        /// __Return__
        ///
        /// - Current clock speed
        pub fn getClockSpeed(self: *const GameClock) ClockSpeed {
            return self.clock_speed;
        }

        /// Get current speed multiplier.
        ///
        /// Returns the effective speed multiplier.
        ///
        /// __Parameters__
        ///
        /// - `self`: Const reference to GameClock
        ///
        /// __Return__
        ///
        /// - Speed multiplier value
        pub fn getSpeedMultiplier(self: *const GameClock) u32 {
            return if (self.clock_speed == .custom) 
                self.custom_speed_multiplier 
            else 
                self.clock_speed.getMultiplier();
        }

        /// Set play clock duration.
        ///
        /// Updates the play clock duration type.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to GameClock
        /// - `duration`: New play clock duration
        ///
        /// __Return__
        ///
        /// - void
        pub fn setPlayClockDuration(self: *GameClock, duration: PlayClockDuration) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            
            self.play_clock_duration = duration;
            self.play_clock = duration.toSeconds();
        }

        /// Start play clock.
        ///
        /// Begins the play clock countdown.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to GameClock
        ///
        /// __Return__
        ///
        /// - void
        pub fn startPlayClock(self: *GameClock) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            
            if (self.game_state.isActive()) {
                self.play_clock_state = .active;
            }
        }

        /// Stop play clock.
        ///
        /// Pauses the play clock countdown.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to GameClock
        ///
        /// __Return__
        ///
        /// - void
        pub fn stopPlayClock(self: *GameClock) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            
            self.play_clock_state = .inactive;
        }

        /// Get current clock state.
        ///
        /// Returns the current clock state enum.
        ///
        /// __Parameters__
        ///
        /// - `self`: Const reference to GameClock
        ///
        /// __Return__
        ///
        /// - Current clock state
        pub fn getClockState(self: *const GameClock) ClockState {
            return self.clock_state;
        }

        /// Get current play clock state.
        ///
        /// Returns the current play clock state enum.
        ///
        /// __Parameters__
        ///
        /// - `self`: Const reference to GameClock
        ///
        /// __Return__
        ///
        /// - Current play clock state
        pub fn getPlayClockState(self: *const GameClock) PlayClockState {
            return self.play_clock_state;
        }

        /// Stop clock with reason.
        ///
        /// Stops the clock and records the stopping reason.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to GameClock
        /// - `reason`: Reason for stopping the clock
        ///
        /// __Return__
        ///
        /// - void
        pub fn stopWithReason(self: *GameClock, reason: ClockStoppingReason) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            
            if (reason.stopsGameClock()) {
                self.is_running = false;
                self.clock_state = .stopped;
                
                // Handle play clock based on stopping reason
                switch (reason) {
                    .timeout, .injury => {
                        self.play_clock_duration = .short_25;
                        self.play_clock = 25;
                        self.play_clock_state = .inactive;
                    },
                    .penalty => {
                        self.play_clock_state = .inactive;
                    },
                    else => {},
                }
            }
        }

        /// Check if two-minute warning should trigger.
        ///
        /// Determines if we're at the two-minute warning point.
        ///
        /// __Parameters__
        ///
        /// - `self`: Const reference to GameClock
        ///
        /// __Return__
        ///
        /// - Boolean indicating if two-minute warning should trigger
        pub fn shouldTriggerTwoMinuteWarning(self: *const GameClock) bool {
            // Two-minute warning occurs in 2nd and 4th quarters
            if (self.quarter != .Q2 and self.quarter != .Q4) {
                return false;
            }
            
            // Check if we just crossed the 2-minute threshold and haven't given warning yet
            const quarter_index = @as(usize, @intFromEnum(self.quarter)) - 1;
            return self.time_remaining <= 120 and !self.two_minute_warning_given[quarter_index];
        }

        /// Trigger two-minute warning.
        ///
        /// Stops the clock for two-minute warning.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to GameClock
        ///
        /// __Return__
        ///
        /// - void
        pub fn triggerTwoMinuteWarning(self: *GameClock) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            
            if (self.shouldTriggerTwoMinuteWarning()) {
                self.is_running = false;
                self.clock_state = .stopped;
                
                const quarter_index = @as(usize, @intFromEnum(self.quarter)) - 1;
                self.two_minute_warning_given[quarter_index] = true;
            }
        }

        /// Advanced tick with speed multiplier.
        ///
        /// Advances clock by multiple seconds based on speed setting.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to GameClock
        /// - `ticks`: Number of ticks to advance
        ///
        /// __Return__
        ///
        /// - Error if quarter transition fails
        pub fn advancedTick(self: *GameClock, ticks: u32) GameClockError!void {
            self.mutex.lock();
            defer self.mutex.unlock();
            
            if (!self.is_running or self.clock_state != .running) {
                return;
            }
            
            const speed_multiplier = self.getSpeedMultiplier();
            const total_time_to_subtract = speed_multiplier * ticks;
            
            // Check for two-minute warning
            if (self.shouldTriggerTwoMinuteWarning()) {
                self.triggerTwoMinuteWarning();
                return;
            }
            
            // Advance play clock
            if (self.play_clock_state.isActive()) {
                const play_clock_subtract = @min(ticks, self.play_clock);
                self.play_clock -= @intCast(play_clock_subtract);
                
                if (self.play_clock == 0) {
                    self.play_clock_state = .expired;
                } else if (self.play_clock <= 5) {
                    self.play_clock_state = .warning;
                }
            }
            
            // Advance game clock
            if (self.time_remaining > 0) {
                const time_to_subtract = @min(total_time_to_subtract, self.time_remaining);
                self.time_remaining -= time_to_subtract;
                self.total_elapsed += time_to_subtract;
                
                // Handle quarter transitions
                if (self.time_remaining == 0) {
                    self.clock_state = .expired;
                    try self.advanceQuarter();
                }
            }
        }

        /// Add deinit method for cleanup.
        ///
        /// Cleans up any resources when GameClock is destroyed.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to GameClock
        ///
        /// __Return__
        ///
        /// - void
        pub fn deinit(self: *GameClock) void {
            // Currently no special cleanup needed, but good practice to have
            _ = self;
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
        try testing.expectEqual(ClockState.stopped, clock.clock_state);
        try testing.expectEqual(PLAY_CLOCK_SECONDS, clock.play_clock);
        try testing.expectEqual(PlayClockState.inactive, clock.play_clock_state);
        try testing.expectEqual(PlayClockDuration.normal_40, clock.play_clock_duration);
        try testing.expectEqual(GameState.PreGame, clock.game_state);
        try testing.expectEqual(ClockSpeed.real_time, clock.clock_speed);
        try testing.expectEqual(@as(u32, 1), clock.custom_speed_multiplier);
        try testing.expect(!clock.two_minute_warning_given[0]);
        try testing.expect(!clock.two_minute_warning_given[1]);
        try testing.expect(!clock.two_minute_warning_given[2]);
        try testing.expect(!clock.two_minute_warning_given[3]);
    }

    test "unit: GameClock: start and stop" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Start the clock
        try clock.start();
        try testing.expectEqual(true, clock.is_running);
        try testing.expectEqual(ClockState.running, clock.clock_state);
        try testing.expectEqual(GameState.InProgress, clock.game_state);
        
        // Try to start again (should error)
        try testing.expectError(GameClockError.ClockAlreadyRunning, clock.start());
        
        // Stop the clock
        try clock.stop();
        try testing.expectEqual(false, clock.is_running);
        try testing.expectEqual(ClockState.stopped, clock.clock_state);
        
        // Try to stop again (should error)
        try testing.expectError(GameClockError.ClockNotRunning, clock.stop());
    }

    test "unit: GameClock: tick functionality" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        try clock.start();
        clock.startPlayClock(); // Need to start play clock for it to tick
        
        const initial_time = clock.time_remaining;
        const initial_play_clock = clock.play_clock;
        
        try clock.tick();
        
        try testing.expectEqual(initial_time - 1, clock.time_remaining);
        try testing.expectEqual(initial_play_clock - 1, clock.play_clock);
        try testing.expectEqual(@as(u64, 1), clock.total_elapsed);
        try testing.expectEqual(ClockState.running, clock.clock_state);
        try testing.expectEqual(PlayClockState.active, clock.play_clock_state);
    }

    test "unit: GameClock: play clock operations" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Reset play clock
        clock.play_clock = 10;
        clock.resetPlayClock();
        try testing.expectEqual(PLAY_CLOCK_SECONDS, clock.play_clock);
        try testing.expectEqual(PlayClockState.inactive, clock.play_clock_state);
        
        // Set play clock
        try clock.setPlayClock(25);
        try testing.expectEqual(@as(u8, 25), clock.play_clock);
        try testing.expectEqual(PlayClockState.active, clock.play_clock_state);
        
        // Set to warning threshold
        try clock.setPlayClock(5);
        try testing.expectEqual(PlayClockState.warning, clock.play_clock_state);
        
        // Set to expired
        try clock.setPlayClock(0);
        try testing.expectEqual(PlayClockState.expired, clock.play_clock_state);
        
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
        try testing.expectEqual(ClockState.stopped, clock.clock_state);
        try testing.expectEqual(PlayClockState.inactive, clock.play_clock_state);
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

    test "unit: GameClock: clock speed control" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Test initial speed
        try testing.expectEqual(ClockSpeed.real_time, clock.getClockSpeed());
        try testing.expectEqual(@as(u32, 1), clock.getSpeedMultiplier());
        
        // Test setting different speeds
        clock.setClockSpeed(.accelerated_2x);
        try testing.expectEqual(ClockSpeed.accelerated_2x, clock.getClockSpeed());
        try testing.expectEqual(@as(u32, 2), clock.getSpeedMultiplier());
        
        clock.setClockSpeed(.accelerated_5x);
        try testing.expectEqual(ClockSpeed.accelerated_5x, clock.getClockSpeed());
        try testing.expectEqual(@as(u32, 5), clock.getSpeedMultiplier());
        
        // Test custom speed
        clock.setCustomClockSpeed(10);
        try testing.expectEqual(ClockSpeed.custom, clock.getClockSpeed());
        try testing.expectEqual(@as(u32, 10), clock.getSpeedMultiplier());
        
        // Test custom speed minimum
        clock.setCustomClockSpeed(0);
        try testing.expectEqual(@as(u32, 1), clock.getSpeedMultiplier());
    }

    test "unit: GameClock: play clock duration" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Test initial duration
        try testing.expectEqual(PlayClockDuration.normal_40, clock.play_clock_duration);
        try testing.expectEqual(@as(u8, 40), clock.play_clock_duration.toSeconds());
        
        // Test setting short duration
        clock.setPlayClockDuration(.short_25);
        try testing.expectEqual(PlayClockDuration.short_25, clock.play_clock_duration);
        try testing.expectEqual(@as(u8, 25), clock.play_clock);
        try testing.expectEqual(@as(u8, 25), clock.play_clock_duration.toSeconds());
    }

    test "unit: GameClock: play clock state management" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // Initial state should be inactive
        try testing.expectEqual(PlayClockState.inactive, clock.getPlayClockState());
        try testing.expect(!clock.play_clock_state.isActive());
        
        // Start game and play clock
        try clock.start();
        clock.startPlayClock();
        try testing.expectEqual(PlayClockState.active, clock.getPlayClockState());
        try testing.expect(clock.play_clock_state.isActive());
        
        // Stop play clock
        clock.stopPlayClock();
        try testing.expectEqual(PlayClockState.inactive, clock.getPlayClockState());
        try testing.expect(!clock.play_clock_state.isActive());
    }

    test "unit: GameClock: clock stopping reasons" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        try clock.start();
        try testing.expectEqual(ClockState.running, clock.getClockState());
        
        // Test timeout stops clock and sets short play clock
        clock.stopWithReason(.timeout);
        try testing.expectEqual(ClockState.stopped, clock.getClockState());
        try testing.expectEqual(false, clock.is_running);
        try testing.expectEqual(PlayClockDuration.short_25, clock.play_clock_duration);
        try testing.expectEqual(@as(u8, 25), clock.play_clock);
        
        // Test incomplete pass stops clock
        try clock.start();
        clock.stopWithReason(.incomplete_pass);
        try testing.expectEqual(ClockState.stopped, clock.getClockState());
        
        // Test penalty stops clock
        try clock.start();
        clock.stopWithReason(.penalty);
        try testing.expectEqual(ClockState.stopped, clock.getClockState());
        try testing.expectEqual(PlayClockState.inactive, clock.play_clock_state);
    }

    test "unit: GameClock: two minute warning" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        // No warning in Q1
        clock.quarter = .Q1;
        clock.time_remaining = 120;
        try testing.expect(!clock.shouldTriggerTwoMinuteWarning());
        
        // Warning should trigger in Q2 at 2:00
        clock.quarter = .Q2;
        clock.time_remaining = 120;
        try testing.expect(clock.shouldTriggerTwoMinuteWarning());
        
        // Trigger the warning
        clock.triggerTwoMinuteWarning();
        try testing.expect(clock.two_minute_warning_given[1]);
        try testing.expectEqual(ClockState.stopped, clock.getClockState());
        
        // Should not trigger again in same quarter
        try testing.expect(!clock.shouldTriggerTwoMinuteWarning());
        
        // Warning should trigger in Q4 at 2:00
        clock.quarter = .Q4;
        clock.time_remaining = 120;
        try testing.expect(clock.shouldTriggerTwoMinuteWarning());
    }

    test "unit: GameClock: advanced tick with speed" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        
        try clock.start();
        clock.setClockSpeed(.accelerated_2x);
        
        const initial_time = clock.time_remaining;
        try clock.advancedTick(1);
        
        // Should advance by 2 seconds (2x speed)
        try testing.expectEqual(initial_time - 2, clock.time_remaining);
        try testing.expectEqual(@as(u64, 2), clock.total_elapsed);
        
        // Test custom speed
        clock.setCustomClockSpeed(5);
        const time_before = clock.time_remaining;
        try clock.advancedTick(1);
        
        // Should advance by 5 seconds
        try testing.expectEqual(time_before - 5, clock.time_remaining);
    }

    test "unit: GameClock: enum method functionality" {
        // Test ClockState methods
        try testing.expect(ClockState.running.isRunning());
        try testing.expect(!ClockState.stopped.isRunning());
        try testing.expect(!ClockState.expired.isRunning());
        
        // Test PlayClockState methods
        try testing.expect(PlayClockState.active.isActive());
        try testing.expect(PlayClockState.warning.isActive());
        try testing.expect(!PlayClockState.inactive.isActive());
        try testing.expect(!PlayClockState.expired.isActive());
        
        // Test PlayClockDuration methods
        try testing.expectEqual(@as(u8, 40), PlayClockDuration.normal_40.toSeconds());
        try testing.expectEqual(@as(u8, 25), PlayClockDuration.short_25.toSeconds());
        
        // Test ClockStoppingReason methods
        try testing.expect(ClockStoppingReason.timeout.stopsGameClock());
        try testing.expect(ClockStoppingReason.incomplete_pass.stopsGameClock());
        try testing.expect(ClockStoppingReason.out_of_bounds.stopsGameClock());
        
        // Test ClockSpeed methods
        try testing.expectEqual(@as(u32, 1), ClockSpeed.real_time.getMultiplier());
        try testing.expectEqual(@as(u32, 2), ClockSpeed.accelerated_2x.getMultiplier());
        try testing.expectEqual(@as(u32, 5), ClockSpeed.accelerated_5x.getMultiplier());
        try testing.expectEqual(@as(u32, 10), ClockSpeed.accelerated_10x.getMultiplier());
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝