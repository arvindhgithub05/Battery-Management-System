`timescale 1ns / 1ps

module tb_Battery_Management_System();

    // =========================================================================
    // Testbench Signals
    // =========================================================================
    
    // Primary inputs
    reg clk;
    reg reset;
    reg reset_n;
    reg charger_plugged;
    reg [7:0] voltage;
    reg moisture_sensor;
    
    // Primary outputs
    wire [7:0] battery_level;
    wire [6:0] temperature;
    wire gated_clock;
    wire [1:0] charging_state;
    wire [1:0] charging_mode;
    wire cooling_fan;
    wire pulse_20;
    wire pulse_80;
    wire pulse_100;
    wire overcharge_alert;
    wire charge_enable_final;
    
    // Test control variables
    integer test_case;
    integer cycle_count;
    reg [255:0] test_description;
    
    // Clock generation (100MHz -> 10ns period)
    always #5 clk = ~clk;
    
    // =========================================================================
    // Device Under Test (DUT) Instantiation
    // =========================================================================
    
    Battery_Management_System_top DUT (
        .clk(clk),
        .reset(reset),
        .reset_n(reset_n),
        .charger_plugged(charger_plugged),
        .voltage(voltage),
        .moisture_sensor(moisture_sensor),
        .battery_level(battery_level),
        .temperature(temperature),
        .gated_clock(gated_clock),
        .charging_state(charging_state),
        .charging_mode(charging_mode),
        .cooling_fan(cooling_fan),
        .pulse_20(pulse_20),
        .pulse_80(pulse_80),
        .pulse_100(pulse_100),
        .overcharge_alert(overcharge_alert),
        .charge_enable_final(charge_enable_final)
    );
    
    // =========================================================================
    // Monitoring and Display Tasks
    // =========================================================================
    
    task display_status;
        begin
            $display("=== Cycle %0d - %s ===", cycle_count, test_description);
            $display("Battery: %0d%% | Temp: %0d°C | Voltage: %0d | State: %s", 
                     battery_level, temperature, voltage, 
                     (charging_state == 2'b00) ? "IDLE" : 
                     (charging_state == 2'b01) ? "FAST" : 
                     (charging_state == 2'b10) ? "SLOW" : "UNKNOWN");
            $display("Charger: %b | Moisture: %b | Charge Enable: %b | Cooling Fan: %b", 
                     charger_plugged, moisture_sensor, charge_enable_final, cooling_fan);
            $display("Pulses: 20%%:%b 80%%:%b 100%%:%b | Overcharge: %b", 
                     pulse_20, pulse_80, pulse_100, overcharge_alert);
            $display("Charging Mode: %s | Gated Clock: %b", 
                     (charging_mode[0] == 1'b0) ? "FAST" : "SLOW", gated_clock);
            $display("----------------------------------------");
        end
    endtask
    
    task wait_cycles;
        input integer num_cycles;
        integer i;
        begin
            for (i = 0; i < num_cycles; i = i + 1) begin
                @(posedge clk);
                cycle_count = cycle_count + 1;
            end
        end
    endtask
    
    task wait_and_display;
        input integer num_cycles;
        begin
            wait_cycles(num_cycles);
            display_status();
        end
    endtask
    
    // =========================================================================
    // Test Scenario Tasks
    // =========================================================================
    
    task reset_system;
        begin
            test_description = "System Reset";
            reset = 1'b1;
            reset_n = 1'b0;
            charger_plugged = 1'b0;
            voltage = 8'd0;
            moisture_sensor = 1'b0;
            wait_cycles(5);
            reset = 1'b0;
            reset_n = 1'b1;
            wait_and_display(2);
        end
    endtask
    
    task test_normal_charging_cycle;
        begin
            $display("\n*** TEST: Normal Charging Cycle (0% to 100%) ***");
            test_description = "Normal Charging - Start";
            
            // Plug in charger with normal voltage
            charger_plugged = 1'b1;
            voltage = 8'd200; // Normal voltage
            moisture_sensor = 1'b0;
            wait_and_display(5);
            
            // Monitor fast charging phase (0% to 80%)
            test_description = "Fast Charging Phase";
            while (battery_level < 80) begin
                wait_cycles(10);
                if (cycle_count % 50 == 0) display_status();
            end
            
            $display("\n*** Reached 80% - Should switch to slow charging ***");
            wait_and_display(5);
            
            // Monitor slow charging phase (80% to 100%)
            test_description = "Slow Charging Phase";
            while (battery_level < 100) begin
                wait_cycles(10);
                if (cycle_count % 50 == 0) display_status();
            end
            
            $display("\n*** Reached 100% - Charging should stop ***");
            wait_and_display(10);
        end
    endtask
    
    task test_moisture_detection;
        begin
            $display("\n*** TEST: Moisture Detection Safety ***");
            
            // Reset battery level to mid-range for testing
            reset_system();
            
            // Start normal charging
            test_description = "Charging Before Moisture";
            charger_plugged = 1'b1;
            voltage = 8'd180;
            moisture_sensor = 1'b0;
            wait_and_display(20);
            
            // Introduce moisture
            test_description = "Moisture Detected - Should Stop Charging";
            moisture_sensor = 1'b1;
            wait_and_display(10);
            
            // Remove moisture
            test_description = "Moisture Cleared - Should Resume Charging";
            moisture_sensor = 1'b0;
            wait_and_display(10);
            
            // Test moisture with charger unplugged
            test_description = "Moisture + No Charger";
            charger_plugged = 1'b0;
            moisture_sensor = 1'b1;
            wait_and_display(5);
            
            // Clean up
            moisture_sensor = 1'b0;
            charger_plugged = 1'b1;
            wait_and_display(5);
        end
    endtask
    
    task test_overcharge_protection;
        begin
            $display("\n*** TEST: Overcharge Protection ***");
            
            // Force battery to near full for faster testing
            test_description = "Preparing for Overcharge Test";
            charger_plugged = 1'b1;
            voltage = 8'd200;
            moisture_sensor = 1'b0;
            
            // Wait until battery reaches 100%
            while (battery_level < 100) begin
                wait_cycles(5);
                if (cycle_count % 30 == 0) display_status();
            end
            
            // Normal voltage at 100% - should stop charging
            test_description = "100% Battery - Normal Voltage";
            voltage = 8'd200;
            wait_and_display(10);
            
            // High voltage at 100% - should trigger overcharge protection
            test_description = "100% Battery - HIGH VOLTAGE (Overcharge)";
            voltage = 8'd255; // Maximum voltage
            wait_and_display(15);
            
            // Reduce voltage but keep at 100%
            test_description = "100% Battery - Voltage Normalized";
            voltage = 8'd200;
            wait_and_display(10);
        end
    endtask
    
    task test_temperature_management;
        begin
            $display("\n*** TEST: Temperature Management ***");
            
            reset_system();
            
            test_description = "Temperature Monitoring - Start Charging";
            charger_plugged = 1'b1;
            voltage = 8'd180;
            moisture_sensor = 1'b0;
            wait_and_display(5);
            
            // Monitor temperature during charging
            test_description = "Monitoring Temperature Rise";
            while (battery_level < 50 && temperature < 45) begin
                wait_cycles(15);
                if (cycle_count % 60 == 0) begin
                    $display("Battery: %0d%% | Temperature: %0d°C | Cooling Fan: %b", 
                             battery_level, temperature, cooling_fan);
                end
            end
            
            $display("\n*** Temperature Status Check ***");
            display_status();
            
            // Continue to see cooling fan activation
            test_description = "High Temperature - Cooling Fan Test";
            while (battery_level < 90) begin
                wait_cycles(10);
                if (cycle_count % 40 == 0) display_status();
            end
        end
    endtask
    
    task test_pulse_generation;
        begin
            $display("\n*** TEST: Battery Level Pulse Generation ***");
            
            reset_system();
            
            test_description = "Monitoring for 20% Pulse";
            charger_plugged = 1'b1;
            voltage = 8'd180;
            moisture_sensor = 1'b0;
            
            // Watch for 20% pulse (if starting from 0)
            while (battery_level < 25) begin
                if (pulse_20) begin
                    $display("\n*** 20%% PULSE DETECTED at cycle %0d ***", cycle_count);
                    display_status();
                end
                wait_cycles(5);
            end
            
            // Watch for 80% pulse
            test_description = "Monitoring for 80% Pulse";
            while (battery_level < 85) begin
                if (pulse_80) begin
                    $display("\n*** 80%% PULSE DETECTED at cycle %0d ***", cycle_count);
                    display_status();
                end
                wait_cycles(5);
            end
            
            // Watch for 100% pulse
            test_description = "Monitoring for 100% Pulse";
            while (battery_level < 100) begin
                if (pulse_100) begin
                    $display("\n*** 100%% PULSE DETECTED at cycle %0d ***", cycle_count);
                    display_status();
                end
                wait_cycles(5);
            end
            
            wait_and_display(10);
        end
    endtask
    
    task test_charger_plug_unplug;
        begin
            $display("\n*** TEST: Charger Plug/Unplug Scenarios ***");
            
            reset_system();
            
            // Start charging
            test_description = "Charger Plugged - Start Charging";
            charger_plugged = 1'b1;
            voltage = 8'd200;
            moisture_sensor = 1'b0;
            wait_and_display(20);
            
            // Unplug charger during charging
            test_description = "Charger UNPLUGGED During Charging";
            charger_plugged = 1'b0;
            wait_and_display(10);
            
            // Plug back in
            test_description = "Charger PLUGGED Back In";
            charger_plugged = 1'b1;
            wait_and_display(15);
            
            // Rapid plug/unplug test
            test_description = "Rapid Plug/Unplug Test";
            repeat(5) begin
                charger_plugged = 1'b0;
                wait_cycles(3);
                charger_plugged = 1'b1;
                wait_cycles(3);
            end
            wait_and_display(5);
        end
    endtask
    
    task test_edge_cases;
        begin
            $display("\n*** TEST: Edge Cases and Stress Tests ***");
            
            // Test simultaneous conditions
            test_description = "Multiple Conditions: Moisture + High Voltage";
            reset_system();
            charger_plugged = 1'b1;
            voltage = 8'd255; // High voltage
            moisture_sensor = 1'b1; // Moisture present
            wait_and_display(10);
            
            // Clear moisture but keep high voltage
            test_description = "High Voltage Only";
            moisture_sensor = 1'b0;
            wait_and_display(10);
            
            // Normalize voltage
            test_description = "All Conditions Normal";
            voltage = 8'd200;
            wait_and_display(15);
            
            // Test voltage variations
            test_description = "Voltage Sweep Test";
            voltage = 8'd50;  wait_cycles(5); display_status();
            voltage = 8'd100; wait_cycles(5); display_status();
            voltage = 8'd150; wait_cycles(5); display_status();
            voltage = 8'd200; wait_cycles(5); display_status();
            voltage = 8'd250; wait_cycles(5); display_status();
            voltage = 8'd255; wait_cycles(5); display_status();
            
            // Reset to normal
            voltage = 8'd180;
            wait_and_display(5);
        end
    endtask
    
    // =========================================================================
    // Main Test Execution
    // =========================================================================
    
    initial begin
        // Initialize simulation
        $display("=====================================");
        $display("Battery Management System Testbench");
        $display("=====================================");
        
        // Initialize signals
        clk = 1'b0;
        cycle_count = 0;
        test_case = 0;
        
        // Setup waveform dump
        $dumpfile("battery_management_tb.vcd");
        $dumpvars(0, tb_Battery_Management_System);
        
        // Execute test sequence
        reset_system();
        
        test_case = 1; test_normal_charging_cycle();
        test_case = 2; test_moisture_detection();
        test_case = 3; test_overcharge_protection();
        test_case = 4; test_temperature_management();
        test_case = 5; test_pulse_generation();
        test_case = 6; test_charger_plug_unplug();
        test_case = 7; test_edge_cases();
        
        // Final summary
        $display("\n=====================================");
        $display("All Tests Completed Successfully!");
        $display("Total Simulation Cycles: %0d", cycle_count);
        $display("Final Battery Level: %0d%%", battery_level);
        $display("Final Temperature: %0d°C", temperature);
        $display("=====================================");
        
        // End simulation
        #100;
        $finish;
    end
    
    // =========================================================================
    // Continuous Monitoring (for catching unexpected events)
    // =========================================================================
    
    // Monitor for critical alerts
    always @(posedge overcharge_alert) begin
        $display("\n!!! OVERCHARGE ALERT TRIGGERED at time %0t !!!", $time);
        display_status();
    end
    
    // Monitor temperature extremes
    always @(temperature) begin
        if (temperature > 50) begin
            $display("\n!!! CRITICAL TEMPERATURE: %0d°C at time %0t !!!", temperature, $time);
        end
    end
    
    // Monitor charging state transitions
    always @(charging_state) begin
        case (charging_state)
            2'b00: $display(">>> State Transition: IDLE at time %0t", $time);
            2'b01: $display(">>> State Transition: FAST_CHARGING at time %0t", $time);
            2'b10: $display(">>> State Transition: SLOW_CHARGING at time %0t", $time);
            default: $display(">>> State Transition: UNKNOWN at time %0t", $time);
        endcase
    end
    
    // Safety timeout (prevent infinite loops)
    initial begin
        #1000000; // 1ms timeout
        $display("\n!!! SIMULATION TIMEOUT - Ending Test !!!");
        $finish;
    end
    
endmodule