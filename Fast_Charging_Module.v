module FastCharging (
    input wire clk,
    input wire reset,
    input wire charger_plugged, // Signal to indicate if charger is plugged in
    output reg [7:0] battery_level, // Battery percentage (0 to 100)
    output wire gated_clock,
    output reg [1:0] present_state, // 2-bit state: 00 - IDLE, 01 - FAST_CHARGING, 10 - SLOW_CHARGING
    output reg [1:0] next_state
);

// State encoding
localparam IDLE = 2'b00;
localparam FAST_CHARGING = 2'b01;
localparam SLOW_CHARGING = 2'b10;

// Gated clock logic
reg clk_gate;
assign gated_clock = clk & clk_gate;

// Initial state
initial begin
    battery_level = 0;
    present_state = IDLE;
    next_state = IDLE;
    clk_gate = 0;
end

// State and battery logic
always @(posedge clk or posedge reset) begin
    if (reset) begin
        battery_level <= 0;
        present_state <= IDLE;
        next_state <= IDLE;
        clk_gate <= 0;
    end else begin
        present_state <= next_state;
        case (present_state)
            IDLE: begin
                if (charger_plugged && battery_level < 100) begin
                    if (battery_level <= 80) begin
                        next_state <= FAST_CHARGING;
                        clk_gate <= 1; // Enable gated clock
                    end else begin
                        next_state <= SLOW_CHARGING;
                        clk_gate <= 1; // Enable gated clock
                    end
                end else if (charger_plugged && battery_level == 100) begin
                    clk_gate <= 0; // Disable gated clock to save power
                    next_state <= IDLE;
                end
            end
            FAST_CHARGING: begin
                if (!charger_plugged) begin
                    next_state <= IDLE;
                    clk_gate <= 0; // Disable gated clock
                end else if (battery_level < 80) begin
                    battery_level <= battery_level + 1;
                    next_state <= FAST_CHARGING;
                end else begin
                    next_state <= SLOW_CHARGING;
                end
            end
            SLOW_CHARGING: begin
                if (!charger_plugged) begin
                    next_state <= IDLE;
                    clk_gate <= 0; // Disable gated clock
                end else if (battery_level < 100) begin
                    battery_level <= battery_level + 1;
                    next_state <= SLOW_CHARGING;
                end else if (battery_level == 100) begin
                    clk_gate <= 0; // Disable gated clock to save power
                    next_state <= IDLE;
                end
            end
            default: next_state <= IDLE;
        endcase

        // Detect discharge from 100% and re-enable clock
        if (charger_plugged && battery_level < 100 && present_state == IDLE) begin
            clk_gate <= 1; // Re-enable gated clock
            next_state <= (battery_level <= 80) ? FAST_CHARGING : SLOW_CHARGING;
        end
    end
end

endmodule