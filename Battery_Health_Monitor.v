`timescale 1ns / 1ps

module Battery_Health_Monitor (
    input wire clk,                // System clock
    input wire reset,              // Reset signal
    input wire [7:0] battery_level,// Battery level in percentage (0-100)
    input wire [7:0] voltage,      // Battery voltage (arbitrary units)
    output reg pulse_20,           // Pulse for 20% low battery warning
    output reg pulse_80,           // Pulse for 80% healthy charge
    output reg pulse_100,          // Pulse for 100% full charge
    output reg clk_enable,         // Clock enable signal for charging
    output reg overcharge_alert    // Overcharge alert signal
    );

    // Parameters for thresholds
    parameter LOW_BATTERY_LEVEL = 8'd20;   // 20% battery level
    parameter HEALTHY_BATTERY_LEVEL = 8'd80; // 80% battery level
    parameter FULL_CHARGE_LEVEL = 8'd100; // 100% battery level
    parameter MAX_VOLTAGE = 8'd255;       // Example maximum voltage threshold

    // Internal signals
    reg [7:0] prev_battery_level;
    reg overcharge_detected;  // Latch for overcharge condition

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset all outputs
            pulse_20 <= 0;
            pulse_80 <= 0;
            pulse_100 <= 0;
            clk_enable <= 1;       // Enable charging on reset
            overcharge_alert <= 0; // Clear alert on reset
            overcharge_detected <= 0;
            prev_battery_level <= 0;
        end else begin
            // Generate pulse at 20% low battery warning (falling edge detection)
            if (battery_level == LOW_BATTERY_LEVEL && prev_battery_level > LOW_BATTERY_LEVEL) begin
                pulse_20 <= 1;
            end else begin
                pulse_20 <= 0;
            end

            // Generate pulse at 80% healthy battery level (rising edge detection)
            if (battery_level == HEALTHY_BATTERY_LEVEL && prev_battery_level < HEALTHY_BATTERY_LEVEL) begin
                pulse_80 <= 1;
            end else begin
                pulse_80 <= 0;
            end

            // Generate pulse at 100% full charge level (rising edge detection)
            if (battery_level == FULL_CHARGE_LEVEL && prev_battery_level < FULL_CHARGE_LEVEL) begin
                pulse_100 <= 1;
            end else begin
                pulse_100 <= 0;
            end

            // Overcharge detection and alert logic
            if (battery_level == FULL_CHARGE_LEVEL && voltage > MAX_VOLTAGE) begin
                overcharge_detected <= 1;
                overcharge_alert <= 1;
            end else if (battery_level < FULL_CHARGE_LEVEL) begin
                // Clear overcharge condition when battery level drops below 100%
                overcharge_detected <= 0;
                overcharge_alert <= 0;
            end

            // Clock enable logic (centralized to avoid conflicts)
            if (overcharge_detected || (battery_level == FULL_CHARGE_LEVEL && voltage > MAX_VOLTAGE)) begin
                clk_enable <= 0;  // Disable charging during overcharge
            end else if (battery_level == FULL_CHARGE_LEVEL && voltage <= MAX_VOLTAGE) begin
                clk_enable <= 0;  // Disable charging at full charge with normal voltage
            end else begin
                clk_enable <= 1;  // Enable charging otherwise
            end

            // Update previous battery level at the end
            prev_battery_level <= battery_level;
        end
    end

endmodule
