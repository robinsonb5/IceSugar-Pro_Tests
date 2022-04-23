library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.jcapture_pkg.all;

-- JTAG Logic capture module with triggers, for Lattice ECP5 / Yosys / GHDL / Trellis / NextPnR flow.

-- Triggers can be set for absolute values or for rising or falling edges (but not currently both edges)
-- To save logic, the triggers can be narrower than the capture bus; signals to be included in trigger
-- conditions should be in the lowest-order bits of the port.

-- Use JTAG commands to set the following registers:
-- Mask: '1' bits select which signals should be included in the trigger condition.
-- Invert: The trigger will match '0' bits unless the corresponding bit in this register is set.
-- Edge: For bits set in both Edge and Mask, the trigger will match on falling edges, unless the corresponding invert bit is set.

entity jcapture is
port(
	clk : in std_logic;
	reset_n : in std_logic;
	-- Design interface
	d : in std_logic_vector(jcapture_width-1 downto 0);
	q : out std_logic_vector(jcapture_width-1 downto 0); -- Optional output data
	update : out std_logic
	-- JTAG interface - might as well be internal.
);	
end entity;


architecture rtl of jcapture is

	-- JTAG signals
	signal vir_update : std_logic;
	signal vir_from_jtag : std_logic_vector(jcapture_irsize-1 downto 0);
	signal vir_to_jtag : std_logic_vector(jcapture_irsize-1 downto 0);
	signal vdr_capture : std_logic; -- Synced to sysclk, so will arrive a couple of cycles after the data has been captured;
	signal vdr_update : std_logic; -- Synced to sysclk, so will arrive a couple of cycles after the data has been updated;
	signal vdr_from_jtag : std_logic_vector(jcapture_width-1 downto 0);

	-- FIFO signals
	signal leadin : std_logic_vector(1 downto 0) := "00";
	signal to_fifo : std_logic_vector(jcapture_width-1 downto 0);
	signal fifo_wr : std_logic;
	signal fifo_full : std_logic;
	signal fifo_empty : std_logic;

	signal trigger : std_logic;
	
	type capstate_t is (STATE_IDLE,STATE_ID,STATE_CAPTURE,STATE_FILL,STATE_READ,STATE_WRITE,STATE_SETLEADIN,STATE_SETMASK,STATE_SETINVERT,STATE_SETEDGE);
	signal capstate : capstate_t;
	signal busy : std_logic;
begin

-- Capture triggering logic

-- From the current and previous incoming values, a mask, invert and edge signal
-- we digest a zero value if the trigger condition is satisfied.
-- Mask is a bitmap of bits to be included in the trigger condition
-- Invert reverses the sense of the comparison: value triggers match '0' by default
-- and '1' if the corresponding bit in invert is set.  Edge triggers match a falling
-- edge by default and a rising edge if the invert bit is set.

-- if V is a bit from the incoming value, and P is its previous value, then
-- V' is (V^I) and P' is (P^I), where I is the corresponding bit from the invert register.
-- M comes from the mask register, and E comes from the edge register.
-- The active-low trigger value for each bit = ((not P') and M and E) or (V' and M)

triggerlogic : block
	signal prev : std_logic_vector(jcapture_triggerwidth-1 downto 0);
	signal edge : std_logic_vector(jcapture_triggerwidth-1 downto 0);
	signal invert : std_logic_vector(jcapture_triggerwidth-1 downto 0);
	signal mask : std_logic_vector(jcapture_triggerwidth-1 downto 0);
	signal triggers : std_logic_vector(jcapture_triggerwidth-1 downto 0);
	signal inverted : std_logic_vector(jcapture_triggerwidth-1 downto 0);
begin

	-- Record the mask, invert and edge signals
	-- and set the trigger signal when conditions are met.
	process(clk,reset_n) begin
		if reset_n='0' then
			mask <= (others=>'0');
			invert <= (others => '0');
			edge <= (others => '0');
		elsif rising_edge(clk) then
			case capstate is
				when STATE_SETMASK =>
					if vdr_update='1' then
						mask <= vdr_from_jtag(jcapture_triggerwidth-1 downto 0);
					end if;
				when STATE_SETINVERT =>
					if vdr_update='1' then
						invert <= vdr_from_jtag(jcapture_triggerwidth-1 downto 0);
					end if;
				when STATE_SETEDGE =>
					if vdr_update='1' then
						edge <= vdr_from_jtag(jcapture_triggerwidth-1 downto 0);
					end if;
				when others =>
					null;
			end case;
		end if;
	end process;

	inverted <= d(jcapture_triggerwidth-1 downto 0) xor invert;

	process(clk) begin
		if reset_n='0' then
			prev <= (others => '0');
		elsif rising_edge(clk) then
			prev <= inverted;
			triggers <= ((not prev) and mask and edge) or (inverted and mask);
		end if;
	end process;

	trigger <= '1' when triggers=std_logic_vector(to_unsigned(0,jcapture_triggerwidth)) else '0';

end block;


	process(clk) begin
		if rising_edge(clk) then
			to_fifo<=d;
			fifo_wr<='0';
			update<='0';
			case capstate is
				when STATE_IDLE =>
					if vir_update='1' then
						case vir_from_jtag is
							when jcapture_ir_capture =>
								capstate<=STATE_CAPTURE;
							when jcapture_ir_setmask =>
								capstate<=STATE_SETMASK;
							when jcapture_ir_setinvert =>
								capstate<=STATE_SETINVERT;
							when jcapture_ir_setedge =>
								capstate<=STATE_SETEDGE;
							when jcapture_ir_setleadin =>
								capstate<=STATE_SETLEADIN;
							when jcapture_ir_write =>
								capstate<=STATE_WRITE;
							when jcapture_ir_read =>
								capstate<=STATE_READ;
							when others =>
								capstate<=STATE_IDLE;
						end case;
					end if;
				when STATE_CAPTURE =>
					if vir_update='1' and vir_from_jtag=jcapture_ir_abort then
						capstate<=STATE_IDLE;
					end if;
					if trigger='1' then
						capstate<=STATE_FILL;
						leadin<="00";
					end if;
				when STATE_FILL =>
					if fifo_full='1' then
						capstate<=STATE_IDLE;
					else
						fifo_wr<='1';
					end if;
				when STATE_READ =>
					if fifo_empty='1' then
						capstate<=STATE_IDLE;
					end if;
				when STATE_WRITE =>
					if vdr_update='1' then
						q <= vdr_from_jtag;
						update <= '1';
						capstate<=STATE_IDLE;
					end if;
				when STATE_SETMASK =>
					if vdr_update='1' then
						capstate<=STATE_IDLE;
					end if;
				when STATE_SETINVERT =>
					if vdr_update='1' then
						capstate<=STATE_IDLE;
					end if;
				when STATE_SETEDGE =>
					if vdr_update='1' then
						capstate<=STATE_IDLE;
					end if;
				when STATE_SETLEADIN =>
					if vdr_update='1' then
						capstate<=STATE_IDLE;
						leadin<=vdr_from_jtag(1 downto 0);
					end if;
				when others =>
					capstate<=STATE_IDLE;
			end case;
		end if;
	end process;

	busy <= '0' when capstate=STATE_IDLE else '1';
	vir_to_jtag<=(3=>'1',2=>fifo_empty,1=>fifo_full,0=>busy,others=>'0');
	vjtag : entity work.vjtag_ecp5
	generic map (
		irwidth => jcapture_irsize,
		drwidth => jcapture_width,
		depth => jcapture_depth
	)
	port map (
		clk => clk,
		reset_n => reset_n,
		-- FIFO signals
		fifo_in => to_fifo,
		fifo_wr => fifo_wr,
		fifo_empty => fifo_empty,
		fifo_full => fifo_full,
		leadin => leadin,
		
		-- Virtual JTAG signals
		vir_in => vir_to_jtag,
		vir_capture => open,
		vir_out => vir_from_jtag,
		vir_update => vir_update,
		vdr_out => vdr_from_jtag,
		vdr_capture => vdr_capture,
		vdr_update => vdr_update
	);

end architecture;

