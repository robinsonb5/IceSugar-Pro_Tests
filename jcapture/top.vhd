-- JTAG Toplevel for IceSugarPro

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
port (
	clk_i : in std_logic;
	txd : out std_logic;
	led_red : out std_logic;
	led_green : out std_logic;
	led_blue : out std_logic
);
end entity;

architecture rtl of top is
	constant er1_width : integer := 256;
	signal freerunning : unsigned(31 downto 0) := (others => '0');
	signal fval : unsigned(er1_width-33 downto 0) := X"00112233_44556677_8899aabb_ccddeeff_00112233_44556677_12345678";
	signal to_jtag : std_logic_vector(er1_width-1 downto 0);
	signal from_jtag : std_logic_vector(er1_width-1 downto 0);
	signal update_dr : std_logic;
	signal reset_ctr : unsigned(5 downto 0) := (others => '0');
	signal reset_n : std_logic;
	
	signal sysclk : std_logic;
	signal ramclk : std_logic;
	signal slowclk : std_logic;
	signal noclk : std_logic;

	component ecp5pll is
	generic	(
		in_hz : integer := 25000000;
		out0_hz : integer := 100000000;
		out1_hz : integer := 100000000;
		out1_deg : integer := 270;
		out2_hz : integer := 50000000
	);
	port (
		clk_i : in std_logic;
		clk_o : out std_logic_vector(3 downto 0);
		reset : in std_logic;
		locked : out std_logic
	);
	end component;

begin

	pll : component ecp5pll
	port map (
		clk_i => clk_i,
		clk_o(0) => sysclk,
		clk_o(1) => ramclk,
		clk_o(2) => slowclk,
		clk_o(3) => noclk,
		reset => '0'
	);

	reset_n <= reset_ctr(reset_ctr'high);
	process(sysclk) begin
		if rising_edge(sysclk) then
		 	if reset_n='0' then
		 		reset_ctr<=reset_ctr+1;
		 	end if;
		end if;
	end process;

	process(clk_i) begin
		if rising_edge(sysclk) then
			freerunning<=freerunning+1;
			to_jtag<=std_logic_vector(fval)&std_logic_vector(freerunning);
		end if;
		
		if rising_edge(sysclk) then
			if update_dr='1' then
				led_red<=from_jtag(0);
				led_green<=from_jtag(1);
				led_blue<=from_jtag(2);
			end if;
		end if;
	end process;

	cap : entity work.jcapture
	port map(
		clk => sysclk,
		reset_n => reset_n,
		-- Design interface
		d => to_jtag,
		q => from_jtag,
		update => update_dr
	);

end architecture;


