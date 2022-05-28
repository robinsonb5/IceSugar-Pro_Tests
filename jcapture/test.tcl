#
# IceSugarPro demo JTAG script
#

init
scan_chain

set capture_fields {
	{ count_lo 16 }
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


proc led {v} {
	::jcapture::virscan ecp5.tap write
	::jcapture::vdrscan ecp5.tap $::jcapture::capture_width $v
}


puts "Turning on LED"
led 1

puts "Setting capture parameters..."

# We only care about bit 8 of count_lo - we want it to be a rising edge
::jcapture::settrigger mask count_lo 0x100
::jcapture::settrigger edge count_lo 0x100
::jcapture::settrigger value count_lo 0x100

# We want an exact match on bits 7:0 of count_hi, with 0xaa
::jcapture::settrigger value count_hi 0xaa
::jcapture::settrigger mask count_hi 0xff

# No lead-in
::jcapture::setleadin 0

# Send capture parameters and start capturing...
::jcapture::capture

puts "Waiting for the FIFO"
::jcapture::wait_fifofull

puts "Collecting the FIFO contents"
puts "Capture should start when bits 23:16 are 0x55 and bit 8 rises."
::jcapture::dump_fifo

puts ""
puts "Repeating the capture with a 1/4 lead-in."
::jcapture::setleadin 3


# Change LED colour
led 2

::jcapture::capture

puts "Waiting for the FIFO to fill"
::jcapture::wait_fifofull

# Change LED colour again
led 4

puts "Collecting the FIFO contents"
puts "Capture should start when bits 23:16 are 0x55 and bit 8 rises,"
puts "after a lead-in of 1/4 of the FIFO's depth."

::jcapture::dump_fifo

# Turn off the LEDs

puts "Turning off LED"
led 0

puts "Done."
exit


