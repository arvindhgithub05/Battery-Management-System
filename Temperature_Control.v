`timescale 1ns / 1ps

// Temperature Module for Fast Charging Battery Management

module Temperature_Control (
    input wire clk,
    input wire reset,
    input wire charging,
    input wire [6:0] battery_percent,
    output reg [6:0] temp,
    output reg charging_mode, // 0 = Fast Charging, 1 = Slow Charging
    output reg cooling_fan // 1 = Cooling fan active, 0 = Cooling fan inactive
    );

    // States
    localparam IDLE = 2'b00;
    localparam FAST_CHARGING = 2'b01;
    localparam SLOW_CHARGING = 2'b10;
    
    reg [1:0] present_state, next_state;

    // Constants  
    localparam INITIAL_TEMP = 7'd27; // Initial temperature is 27°C
    localparam MAX_TEMP = 7'd45;     // Maximum temperature before switching to slow charging
    localparam MIN_TEMP = 7'd27;     // Minimum temperature limit
    localparam SLOW_START_CYCLE = 7'd80; // Battery percent to start slow charging
    localparam SLOW_END_CYCLE = 7'd100;  // Battery percent for end of slow charging

    // Internal signals to track battery level changes
    reg [6:0] prev_battery_percent;
    reg [6:0] temp_next;
    reg cooling_fan_next;
    reg charging_mode_next;

    // Sequential Logic: State Transitions and Register Updates
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            present_state <= IDLE;
            temp <= INITIAL_TEMP;
            prev_battery_percent <= 7'd0;
            charging_mode <= 1'b0;
            cooling_fan <= 1'b0;
        end else begin
            present_state <= next_state;
            temp <= temp_next;
            charging_mode <= charging_mode_next;
            cooling_fan <= cooling_fan_next;
            prev_battery_percent <= battery_percent;
        end
    end

    // Combinational Logic: Next State and Output Logic
    always @(*) begin
        // Default values
        next_state = present_state;
        charging_mode_next = 1'b0; // Default to Fast Charging
        cooling_fan_next = cooling_fan; // Maintain current cooling fan state
        temp_next = temp; // Maintain current temperature

        case (present_state)
            IDLE: begin
                if (charging && (battery_percent < SLOW_START_CYCLE)) begin
                    next_state = FAST_CHARGING;
                end else if (charging && (battery_percent >= SLOW_START_CYCLE) && (battery_percent <= SLOW_END_CYCLE)) begin
                    next_state = SLOW_CHARGING;
                end
                // Temperature remains constant in IDLE state
            end

            FAST_CHARGING: begin
                charging_mode_next = 1'b0; // Fast charging mode
                
                if (!charging) begin
                    next_state = IDLE;
                end else if (battery_percent >= SLOW_START_CYCLE) begin
                    next_state = SLOW_CHARGING; // Switch to slow charging after 80%
                end else begin
                    // Check for 10% battery increment to increase temperature
                    // if ((battery_percent % 10) == 0)
                    if ((battery_percent >= 10) && (prev_battery_percent < 10) ||
                        (battery_percent >= 20) && (prev_battery_percent < 20) ||
                        (battery_percent >= 30) && (prev_battery_percent < 30) ||
                        (battery_percent >= 40) && (prev_battery_percent < 40) ||
                        (battery_percent >= 50) && (prev_battery_percent < 50) ||
                        (battery_percent >= 60) && (prev_battery_percent < 60) ||
                        (battery_percent >= 70) && (prev_battery_percent < 70) ||
                        (battery_percent >= 80) && (prev_battery_percent < 80)) begin
                        
                        temp_next = temp + 7'd1; // Increase temperature by 1°C
                        
                        if (temp_next >= MAX_TEMP) begin
                            next_state = SLOW_CHARGING; // Overheating: Switch to slow charging
                            cooling_fan_next = 1'b1; // Activate cooling fan on overheating
                        end
                    end
                end
            end

            SLOW_CHARGING: begin
                charging_mode_next = 1'b1; // Slow charging mode
                
                if (!charging) begin
                    next_state = IDLE;
                end else begin
                    // Temperature management in slow charging
                    if (temp > MAX_TEMP) begin
                        temp_next = temp - 7'd1; // Decrease temperature slowly
                        cooling_fan_next = 1'b1; // Keep cooling fan active
                    end else if (temp <= MAX_TEMP) begin
                        cooling_fan_next = 1'b0; // Deactivate cooling fan when temperature is controlled
                        
                        // Check for 20% battery increment in slow charging
                        if ((battery_percent >= 80) && (prev_battery_percent < 80) ||
                            (battery_percent >= 100) && (prev_battery_percent < 100)) begin
                            temp_next = temp + 7'd1; // Increment temperature by 1°C for every 20% increase
                        end
                    end
                    
                    // Ensure temperature doesn't go below minimum
                    if (temp_next < MIN_TEMP) begin
                        temp_next = MIN_TEMP;
                    end
                end
            end

            default: begin
                next_state = IDLE;
                charging_mode_next = 1'b0;
                cooling_fan_next = 1'b0;
            end
        endcase
    end

endmodule
