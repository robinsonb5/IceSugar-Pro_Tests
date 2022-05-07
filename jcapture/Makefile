TARGET=jtagtest
TOP=jtagtest

VHDL_OBJS=cdc_pulse.vhd vjtag_fifo.vhd vjtag_ecp5.vhd jcapture_pkg.vhd jcapture.vhd top.vhd
VERILOG_OBJS=../PLL/ECP5/ecp5pll.sv

all:
	$(info IceSugar-Pro JTAG test.)
	$(info ~~~~~~~~~~~~~~~~~~~~~~~)
	$(info Make sure the oss-cad-suite environment is active, then use one of: )
	$(info )
	$(info > make clean - remove any generated files from the project directory. )
	$(info )
	$(info > make build - compile the project using Yosys and friends. )
	$(info )
	$(info > make config - configure the FPGA temporarily with the compiled project.)
	$(info )
	$(info > make run - execute a Tcl script to interact with the configured FPGA.)
	$(info )

$(TARGET).json: $(VHDL_OBJS)
	ghdl -a $(VHDL_OBJS)
	yosys -m ghdl -p "read_verilog $(VERILOG_OBJS); ghdl top; synth_ecp5 -abc9 -top top -json $@"

$(TARGET)_out.config: $(TARGET).json
	nextpnr-ecp5 --25k --package CABGA256 --speed 6 --json $< --textcfg $@ --lpf ../board/icesugarpro.lpf --freq 25

$(TARGET).bit: $(TARGET)_out.config
	ecppack --svf ${TARGET}.svf $< $@

${TARGET}.svf : ${TARGET}.bit

build: ${TARGET}.svf

run: ${TARGET}.svf
	openocd -f ../tools/cmsisdap.cfg -f test.tcl

config: ${TARGET}.svf
	openocd -f ../tools/cmsisdap.cfg -c \
	"   init; \
	    scan_chain; \
	    svf -tap ecp5.tap -quiet -progress ${TARGET}.svf; \
	    exit;"

clean:
	rm -f *.svf *.bit *.config *.o *.ys *.json *.cf

sim:
	ghdl -a debug_fifo.vhd sim.vhd
	ghdl -e sim
	ghdl -r sim --wave=sim.ghw --stop-time=5000ns

.PHONY: config clean run build sim


