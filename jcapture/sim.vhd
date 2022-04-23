-- JTAG Toplevel for IceSugarPro

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sim is
end entity;

architecture rtl of sim is
	constant clk_period : time := 10 ns;
	signal clk_i : std_logic;
	constant clk2_period : time := 123 ns;
	signal clk2_i : std_logic;
begin

	clk_process: process
	begin
		clk_i <= '0';
		wait for clk_period/2;
		clk_i <= '1';
		wait for clk_period/2;
	end process;

	clk2_process: process
	begin
		clk2_i <= '0';
		wait for clk2_period/2;
		clk2_i <= '1';
		wait for clk2_period/2;
	end process;

	srcgen : block
		signal freerunning : unsigned(31 downto 0) := (others => '0');
		signal inverted : std_logic_vector(31 downto 0) := (others => '0');
		signal prev : std_logic_vector(31 downto 0);
		signal trigger : std_logic_vector(31 downto 0);
		signal mask : std_logic_vector(31 downto 0) := X"000000fe";
		signal edge : std_logic_vector(31 downto 0) := X"00000000";
		signal invert : std_logic_vector(31 downto 0) := X"000000c0";
		signal go : std_logic;
		signal cdc : std_logic;
		signal empty : std_logic;
		signal full : std_logic;
		signal lead : std_logic_vector(1 downto 0);
		signal wren : std_logic;
		signal rden : std_logic;
	begin
		process(clk_i) begin
			if rising_edge(clk_i) then
				freerunning<=freerunning+1;
			end if;
		end process;

		inverted <= std_logic_vector(freerunning) xor invert;

		process(clk_i) begin
			if rising_edge(clk_i) then
				prev <= inverted xor edge;
				trigger <= mask and not (prev and inverted);
			end if;
		end process;

		go <= '1' when trigger=std_logic_vector(to_unsigned(0,32)) else '0';

		cdcpulse : entity work.cdc_pulse
		port map(
			clk_d=>clk_i,d=>freerunning(4),clk_q=>clk2_i,q=>cdc
		);

		process(clk_i) begin
			if rising_edge(clk_i) then
				if freerunning(11 downto 0) = X"001" then
					lead<="10";
				end if;
				if freerunning(11 downto 0) = X"027" then
					lead <= "00";
				end if;
			end if;
		end process;

		wren <= not full;
		rden <= '0';--not empty;

		fifo : entity work.debug_fifo
		generic map (
			width => 32
		)
		port map (
			rd_clk => clk2_i,
			rd_en => rden,
			dout => open,
			empty => empty,

			wr_clk => clk_i,
			wr_en => wren,
			din => std_logic_vector(freerunning),
			full => full,
			
			lead => lead
	);

	end block;

end architecture;

