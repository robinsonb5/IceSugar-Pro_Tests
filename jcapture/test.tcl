#
# IceSugarPro demo JTAG script
#

init
scan_chain

# Some convenience functions

# Virtual IR scan - shifts a value into a register attached to ER1
set ::jcapture::commands {status null1 null2 write setleadin setmask setinvert setedge capture}
proc virscan {tap {cmd status}} {
	set v -1
	for {set i 0} {$i < [llength $::jcapture::commands]} {incr i} {
		if {[lindex $::jcapture::commands $i] == $cmd} {
			set v $i
			set i [llength $::jcapture::commands]
		}
	}
	if {$v>=0} {
		irscan $tap 0x32
		return [drscan $tap 4 $v]
	} else {
		error "Unknown command $cmd";
	}
}

# Virtual DR scan - shifts a value into a register attached to ER2
proc vdrscan {tap c v {sp -full}} {
	if {$sp == "-full" || $sp == "-start"} {
		irscan $tap 0x38
	}
	if {$sp == "-full" || $sp == "-end"} {
		return [drscan $tap $c $v]
	}
	return [drscan $tap $c $v -endstate DRPAUSE]	
}

# Command definitions for the jcapture module
set jcapture_status 0x0
set jcapture_null1 0x01
set jcapture_null1 0x02
set jcapture_write 0x3
set jcapture_setleadin 0x4
set jcapture_setmask 0x5
set jcapture_setinvert 0x6
set jcapture_setedge 0x7
set jcapture_capture 0x8

# Flag definitions
set jcapture_flag_busy 0x1
set jcapture_flag_full 0x2
set jcapture_flag_empty 0x4


# Wait for the busy flag to fall 
proc wait_fifo { tap } {
	global jcapture_status jcapture_flag_busy
	set status [virscan $tap status]
	while {[expr "0x$status & $jcapture_flag_busy"] != 0 } {
		set status [virscan $tap status]
	}
}

# Dump the FIFO contents to the shell window
proc dump_fifo { tap } {
	global jcapture_status jcapture_flag_empty
	set status [virscan $tap status]
	while {[expr "0x$status & $jcapture_flag_empty"] == 0 } {
		set a [vdrscan $tap 16 0 -start]
		set b [vdrscan $tap 16 0 -cont]
		set c [vdrscan $tap 32 0 -cont]
		set d [vdrscan $tap 32 0 -cont]
		set e [vdrscan $tap 32 0 -cont]
		set f [vdrscan $tap 32 0 -cont]
		set g [vdrscan $tap 32 0 -cont]
		set h [vdrscan $tap 32 0 -cont]
		set i [vdrscan $tap 32 0 -cont]
		puts "$i $h $g $f $e $d $c $b $a"
		set status [virscan ecp5.tap status]
	}
}

# Silently empty the FIFO.
proc flush_fifo { tap } {
	global jcapture_status jcapture_flag_empty
	set status [virscan $tap status]
	while {[expr "0x$status & $jcapture_flag_empty"] == 0 } {
		vdrscan $tap 256 0
		set status [virscan ecp5.tap status]
	}
}


# Make sure the FIFO is empty before we start.
flush_fifo ecp5.tap

puts "Turning on LED"
virscan ecp5.tap write
vdrscan ecp5.tap 256 1

puts "Setting capture parameters..."
virscan ecp5.tap setmask
vdrscan ecp5.tap 256 0xff0100

virscan ecp5.tap setedge
vdrscan ecp5.tap 256 0x000100

virscan ecp5.tap setinvert
vdrscan ecp5.tap 256 0x550100

virscan ecp5.tap capture

puts "Waiting for the FIFO"
wait_fifo ecp5.tap

puts "Collecting the FIFO contents"
puts "Capture should start when bits 23:16 are 0x55 and bit 8 rises."
dump_fifo ecp5.tap

puts ""
puts "Repeating the capture with a 1/4 lead-in."
virscan ecp5.tap setleadin
vdrscan ecp5.tap 256 3

virscan ecp5.tap capture

# Change LED colour
virscan ecp5.tap write
vdrscan ecp5.tap 256 2

puts "Waiting for the FIFO to fill"
wait_fifo ecp5.tap

# Change LED colour again
virscan ecp5.tap write
vdrscan ecp5.tap 256 4

puts "Collecting the FIFO contents"
puts "Capture should start when bits 23:16 are 0x55 and bit 8 rises,"
puts "after a lead-in of 1/4 of the FIFO's depth."

dump_fifo ecp5.tap

# Turn off the LEDs

puts "Turning off LED"
virscan ecp5.tap write
vdrscan ecp5.tap 256 0

puts "Done."
exit

