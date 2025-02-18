// Temperature Module for Fast Charging Battery Management

module temperature_control (
    input wire clk,
    input wire reset,
    input wire charging,
    input wire [6:0] battery_percent,
    output reg [6:0] temp,
    output reg charging_mode, // 0 = Fast Charging, 1 = Slow Charging
    output reg cooling_fan // 1 = Cooling fan active, 0 = Cooling fan inactive
);

    // States
    typedef enum logic [1:0] {
        IDLE = 2'b00,
        FAST_CHARGING = 2'b01,
        SLOW_CHARGING = 2'b10
    } state_t;

    state_t present_state, next_state;

    // Constants  
    localparam INITIAL_TEMP = 7'd27; // Initial temperature is 27°C
    localparam MAX_TEMP = 7'd45;     // Maximum temperature before switching to slow charging
    localparam MIN_TEMP = 7'd27;     // Minimum temperature limit
    localparam SLOW_START_CYCLE = 7'd80; // Clock cycle to start slow charging
    localparam SLOW_END_CYCLE = 7'd100;  // Clock cycle for end of slow charging

    // Internal signal to track increments
    reg [3:0] battery_count; // To count 10% increments (0 to 10)
    reg [4:0] battery_count_slow; // To count 20% increments (0 to 20)

    // Sequential Logic: State Transitions
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            present_state <= IDLE;
            temp <= INITIAL_TEMP;
            battery_count <= battery_percent % 10;
            battery_count_slow <= battery_percent % 20;
            cooling_fan <= 1'b0; // Ensure cooling fan is inactive on reset
        end else begin
            present_state <= next_state;
        end
    end

    // Combinational Logic: Next State and Output Logic
    always @(*) begin
        // Default values
        next_state = present_state;
        charging_mode = 1'b0; // Default to Fast Charging
        cooling_fan = 1'b0; // Default to cooling fan inactive

        case (present_state)
            IDLE: begin
                if (charging && (battery_percent < SLOW_START_CYCLE)) begin
                    next_state = FAST_CHARGING;
                end else if (charging && (battery_percent >= SLOW_START_CYCLE) && (battery_percent <= SLOW_END_CYCLE)) begin
                    next_state = SLOW_CHARGING; // Switch to slow charging for clock cycles 80 to 100
                end else begin
                    next_state = IDLE;
                end
            end

            FAST_CHARGING: begin
                if (charging) begin
                    if (battery_percent < SLOW_START_CYCLE) begin
                        if ((battery_percent % 10) == 0) begin
                            temp = temp + 7'd1; // Increase temperature by 1°C
                            if (temp >= MAX_TEMP) begin
                                next_state = SLOW_CHARGING; // Overheating: Switch to slow charging
                                cooling_fan = 1'b1; // Activate cooling fan on overheating
                            end
                        end
                    end else begin
                        next_state = SLOW_CHARGING; // Automatically switch to slow charging after cycle 80
                    end
                end else begin
                    next_state = IDLE; // Charger unplugged
                end
            end

            SLOW_CHARGING: begin
                charging_mode = 1'b1; // Slow charging mode
                if (!charging) begin
                    next_state = IDLE;
                end else if ((battery_percent >= SLOW_START_CYCLE) && (battery_percent <= SLOW_END_CYCLE)) begin
                    if (temp > MAX_TEMP) begin
                        temp = temp - 7'd1; // Decrease temperature slowly
                        cooling_fan = 1'b1; // Keep cooling fan active if temperature exceeds max
                    end else if (temp < MAX_TEMP && (battery_percent % 20) == 0) begin
                        temp = temp + 7'd1; // Increment temperature by 1°C for every 20% battery increase
                    end

                    temp = (temp < MIN_TEMP) ? MIN_TEMP : temp; // Clamp temperature to MIN_TEMP
                end

                if (temp <= MAX_TEMP) begin
                    cooling_fan = 1'b0; // Deactivate cooling fan when temperature is under control
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Preserve temperature in IDLE state
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            temp <= INITIAL_TEMP;
        end else if (present_state == IDLE) begin
            temp <= temp; // Hold the temperature
        end
    end

endmodule