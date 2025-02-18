// Moisture Detection Module for Fast Charging SoC

module MoistureDetection (
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

    // State transition logic
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            current_state <= NO_MOISTURE; // Default state: No moisture detected
        else
            current_state <= next_state;
    end

    // Next state logic and output logic
    always @(*) begin
        case (current_state)
            NO_MOISTURE: begin
                if (moisture_sensor)
                    next_state = MOISTURE;
                else
                    next_state = NO_MOISTURE;
                charge_enable = charger_plugged ? 1'b1 : 1'b0; // Allow charging only if charger is plugged in
            end

            MOISTURE: begin
                if (!moisture_sensor)
                    next_state = NO_MOISTURE;
                else
                    next_state = MOISTURE;
                charge_enable = 1'b0; // Disable charging
            end

            default: begin
                next_state = NO_MOISTURE;
                charge_enable = charger_plugged ? 1'b1 : 1'b0; // Fail-safe: Allow charging only if charger is plugged in
            end
        endcase
    end

endmodule
