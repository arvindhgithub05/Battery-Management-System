module battery_notification_with_low_warning (
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

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset all outputs
            pulse_20 <= 0;
            pulse_80 <= 0;
            pulse_100 <= 0;
            clk_enable <= 1;       // Enable charging on reset
            overcharge_alert <= 0; // Clear alert on reset
            prev_battery_level <= 0;
        end else begin
            // Generate pulse at 20% low battery warning
            if (battery_level == LOW_BATTERY_LEVEL && prev_battery_level > LOW_BATTERY_LEVEL) begin
                pulse_20 <= 1;
            end else begin
                pulse_20 <= 0;
            end

            // Generate pulse at 80% healthy battery level
            if (battery_level == HEALTHY_BATTERY_LEVEL && prev_battery_level < HEALTHY_BATTERY_LEVEL) begin
                pulse_80 <= 1;
            end else begin
                pulse_80 <= 0;
            end

            // Generate pulse at 100% full charge level
            if (battery_level == FULL_CHARGE_LEVEL && prev_battery_level < FULL_CHARGE_LEVEL) begin
                pulse_100 <= 1;
                clk_enable <= 0; // Disable charging at full charge
            end else begin
                pulse_100 <= 0;
            end

            // Overcharge protection
            if (battery_level > FULL_CHARGE_LEVEL || voltage > MAX_VOLTAGE) begin
                clk_enable <= 0;       // Disable charging
                overcharge_alert <= 1; // Trigger overcharge alert
            end else begin
                // Clear overcharge alert if conditions are normal
                overcharge_alert <= 0;
                if (battery_level < FULL_CHARGE_LEVEL) begin
                    clk_enable <= 1;   // Enable charging if not full
                end
            end

            // Update previous battery level
            prev_battery_level <= battery_level;
        end
    end

endmodule
