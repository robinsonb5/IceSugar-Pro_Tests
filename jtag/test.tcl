#
# IceSugarPro demo JTAG script
#

init
scan_chain

# select the ER1 register (256 bits wide in this design)
irscan ecp5.tap 0x32

puts "Test the FIFO - all numbers should rise consecutively."

# Shift all 256 bits repeatedly - the result should increment by 1 each time
for { set j 0 } { $j < 128 } { incr j } {
	set this [drscan ecp5.tap 256 $j ]
	puts 0x$this
}

puts "Shift out the register in eight chunks of 32 bits."

# Shift out the entire register in eight chunks of 32 bits
for { set j 0 } { $j < 8 } { incr j } {
	set this [drscan ecp5.tap 32 0x55aa55aa -endstate DRPAUSE]
	puts 0x$this
}

# Return to the RUN/IDLE state in preparation for the next shift
pathmove DRPAUSE DREXIT2 DRUPDATE RUN/IDLE

set this [drscan ecp5.tap 256 0 ]
puts 0x$this

# The LEDs are tied to the lower three bits of the register.  Blink the LEDS by
# shifting in the values 0 to 8, followed by two further partial shifts.
# Provided we shift 256 bits in total, the first value shifted will end up in
# the lowest three bits and trigger the LEDs.
puts "Cycle the LEDs through the primary and secondary colours, white and off."
for { set j 0 } { $j < 9 } { incr j } {
	after 200
	drscan ecp5.tap 3 $j -endstate DRPAUSE
	drscan ecp5.tap 200 0 -endstate DRPAUSE
	drscan ecp5.tap 53 0
}

# Finally select the ER2 register (3 bits wide in this design) and send some values.
irscan ecp5.tap 0x38
for { set j 0 } { $j < 9 } { incr j } {
	drscan ecp5.tap 3 $j
}

puts "Done."
exit

