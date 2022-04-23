library ieee;
use ieee.std_logic_1164.all;

package jcapture_pkg is

	-- User constants

	constant jcapture_width : integer := 256;
	constant jcapture_triggerwidth : integer := 24;
	constant jcapture_depth : integer := 5;

	-- Internal constants

	constant jcapture_irsize : integer := 4;
	constant jcapture_drsize : integer := 32;
	constant jcapture_ir_status : std_logic_vector(jcapture_irsize-1 downto 0) := "0000";
	constant jcapture_ir_abort : std_logic_vector(jcapture_irsize-1 downto 0) := "0001";
	constant jcapture_ir_read : std_logic_vector(jcapture_irsize-1 downto 0) := "0010";
	constant jcapture_ir_write : std_logic_vector(jcapture_irsize-1 downto 0) := "0011";
	constant jcapture_ir_setleadin : std_logic_vector(jcapture_irsize-1 downto 0) := "0100";
	constant jcapture_ir_setmask : std_logic_vector(jcapture_irsize-1 downto 0) := "0101";
	constant jcapture_ir_setinvert : std_logic_vector(jcapture_irsize-1 downto 0) := "0110";
	constant jcapture_ir_setedge : std_logic_vector(jcapture_irsize-1 downto 0) := "0111";
	constant jcapture_ir_capture : std_logic_vector(jcapture_irsize-1 downto 0) := "1000";
	constant jcapture_ir_bypass : std_logic_vector(jcapture_irsize-1 downto 0) := "1111";
end package;

