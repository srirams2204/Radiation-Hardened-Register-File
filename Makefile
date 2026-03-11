# --- Variables ---
VCS = vcs
SIMV = ./simv
# Coverage directory
COV_DIR = coverage_report.vdb
# Source files
RTL_FILES = rtl/hard_reg.sv rtl/reg.sv
TB_FILES = tb/hardReg_tb.sv
# Compile options: -sverilog for SV, -cm for coverage
VCS_FLAGS = -sverilog -full64 -debug_access+all -cm line+cond+fsm+tgl+branch -cm_dir $(COV_DIR)

# --- Targets ---

# 1. Compile
comp:
	$(VCS) $(VCS_FLAGS) $(RTL_FILES) $(TB_FILES) -o simv

# 2. Run Simulation
sim: comp
	$(SIMV) -cm line+cond+fsm+tgl+branch -cm_dir $(COV_DIR) -l simulation.log

# 3. View Coverage (Opens DVE)
view_cov:
	dve -cov -dir $(COV_DIR) &

# 4. Clean up
clean:
	rm -rf simv* *.log *.key csrc *.vdb DVEfiles