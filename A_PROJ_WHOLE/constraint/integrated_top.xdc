# ================= CLOCK =================

set_property PACKAGE_PIN P17 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# ================= RESET =================

set_property PACKAGE_PIN P15 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

# ================= BUTTONS ================
# S0_send
set_property PACKAGE_PIN R11 [get_ports btn_send]
set_property IOSTANDARD LVCMOS33 [get_ports btn_send]

# S3_confirm
set_property PACKAGE_PIN V1 [get_ports btn_confirm]
set_property IOSTANDARD LVCMOS33 [get_ports btn_confirm]

# ================= SWITCHES ================
set_property PACKAGE_PIN U3 [get_ports {sw_right[7]}]      
set_property IOSTANDARD LVCMOS33 [get_ports {sw_right[7]}]

set_property PACKAGE_PIN U2 [get_ports {sw_right[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw_right[6]}]

set_property PACKAGE_PIN V2 [get_ports {sw_right[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw_right[5]}]

set_property PACKAGE_PIN V5 [get_ports {sw_right[4]}]     
set_property IOSTANDARD LVCMOS33 [get_ports {sw_right[4]}]

set_property PACKAGE_PIN V4 [get_ports {sw_right[3]}]      
set_property IOSTANDARD LVCMOS33 [get_ports {sw_right[3]}]

set_property PACKAGE_PIN R3 [get_ports {sw_right[2]}]     
set_property IOSTANDARD LVCMOS33 [get_ports {sw_right[2]}]

set_property PACKAGE_PIN T3 [get_ports {sw_right[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw_right[1]}]

set_property PACKAGE_PIN T5 [get_ports {sw_right[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw_right[0]}]

set_property PACKAGE_PIN R1 [get_ports {sw_left[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw_left[0]}]

set_property PACKAGE_PIN N4 [get_ports {sw_left[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw_left[1]}]

set_property PACKAGE_PIN M4 [get_ports {sw_left[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw_left[2]}]

set_property PACKAGE_PIN R2 [get_ports {sw_left[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw_left[3]}]

set_property PACKAGE_PIN P2 [get_ports {sw_left[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw_left[4]}]

set_property PACKAGE_PIN P3 [get_ports {sw_left[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw_left[5]}]

set_property PACKAGE_PIN P4 [get_ports {sw_left[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw_left[6]}]

set_property PACKAGE_PIN P5 [get_ports {sw_left[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw_left[7]}]
# ================= LEDS ==================

# LED0_uart_rx
set_property PACKAGE_PIN K3 [get_ports LED0_uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports LED0_uart_rx]

# LED1_uart_tx
set_property PACKAGE_PIN M1 [get_ports LED1_uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports LED1_uart_tx]

# led_err
set_property PACKAGE_PIN F6 [get_ports led_error]
set_property IOSTANDARD LVCMOS33 [get_ports led_error]

# led_idle
set_property PACKAGE_PIN G4 [get_ports led_idle]
set_property IOSTANDARD LVCMOS33 [get_ports led_idle]

# led_busy
set_property PACKAGE_PIN G3 [get_ports led_busy]
set_property IOSTANDARD LVCMOS33 [get_ports led_busy]

# led_done
set_property PACKAGE_PIN J4 [get_ports led_done]
set_property IOSTANDARD LVCMOS33 [get_ports led_done]

# ================= 7-segment display ===============

## Group 0: DK1-DK4
set_property PACKAGE_PIN B4 [get_ports {seg0[0]}] ;# A0
set_property PACKAGE_PIN A4 [get_ports {seg0[1]}] ;# B0
set_property PACKAGE_PIN A3 [get_ports {seg0[2]}] ;# C0
set_property PACKAGE_PIN B1 [get_ports {seg0[3]}] ;# D0
set_property PACKAGE_PIN A1 [get_ports {seg0[4]}] ;# E0
set_property PACKAGE_PIN B3 [get_ports {seg0[5]}] ;# F0
set_property PACKAGE_PIN B2 [get_ports {seg0[6]}] ;# G0
set_property PACKAGE_PIN D5 [get_ports {seg0[7]}] ;# DP0
set_property IOSTANDARD LVCMOS33 [get_ports {seg0[*]}]

## Digit Enable for DK1-DK4

# DK1 
set_property PACKAGE_PIN G2 [get_ports dk1_en]
set_property IOSTANDARD LVCMOS33 [get_ports dk1_en]

# DK4 
set_property PACKAGE_PIN H1 [get_ports dk4_en]
set_property IOSTANDARD LVCMOS33 [get_ports dk4_en]

## Group 1: DK5-DK8
set_property PACKAGE_PIN D4 [get_ports {seg1[0]}] ;# A1
set_property PACKAGE_PIN E3 [get_ports {seg1[1]}] ;# B1
set_property PACKAGE_PIN D3 [get_ports {seg1[2]}] ;# C1
set_property PACKAGE_PIN F4 [get_ports {seg1[3]}] ;# D1
set_property PACKAGE_PIN F3 [get_ports {seg1[4]}] ;# E1
set_property PACKAGE_PIN E2 [get_ports {seg1[5]}] ;# F1
set_property PACKAGE_PIN D2 [get_ports {seg1[6]}] ;# G1
set_property PACKAGE_PIN H2 [get_ports {seg1[7]}] ;# DP1
set_property IOSTANDARD LVCMOS33 [get_ports {seg1[*]}]

## Digit Enable for DK5-DK8 

# DK5
set_property PACKAGE_PIN G1 [get_ports dk5_en]
set_property IOSTANDARD LVCMOS33 [get_ports dk5_en]

# DK6
set_property PACKAGE_PIN F1 [get_ports dk6_en]
set_property IOSTANDARD LVCMOS33 [get_ports dk6_en]

# DK7
set_property PACKAGE_PIN E1 [get_ports dk7_en]
set_property IOSTANDARD LVCMOS33 [get_ports dk7_en]

# DK8
set_property PACKAGE_PIN G6 [get_ports dk8_en]
set_property IOSTANDARD LVCMOS33 [get_ports dk8_en]

# ================= UART ===================

# UART RX 
set_property PACKAGE_PIN N5 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]

# UART TX 
set_property PACKAGE_PIN T4 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]

