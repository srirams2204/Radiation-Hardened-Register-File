# Radiation-Hardened-Register-File
Design of 32x32 bit dual port register file with signle event upset prevention.

## Deliverables: 
RTL: Redundant storage array and the associated majority-voting/correction logic
Verification: Simulation logs demonstrating fault tolerance when internal bits are forced to toggle.
Synthesis: Comparitive area report against a standard, non-redundant register implementation.
## Problem Statement
This project implements a 32×32-bit dual-port register file that maintains data 
integrity in the presence of radiation-induced Single Event Upsets (SEU).

The design uses modular redundancy and majority voting to detect and correct 
single-bit errors in stored data.

## Motivation 
Radiation particles in space or high-altitude environments can flip memory bits,
causing Single Event Upsets (SEU). These errors can lead to incorrect system
behavior in satellites, spacecraft, and safety-critical electronics.

To address this issue, radiation-hardened digital circuits use redundancy
techniques to maintain correct operation even when faults occur.

## Block Diagram

<p align="center">
  <img src="DOCS/reg_file.png" width="400">
</p>

### Block Diagram Description

* The **`reg_wr` module** implements a **32 × 32-bit register file**.
* It supports **two read ports and one write port** for efficient data access.
* **`rs1` and `rs2`** are read address inputs used to select two registers simultaneously.
* The selected register values are output through **`rd1` and `rd2`**.
* **`rd`** specifies the register address where data will be written.
* **`rd_data`** is the input data that will be stored in the selected register.
* The **write operation is controlled by the clock signal (`clk`)**, ensuring synchronous updates.
* This architecture allows **parallel read operations and controlled write operations** within the register file.

## Architecture

To protect against Single Event Upsets (SEU), the design implements
Triple Modular Redundancy (TMR).

Three identical register files are instantiated:

- RF_A
- RF_B
- RF_C

All write operations update the three copies simultaneously.
During read operations, the outputs of the three register files are
passed to a majority voter which selects the correct value based on
majority agreement.
## Majority Voter

The majority voter compares the outputs of the three redundant
register files.

For each bit position:

- If two or more copies match, that value is selected as the correct output.
- If one copy is corrupted due to SEU, the other two correct copies
determine the final output.

Example:

RF_A = 1011  
RF_B = 1011  
RF_C = 1001 (bit flipped)

Majority Output = 1011
## SEU Fault Tolerance

Single Event Upsets (SEU) occur when radiation particles flip
stored memory bits.

In this design:

- Data is stored in three redundant register files.
- A majority voter masks the incorrect value from the corrupted copy.
- Correct data is still delivered to the output.

This ensures reliable operation even when radiation-induced faults occur.
## Modules

reg.sv  
Implements the base **32×32 dual-port register file**.  
It supports two simultaneous read operations and one synchronous write operation using the clock signal.

hard_reg.sv  
Implements the **radiation-hardened register file** using redundancy.  
This module instantiates multiple copies of the register file and applies **majority voting** to protect against **Single Event Upsets (SEU)**.

## Procedure to Run the Design




