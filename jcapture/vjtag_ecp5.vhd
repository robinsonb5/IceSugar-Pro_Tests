-- Virtual JTAG wrapper for ECP5 JTAGG primitive.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vjtag_ecp5 is
generic (
	irwidth : integer := 3;
	drwidth : integer := 32;
	depth : integer := 7
);
port (
	clk : in std_logic;
	reset_n : in std_logic;
	-- FIFO signals
	fifo_in : in std_logic_vector(drwidth-1 downto 0);
	fifo_wr : in std_logic;
	fifo_empty : out std_logic; -- Caution - not synced to clk
	fifo_full : out std_logic;
	leadin : in std_logic_vector(1 downto 0);
	
	-- Virtual JTAG signals
	vir_in : in std_logic_vector(irwidth-1 downto 0);
	vir_capture : out std_logic;
	vir_out : out std_logic_vector(irwidth-1 downto 0);
	vir_update : out std_logic;
	vdr_out : out std_logic_vector(drwidth-1 downto 0);
	vdr_capture : out std_logic;
	vdr_update : out std_logic
);
end entity;

architecture rtl of vjtag_ecp5 is
	-- JTAG signals
	signal jtck,jtdi,jshift,jupdate,jrstn,jce1,jce2,jrti1,jrti2,jtdo1,jtdo2 : std_logic;
	signal jtdi_mux : std_logic;
	signal capture : std_logic_vector(1 downto 0);
	signal update : std_logic_vector(1 downto 0);
	-- FIFO signals
	signal frd_en,fwr_en,fempty,ffull : std_logic;
	signal fwr : std_logic_vector(drwidth-1 downto 0);
	signal frd : std_logic_vector(drwidth-1 downto 0);
	
	component JTAGG
	port (
		JTCK : out std_logic;
		JTDI : out std_logic;
		JSHIFT : out std_logic;
		JUPDATE : out std_logic;
		JRSTN : out std_logic;
		JCE1 : out std_logic;
		JCE2 : out std_logic;
		JRTI1 : out std_logic;
		JRTI2 : out std_logic;
		JTDO1 : in std_logic;
		JTDO2 : in std_logic
	);
	end component;

begin

	fifo_empty <= fempty;
	fifo_full <= ffull;

	fifo : entity work.debug_fifo
	generic map (
		width => drwidth,
		depth => depth
	)
	port map(
		reset_n => '1',
		rd_clk => jtck,
		rd_en => frd_en,
		dout => frd,
		empty => fempty,
		
		wr_clk => clk,
		wr_en => fifo_wr,
		din => fifo_in,
		full => ffull,
		lead => leadin
	);

	jtg : component JTAGG
	port map(
		JTCK => jtck,
		JTDI => jtdi,
		JSHIFT => jshift,
		JUPDATE => jupdate,
		JRSTN => jrstn,
		JCE1 => jce1,
		JCE2 => jce2,
		JRTI1 => jrti1,
		JRTI2 => jrti2,
		JTDO1 => jtdo1,
		JTDO2 => jtdo2
	);

	-- separate the Create capture and update signals for the two channels

	jtagctrl : block
		signal jtdi_latched : std_logic;
		signal jshift_d : std_logic;
		signal selectedreg : std_logic;
	begin
		jtdi_mux <= jtdi when jshift_d='1' else jtdi_latched;

		process(jtck) begin
			if rising_edge(jtck) then
				jshift_d <= jshift;
				if jshift_d='1' then
					jtdi_latched <= jtdi;
				end if;
			end if;
		end process;

		capture(0) <= jce1 and not jshift;
		capture(1) <= jce2 and not jshift;

		-- Record which register is being accessed, and filter jupdate accordingly.
		process(jtck) begin
			if rising_edge(jtck) then
				if (jce1 and jshift) = '1' then
					selectedreg<='0';
				end if;
				if (jce2 and jshift) = '1' then
					selectedreg<='1';
				end if;
			end if;
		end process;
		update(0) <= jupdate and not selectedreg;
		update(1) <= jupdate and selectedreg;

	end block;

		-- Create a pair of registers to be accessed over the JTAG chain

	virtual_ir : block
		-- First register, provides our virtual IR register.
		signal shift_next : std_logic_vector(irwidth-1 downto 0);
		signal shift : std_logic_vector(irwidth-1 downto 0);

		signal q : std_logic_vector(irwidth-1 downto 0);
	begin

		jtdo1 <= shift(0);

		shift_next <= jtdi_mux & shift(irwidth-1 downto 1);
		
		process(jtck) begin
			if rising_edge(jtck) then
				if capture(0)='1' then
					shift<=vir_in;
				end if;

				if jshift='1' and jce1='1' then
					shift<=shift_next;
				end if;
			end if;
		end process;
		
		process(jtck) begin
			if rising_edge(jtck) then
				if update(0)='1' then
					q<=shift_next;
				end if;
			end if;
		end process;

		-- Synchronise the update and capture signals to clk
		cdc_uir : entity work.cdc_pulse port map ( clk_d => jtck, d=>update(0), clk_q => clk, q=>vir_update);
		cdc_cir : entity work.cdc_pulse port map ( clk_d => jtck, d=>capture(0), clk_q => clk, q=>vir_capture);

		vir_out <= q;
	end block;


	virtual_dr : block
		-- Second register, provides our virtual DR register
		signal shift_next : std_logic_vector(drwidth-1 downto 0);
		signal shift : std_logic_vector(drwidth-1 downto 0);
		signal q : std_logic_vector(drwidth-1 downto 0);
	begin

		jtdo2 <= shift(0);

		shift_next <= jtdi_mux & shift(drwidth-1 downto 1);

		process(jtck) begin
			if rising_edge(jtck) then
				frd_en<='0';
				if capture(1)='1' then
					shift<=frd;
					if fempty='0' then
						frd_en<='1';
					end if;
				end if;

				if jshift='1' and jce2='1' then
					shift<=shift_next;
				end if;
			end if;
		end process;

		process(jtck) begin
			if rising_edge(jtck) then
				if update(1)='1' then
					q<=shift_next;
				end if;
			end if;
		end	process;

		-- Synchronise the update and capture signals to clk
		cdc_udr : entity work.cdc_pulse port map ( clk_d => jtck, d=>update(1), clk_q => clk, q=>vdr_update);
		cdc_cdr : entity work.cdc_pulse port map ( clk_d => jtck, d=>capture(1), clk_q => clk, q=>vdr_capture);

		vdr_out<=q;

	end block;


end architecture;


