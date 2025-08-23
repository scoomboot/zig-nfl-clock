// config.zig — Configuration system for NFL game clock
//
// repo   : https://github.com/scoomboot/zig-nfl-clock
// docs   : https://zig-nfl-clock.github.io/docs/lib/game_clock/utils/config
// author : https://github.com/scoomboot
//
// Vibe coded by Scoom.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const Allocator = std.mem.Allocator;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    /// Configuration validation error types
    pub const ConfigError = error{
        InvalidQuarterLength,
        InvalidOvertimeLength,
        InvalidPlayClock,
        InvalidTimeoutDuration,
        InvalidHalftimeDuration,
        InvalidSpeedMultiplier,
        IncompatibleConfiguration,
    };

    /// Feature flags for enabling/disabling specific functionality
    pub const Features = struct {
        two_minute_warning: bool = true,
        overtime: bool = true,
        timeouts: bool = true,
        injuries: bool = true,
        penalties: bool = true,
        challenges: bool = true,
        weather_effects: bool = false,
        
        /// Returns default NFL feature flags.
        ///
        /// Standard NFL game features enabled.
        ///
        /// __Parameters__
        ///
        /// - None
        ///
        /// __Return__
        ///
        /// - Default Features configuration
        pub fn default() Features {
            return Features{};
        }
        
        /// Returns practice mode feature flags.
        ///
        /// Simplified features for practice sessions.
        ///
        /// __Parameters__
        ///
        /// - None
        ///
        /// __Return__
        ///
        /// - Practice Features configuration
        pub fn practice() Features {
            return Features{
                .two_minute_warning = false,
                .overtime = false,
                .timeouts = false,
                .injuries = false,
                .penalties = false,
                .challenges = false,
                .weather_effects = false,
            };
        }
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    /// Comprehensive clock configuration structure
    pub const ClockConfig = struct {
        // Time Settings
        quarter_length: u32 = 900,           // 15 minutes in seconds
        overtime_length: u32 = 600,          // 10 minutes in seconds
        halftime_duration: u32 = 720,        // 12 minutes in seconds
        play_clock_normal: u8 = 40,          // 40 seconds
        play_clock_short: u8 = 25,           // 25 seconds
        timeout_duration: u32 = 30,          // 30 seconds per timeout
        two_minute_warning_time: u32 = 120,  // 2 minutes
        
        // Rule Settings
        timeouts_per_half: u8 = 3,
        challenges_per_game: u8 = 2,
        overtime_type: OvertimeType = .sudden_death,
        clock_stop_incomplete_pass: bool = true,
        clock_stop_out_of_bounds: bool = true,
        clock_stop_penalty: bool = true,
        clock_stop_first_down: bool = false, // Only in last 2 minutes
        
        // Behavior Settings
        auto_start_play_clock: bool = true,
        auto_timeout_management: bool = false,
        injury_timeout_enabled: bool = true,
        enforce_delay_of_game: bool = true,
        
        // Advanced Settings
        minimum_snap_time: u8 = 1,           // 1 second minimum before snap
        spike_clock_runoff: u8 = 3,          // 3 seconds for spike
        kneel_clock_runoff: u8 = 40,         // 40 seconds for kneel
        simulation_speed: u32 = 1,           // Real-time by default
        deterministic_mode: bool = false,    // For testing
        
        // Feature flags
        features: Features = Features.default(),
        
        /// Overtime type enumeration
        pub const OvertimeType = enum {
            sudden_death,
            modified_sudden_death,
            college_style,
            none,
        };
        
        /// Initialize with default NFL regular season settings.
        ///
        /// Creates a configuration with standard NFL timing rules.
        ///
        /// __Parameters__
        ///
        /// - None
        ///
        /// __Return__
        ///
        /// - Default ClockConfig instance
        pub fn default() ClockConfig {
            return ClockConfig{};
        }
        
        /// Initialize with NFL playoff settings.
        ///
        /// Creates a configuration for playoff games with modified overtime.
        ///
        /// __Parameters__
        ///
        /// - None
        ///
        /// __Return__
        ///
        /// - Playoff ClockConfig instance
        pub fn nflPlayoff() ClockConfig {
            return ClockConfig{
                .overtime_type = .modified_sudden_death,
                .overtime_length = 900, // 15 minutes in playoffs
                .features = Features{
                    .two_minute_warning = true,
                    .overtime = true,
                    .timeouts = true,
                    .injuries = true,
                    .penalties = true,
                    .challenges = true,
                    .weather_effects = true,
                },
            };
        }
        
        /// Initialize with college football settings.
        ///
        /// Creates a configuration for college football timing rules.
        ///
        /// __Parameters__
        ///
        /// - None
        ///
        /// __Return__
        ///
        /// - College ClockConfig instance
        pub fn college() ClockConfig {
            return ClockConfig{
                .quarter_length = 900,
                .overtime_type = .college_style,
                .overtime_length = 0, // No timed OT in college
                .clock_stop_first_down = true, // Clock stops on first downs
                .halftime_duration = 1200, // 20 minutes halftime
                .features = Features{
                    .two_minute_warning = false, // No 2-minute warning in college
                    .overtime = true,
                    .timeouts = true,
                    .injuries = true,
                    .penalties = true,
                    .challenges = false, // Different review system
                    .weather_effects = false,
                },
            };
        }
        
        /// Initialize with practice/scrimmage settings.
        ///
        /// Creates a simplified configuration for practice sessions.
        ///
        /// __Parameters__
        ///
        /// - None
        ///
        /// __Return__
        ///
        /// - Practice ClockConfig instance
        pub fn practice() ClockConfig {
            return ClockConfig{
                .quarter_length = 600, // 10 minute quarters
                .overtime_type = .none,
                .halftime_duration = 300, // 5 minutes
                .auto_timeout_management = false,
                .enforce_delay_of_game = false,
                .features = Features.practice(),
            };
        }
        
        /// Validate the configuration for consistency.
        ///
        /// Checks that all configuration values are within valid ranges.
        ///
        /// __Parameters__
        ///
        /// - `self`: The configuration to validate
        ///
        /// __Return__
        ///
        /// - Error if configuration is invalid
        pub fn validate(self: *const ClockConfig) ConfigError!void {
            // Validate time settings
            if (self.quarter_length < 1 or self.quarter_length > 3600) {
                return ConfigError.InvalidQuarterLength;
            }
            
            if (self.overtime_length > 1800) { // Max 30 minutes
                return ConfigError.InvalidOvertimeLength;
            }
            
            if (self.play_clock_normal < 1 or self.play_clock_normal > 60) {
                return ConfigError.InvalidPlayClock;
            }
            
            if (self.play_clock_short < 1 or self.play_clock_short > self.play_clock_normal) {
                return ConfigError.InvalidPlayClock;
            }
            
            if (self.timeout_duration < 1 or self.timeout_duration > 120) {
                return ConfigError.InvalidTimeoutDuration;
            }
            
            if (self.halftime_duration < 60 or self.halftime_duration > 3600) {
                return ConfigError.InvalidHalftimeDuration;
            }
            
            if (self.simulation_speed < 1 or self.simulation_speed > 100) {
                return ConfigError.InvalidSpeedMultiplier;
            }
            
            // Validate rule consistency
            if (self.overtime_type == .college_style and self.features.two_minute_warning) {
                return ConfigError.IncompatibleConfiguration;
            }
            
            if (self.two_minute_warning_time > self.quarter_length) {
                return ConfigError.IncompatibleConfiguration;
            }
        }
        
        /// Check if a configuration change is compatible with current state.
        ///
        /// Determines if a new configuration can be applied without breaking game state.
        ///
        /// __Parameters__
        ///
        /// - `self`: Current configuration
        /// - `new_config`: Proposed new configuration
        /// - `current_time`: Current time remaining in quarter
        ///
        /// __Return__
        ///
        /// - Boolean indicating if change is compatible
        pub fn isCompatibleChange(self: *const ClockConfig, new_config: *const ClockConfig, current_time: u32) bool {
            _ = self; // Current config may be used for future comparisons
            
            // Can't change quarter length if it would make current time invalid
            if (new_config.quarter_length < current_time) {
                return false;
            }
            
            // Can't disable features that are currently in use
            // This would need more context about game state in practice
            
            // Allow most other changes
            return true;
        }
        
        /// Create a migration plan for incompatible changes.
        ///
        /// Generates steps to safely transition to a new configuration.
        ///
        /// __Parameters__
        ///
        /// - `self`: Current configuration
        /// - `new_config`: Target configuration
        /// - `allocator`: Memory allocator for migration data
        ///
        /// __Return__
        ///
        /// - Migration plan or error
        pub fn createMigration(self: *const ClockConfig, new_config: *const ClockConfig, allocator: Allocator) !Migration {
            var migration = Migration.init(allocator);
            
            // Check if quarter length changes
            if (self.quarter_length != new_config.quarter_length) {
                try migration.addStep(.{
                    .type = .adjust_time,
                    .description = "Adjust quarter length",
                    .old_value = self.quarter_length,
                    .new_value = new_config.quarter_length,
                });
            }
            
            // Check feature changes
            if (self.features.two_minute_warning != new_config.features.two_minute_warning) {
                try migration.addStep(.{
                    .type = .toggle_feature,
                    .description = "Toggle two-minute warning",
                    .old_value = @intFromBool(self.features.two_minute_warning),
                    .new_value = @intFromBool(new_config.features.two_minute_warning),
                });
            }
            
            return migration;
        }
        
        /// Apply configuration at compile time.
        ///
        /// Creates a compile-time constant configuration.
        ///
        /// __Parameters__
        ///
        /// - `config`: Configuration to apply at compile time
        ///
        /// __Return__
        ///
        /// - Compile-time configuration
        pub fn applyComptime(comptime config: ClockConfig) ClockConfig {
            comptime {
                var validated_config = config;
                validated_config.validate() catch @compileError("Invalid configuration");
                return validated_config;
            }
        }
    };
    
    /// Migration plan for configuration changes
    pub const Migration = struct {
        allocator: Allocator,
        steps: std.ArrayList(MigrationStep),
        
        pub const MigrationStep = struct {
            type: StepType,
            description: []const u8,
            old_value: u32,
            new_value: u32,
            
            pub const StepType = enum {
                adjust_time,
                toggle_feature,
                reset_state,
            };
        };
        
        /// Initialize a new migration plan.
        ///
        /// Creates an empty migration plan.
        ///
        /// __Parameters__
        ///
        /// - `allocator`: Memory allocator
        ///
        /// __Return__
        ///
        /// - Initialized Migration instance
        pub fn init(allocator: Allocator) Migration {
            return Migration{
                .allocator = allocator,
                .steps = std.ArrayList(MigrationStep).init(allocator),
            };
        }
        
        /// Add a step to the migration plan.
        ///
        /// Appends a new migration step.
        ///
        /// __Parameters__
        ///
        /// - `self`: Migration plan
        /// - `step`: Step to add
        ///
        /// __Return__
        ///
        /// - Error if allocation fails
        pub fn addStep(self: *Migration, step: MigrationStep) !void {
            try self.steps.append(step);
        }
        
        /// Clean up migration resources.
        ///
        /// Frees allocated memory.
        ///
        /// __Parameters__
        ///
        /// - `self`: Migration plan to clean up
        ///
        /// __Return__
        ///
        /// - None
        pub fn deinit(self: *Migration) void {
            self.steps.deinit();
        }
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝