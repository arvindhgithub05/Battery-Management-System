`timescale 1ns / 1ps

module Moisture_Detection (
    input wire clk,              // System clock
    input wire reset_n,          // Active low reset
    input wire moisture_sensor,  // Input from moisture sensor (1: Moisture detected, 0: No moisture)
    input wire charger_plugged,  // Input indicating if the charger is plugged in (1: Plugged, 0: Unplugged)
    output reg charge_enable     // Output signal to enable/disable charging
    );

    // State encoding
    localparam NO_MOISTURE = 1'b0;  // No moisture detected, charging allowed
    localparam MOISTURE = 1'b1;     // Moisture detected, charging disabled

    reg current_state, next_state;
    reg charge_enable_next;

    // State transition logic
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            current_state <= NO_MOISTURE; // Default state: No moisture detected
            charge_enable <= 1'b0;         // Disable charging on reset
        end else begin
            current_state <= next_state;
            charge_enable <= charge_enable_next;
        end
    end

    // Next state logic and output logic
    always @(*) begin
        // Default assignments to prevent latches
        next_state = current_state;
        charge_enable_next = 1'b0;

        case (current_state)
            NO_MOISTURE: begin
                if (moisture_sensor) begin
                    next_state = MOISTURE;
                    charge_enable_next = 1'b0; // Disable charging when moisture detected
                end else begin
                    next_state = NO_MOISTURE;
                    charge_enable_next = charger_plugged; // Allow charging only if charger is plugged in
                end
            end

            MOISTURE: begin
                if (!moisture_sensor) begin
                    next_state = NO_MOISTURE;
                    charge_enable_next = charger_plugged; // Re-enable charging if charger plugged and no moisture
                end else begin
                    next_state = MOISTURE;
                    charge_enable_next = 1'b0; // Keep charging disabled while moisture present
                end
            end

            default: begin
                next_state = NO_MOISTURE;
                charge_enable_next = 1'b0; // Fail-safe: Disable charging in unknown state
            end
        endcase
    end

endmodule
