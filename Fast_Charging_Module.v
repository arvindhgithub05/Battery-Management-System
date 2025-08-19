`timescale 1ns / 1ps

module Fast_Charging_Module (
    input wire clk,
    input wire reset,
    input wire charger_plugged, // Signal to indicate if charger is plugged in
    output reg [7:0] battery_level, // Battery percentage (0 to 100)
    output wire gated_clock,
    output reg [1:0] present_state // Current state: 00 - IDLE, 01 - FAST_CHARGING, 10 - SLOW_CHARGING
    );
    
    // State encoding
    localparam IDLE = 2'b00;
    localparam FAST_CHARGING = 2'b01;
    localparam SLOW_CHARGING = 2'b10;

    // Internal next_state signal
    reg [1:0] next_state;

    // Gated clock logic - using enable signal instead of gating
    reg clk_enable;
    assign gated_clock = clk & clk_enable;
    
    // Initial state
    initial begin
        battery_level = 0;
        present_state = IDLE;
        clk_enable = 0;
    end
    
    // Combinational logic for next state
    always @(*) begin
        next_state = present_state; // Default: stay in current state
        
        case (present_state)
            IDLE: begin
                if (charger_plugged && battery_level < 100) begin
                    if (battery_level <= 80) begin
                        next_state = FAST_CHARGING;
                    end else begin
                        next_state = SLOW_CHARGING;
                    end
                end
            end
            
            FAST_CHARGING: begin
                if (!charger_plugged) begin
                    next_state = IDLE;
                end else if (battery_level >= 80 && battery_level < 100) begin
                    next_state = SLOW_CHARGING;
                end
                // else stay in FAST_CHARGING
            end
            
            SLOW_CHARGING: begin
                if (!charger_plugged) begin
                    next_state = IDLE;
                end else if (battery_level == 100) begin
                    next_state = IDLE;
                end
                // else stay in SLOW_CHARGING
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic for state updates and battery charging
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            battery_level <= 0;
            present_state <= IDLE;
            clk_enable <= 0;
        end else begin
            // Update state
            present_state <= next_state;
            
            // Update clock enable based on next state
            if (next_state == IDLE) begin
                clk_enable <= 0; // Disable clock when idle or fully charged
            end else begin
                clk_enable <= 1; // Enable clock when charging
            end
            
            // Battery charging logic
            case (next_state)
                FAST_CHARGING: begin
                    if (battery_level < 80) begin
                        battery_level <= battery_level + 2; // Faster charging rate
                    end
                end
                
                SLOW_CHARGING: begin
                    if (battery_level < 100) begin
                        battery_level <= battery_level + 1; // Slower charging rate
                    end
                end
                
                // IDLE: battery_level remains unchanged
            endcase
            
            // Ensure battery level doesn't exceed 100
            if (battery_level > 100) begin
                battery_level <= 100;
            end
        end
    end

endmodule
