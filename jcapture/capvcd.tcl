#
# IceSugarPro demo JTAG script
#

init
scan_chain


set capture_fields {
	{ lsb 1 }
	{ nsb 1 }
	{ count_lo 14 }
	{ count_hi 16 }
	{ id1 32 }
	{ id2 32 }
	{ id3 32 }
	{ id4 32 }
	{ id5 32 }
	{ id6 32 }
	{ id7 32 }
}

source jcapture.tcl

set capture_length [::jcapture::setup ecp5.tap $capture_fields]

# We only care about bit 4 of count_lo - we want it to be a rising edge
::jcapture::settrigger mask count_lo 0x0010
::jcapture::settrigger edge count_lo 0x0010
::jcapture::settrigger value count_lo 0x0010

# We want an exact match on bits 7:0 of count_hi, with 0xaa
::jcapture::settrigger value count_hi 0xaa
::jcapture::settrigger mask count_hi 0xff

while {1} {
	set chan [::jcapture::create_vcd capture.vcd -31]
	::jcapture::setleadin 3
	::jcapture::capture
	::jcapture::wait_fifofull
	::jcapture::fifo_to_vcd $chan 
	after 100
}

exit


