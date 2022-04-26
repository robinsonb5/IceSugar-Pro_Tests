#
# IceSugarPro demo JTAG script
#

init
scan_chain

# Virtual IR scan - shifts a value into a register attached to ER1
proc virscan {tap v} {
	irscan $tap 0x32
	return [drscan $tap 4 $v]
}

# Virtual DR scan - shifts a value into a register attached to ER2
proc vdrscan {tap c v} {
	irscan $tap 0x38
	return [drscan $tap $c $v]
}

# Commands for the jcapture module
set jcapture_status 0x0
set jcapture_write 0x3
set jcapture_setleadin 0x4
set jcapture_setmask 0x5
set jcapture_setinvert 0x6
set jcapture_setedge 0x7
set jcapture_capture 0x8

set jcapture_flag_busy 0x1
set jcapture_flag_full 0x2
set jcapture_flag_empty 0x4


# Wait for the busy flag to fall 
proc wait_fifo { tap } {
	global jcapture_status jcapture_flag_busy
	set status [virscan $tap $jcapture_status]
	while {[expr "0x$status & $jcapture_flag_busy"] != 0 } {
		set status [virscan $tap $jcapture_status]
	}
}

# Dump the FIFO contents to the shell window
proc dump_fifo { tap } {
	global jcapture_status jcapture_flag_empty
	set status [virscan $tap $jcapture_status]
	while {[expr "0x$status & $jcapture_flag_empty"] == 0 } {
		puts [vdrscan $tap 256 0]
		set status [virscan ecp5.tap $jcapture_status]
	}
}

# Silently empty the FIFO.
proc flush_fifo { tap } {
	global jcapture_status jcapture_flag_empty
	set status [virscan $tap $jcapture_status]
	while {[expr "0x$status & $jcapture_flag_empty"] == 0 } {
		vdrscan $tap 256 0
		set status [virscan ecp5.tap $jcapture_status]
	}
}


# Make sure the FIFO is empty before we start.
flush_fifo ecp5.tap

puts "Turning on LED"
virscan ecp5.tap $jcapture_write
vdrscan ecp5.tap 256 1

puts "Setting capture parameters..."
virscan ecp5.tap $jcapture_setmask
vdrscan ecp5.tap 256 0xff0100

virscan ecp5.tap $jcapture_setedge
vdrscan ecp5.tap 256 0x000100]

virscan ecp5.tap $jcapture_setinvert]
vdrscan ecp5.tap 256 0x550100

virscan ecp5.tap $jcapture_capture]

puts "Waiting for the FIFO"
wait_fifo ecp5.tap

puts "Collecting the FIFO contents"
puts "Capture should start when bits 23:16 are 0x55 and bit 8 rises."
dump_fifo ecp5.tap

puts ""
puts "Repeating the capture with a 1/4 lead-in."
virscan ecp5.tap $jcapture_setleadin
vdrscan ecp5.tap 256 3

virscan ecp5.tap $jcapture_capture]

# Change LED colour
virscan ecp5.tap $jcapture_write
vdrscan ecp5.tap 256 2

puts "Waiting for the FIFO to fill"
wait_fifo ecp5.tap

# Change LED colour again
virscan ecp5.tap $jcapture_write
vdrscan ecp5.tap 256 4

puts "Collecting the FIFO contents"
puts "Capture should start when bits 23:16 are 0x55 and bit 8 rises,"
puts "after a lead-in of 1/4 of the FIFO's depth."

dump_fifo ecp5.tap

# Turn off the LEDs

puts "Turning off LED"
virscan ecp5.tap $jcapture_write]
vdrscan ecp5.tap 256 0

puts "Done."
exit

