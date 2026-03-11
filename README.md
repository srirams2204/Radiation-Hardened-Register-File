# Radiation-Hardened Register File

Design of 32×32 bit dual port register file with single event upset prevention.

---

## Deliverables

**RTL:**  
Redundant storage array and the associated majority-voting/correction logic.

**Verification:**  
Simulation logs demonstrating fault tolerance when internal bits are forced to toggle.

**Synthesis:**  
Comparitive area report against a standard, non-redundant register implementation.

---

## Problem Statement

This project implements a **32×32-bit dual-port register file** that maintains data integrity in the presence of radiation-induced **Single Event Upsets (SEU)**.

The design uses **modular redundancy** and **majority voting** to detect and correct single-bit errors in stored data.

---

## Motivation

Radiation particles in space or high-altitude environments can flip memory bits, causing **Single Event Upsets (SEU)**. These errors can lead to incorrect system behavior in satellites, spacecraft, and safety-critical electronics.

To address this issue, **radiation-hardened digital circuits** use redundancy techniques to maintain correct operation even when faults occur.

---

## Block Diagram

<p align="center">
  <img src="pic/reg_file.png" width="400">
</p>

### Block Diagram Description

- The **`reg_wr` module** implements a **32 × 32-bit register file**.
- It supports **two read ports and one write port** for efficient data access.
- **`rs1` and `rs2`** are read address inputs used to select two registers simultaneously.
- The selected register values are output through **`rd1` and `rd2`**.
- **`rd`** specifies the register address where data will be written.
- **`rd_data`** is the input data that will be stored in the selected register.
- The **write operation is controlled by the clock signal (`clk`)**, ensuring synchronous updates.
- This architecture allows **parallel read operations and controlled write operations** within the register file.

---

## Architecture

To protect against **Single Event Upsets (SEU)**, the design implements **Triple Modular Redundancy (TMR)**.

Three identical register files are instantiated:

- RF_A  
- RF_B  
- RF_C  

All write operations update the three copies simultaneously.

During read operations, the outputs of the three register files are passed to a **majority voter**, which selects the correct value based on majority agreement.

---

## Majority Voter

The majority voter compares the outputs of the three redundant register files.

For each bit position:

- If two or more copies match, that value is selected as the correct output.
- If one copy is corrupted due to SEU, the other two correct copies determine the final output.

Example:

```
RF_A = 1011
RF_B = 1011
RF_C = 1001 (bit flipped)

Majority Output = 1011
```

---

## SEU Fault Tolerance

Single Event Upsets (SEU) occur when radiation particles flip stored memory bits.

In this design:

- Data is stored in **three redundant register files**.
- A **majority voter** masks the incorrect value from the corrupted copy.
- Correct data is still delivered to the output.

This ensures reliable operation even when radiation-induced faults occur.

---

## Modules

**reg.sv**

Implements the base **32×32 dual-port register file**.  
It supports two simultaneous read operations and one synchronous write operation using the clock signal.

**hard_reg.sv**

Implements the **radiation-hardened register file using redundancy**.  
This module instantiates multiple copies of the register file and applies **majority voting** to protect against **Single Event Upsets (SEU)**.

---

# Procedure to Run the Design

## 1. Clone the Repository

```bash
git clone https://github.com/srirams2204/Radiation-Hardened-Register-File.git
cd srirams2204/Radiation-Hardened-Register-File
```

---

# RTL Simulation (Verification)

RTL simulation is performed to verify the functionality of the radiation-hardened register file and demonstrate tolerance against **Single Event Upsets (SEU)**.

## Steps

### 1. Compile the RTL files

```bash
vcs -full64 -sverilog rtl/hard_reg.sv tb/hardReg_tb.sv -debug_access+all -lca -kdb
```

### 2. Run the simulation

```bash
./simv Verdi
```


---

## Expected Result

- Data is written to the register file correctly.
- Two registers can be read simultaneously.
- When a bit flip is injected in one redundant register copy, the **majority voter masks the error**, producing the correct output.

---

# Synthesis (Using Synopsys Design Compiler)

Synthesis converts the RTL design into a **gate-level netlist** and generates **area reports**.

## Steps

### 1. Launch Design Compiler

```bash
dc_shell
```

### 2. Run the synthesis script

```tcl
source run_dc.tcl
```

Typical synthesis script includes:

- Reading RTL files
- Setting technology library
- Applying constraints
- Compiling the design
- Generating reports

---

# Comparing Standard vs Radiation-Hardened Design

To analyze the overhead introduced by redundancy, both the **standard register file** and the **radiation-hardened design** are synthesized and compared.

## Steps

1. Synthesize **`reg.sv`** (standard register file).  
2. Synthesize **`hard_reg.sv`** (radiation-hardened register file).  
3. Generate the synthesis reports using **Synopsys Design Compiler**.  
4. Compare the **area reports** of both designs.

---

# Results 
## Timing Report (after retime)

<div align="center">

| Parameter (ns) | Normal Reg File | Hardened Reg File |
|----------|-------| --------|
| Clock Period  | 2.2 | 2.2 |
| Data Required Time | 1.40 | 1.40 |
| Data Arrival Time | -1.40 | -1.40 |
| Hold Violations | 0 | 0|
| Slack | 0 (MET) | 0 (MET) |

</div>

---

## Area Report

<div align="center">

| Parameter | Normal Reg File | Hardened Reg File |
|-----------------------|-------|-----------------|
| Ports                 | 113 | 113 |
| Nets                  | 3619 | 9042 | 
| Cells                 | 3570 | 8993 |
| Total Cell Area (µm²) | 13087.1455 | 14331.9426 |
| Total Area (µm²)      | 18614.4979 | 24622.6721 |

</div>

---

## Power Report

<div align="center">

| Parameter | Normal Reg File | Hardened Reg File |
|----------|-------|------------|
| Switching Power | 24.9706 µW | 79.1454 µW |
| Leakage Power | 2.1639 × 10⁷ pW | 2.8040  × 10⁷ pW |
| Total Power | 202.1359 µW | 231.2428 µW |

</div>



