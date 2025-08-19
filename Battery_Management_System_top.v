`timescale 1ns / 1ps

module Battery_Management_System_top (
    // Primary inputs
    input wire clk,                    // System clock
    input wire reset,                  // Active high reset
    input wire reset_n,                // Active low reset for moisture detection
    input wire charger_plugged,       // Physical charger connection status
    input wire [7:0] voltage,          // Battery voltage measurement
    input wire moisture_sensor,        // Moisture detection sensor
    
    // Primary outputs
    output wire [7:0] battery_level,   // Current battery percentage (0-100)
    output wire [6:0] temperature,     // Battery temperature
    output wire gated_clock,           // Power-managed clock output
    output wire [1:0] charging_state,  // Current charging state
    output wire [1:0] charging_mode,   // Charging mode (fast/slow)
    output wire cooling_fan,           // Cooling fan control
    output wire pulse_20,              // 20% battery warning pulse
    output wire pulse_80,              // 80% healthy charge pulse
    output wire pulse_100,             // 100% full charge pulse
    output wire overcharge_alert,      // Overcharge protection alert
    output wire charge_enable_final    // Final charging enable decision
    );

    // Internal control signals
    wire fast_charge_enable;
    wire health_monitor_enable;
    wire moisture_charge_enable;
    wire temp_charge_enable;
    wire charging_active;
    
    // Temperature control signals
    wire [6:0] temp_out;
    wire temp_charging_mode;
    wire temp_cooling_fan;
    
    // Battery level conversion (8-bit to 7-bit for temperature module)
    wire [6:0] battery_percent_7bit;
    assign battery_percent_7bit = battery_level[6:0]; // Take lower 7 bits
    
    // Master charging enable logic - ALL conditions must be met
    assign charging_active = charger_plugged & 
                            fast_charge_enable & 
                            health_monitor_enable & 
                            moisture_charge_enable;
    
    // Final charge enable with temperature consideration
    assign charge_enable_final = charging_active;
    
    // Output assignments
    assign temperature = temp_out;
    assign charging_mode = {1'b0, temp_charging_mode}; // Convert 1-bit to 2-bit
    assign cooling_fan = temp_cooling_fan;
    
    // =========================================================================
    // MODULE 1: Fast Charging Controller
    // =========================================================================
    Fast_Charging_Module fast_charger (
        .clk(clk),
        .reset(reset),
        .charger_plugged(charging_active),  // Use combined charging decision
        .battery_level(battery_level),
        .gated_clock(gated_clock),
        .present_state(charging_state)
    );
    
    // Extract charging enable from fast charging module internal logic
    assign fast_charge_enable = (charging_state != 2'b00) ? 1'b1 : 
                               (charger_plugged && battery_level < 100) ? 1'b1 : 1'b0;
    
    // =========================================================================
    // MODULE 2: Battery Health Monitor
    // =========================================================================
    Battery_Health_Monitor health_monitor (
        .clk(clk),
        .reset(reset),
        .battery_level(battery_level),
        .voltage(voltage),
        .pulse_20(pulse_20),
        .pulse_80(pulse_80),
        .pulse_100(pulse_100),
        .clk_enable(health_monitor_enable),
        .overcharge_alert(overcharge_alert)
    );
    
    // =========================================================================
    // MODULE 3: Temperature Control
    // =========================================================================
    Temperature_Control temp_controller (
        .clk(clk),
        .reset(reset),
        .charging(charging_active),
        .battery_percent(battery_percent_7bit),
        .temp(temp_out),
        .charging_mode(temp_charging_mode),
        .cooling_fan(temp_cooling_fan)
    );
    
    // =========================================================================
    // MODULE 4: Moisture Detection
    // =========================================================================
    Moisture_Detection moisture_detector (
        .clk(clk),
        .reset_n(reset_n),
        .moisture_sensor(moisture_sensor),
        .charger_plugged(charger_plugged),
        .charge_enable(moisture_charge_enable)
    );
    
    // =========================================================================
    // Safety and Status Logic
    // =========================================================================
    
    // Additional safety checks
    reg safety_shutdown;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            safety_shutdown <= 1'b0;
        end else begin
            // Emergency shutdown conditions
            if (overcharge_alert || (temperature > 7'd50)) begin  // Emergency temp limit
                safety_shutdown <= 1'b1;
            end else if (battery_level < 8'd5) begin  // Allow restart when battery very low
                safety_shutdown <= 1'b0;
            end
        end
    end
    
    // Override all charging if safety shutdown is active
    wire final_charging_decision;
    assign final_charging_decision = charging_active & ~safety_shutdown;
    
endmodule