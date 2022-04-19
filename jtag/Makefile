TARGET=jtagtest
TOP=jtagtest

VHDL_OBJS=debug_fifo.vhd top.vhd

TRELLIS=/usr/local/share/trellis

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
	yosys -m ghdl -p "ghdl top; synth_ecp5 -top top -json $@"

$(TARGET)_out.config: $(TARGET).json
	nextpnr-ecp5 --25k --package CABGA256 --speed 6 --json $< --textcfg $@ --lpf icesugarpro.lpf --freq 50

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

.PHONY: config clean run build

