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
	-- JTAG signals
	signal jtck,jtdi,jshift,jupdate,jrstn,jce1,jce2,jrti1,jrti2,jtdo1,jtdo2 : std_logic;
	signal jtdi_mux : std_logic;
	signal capture : std_logic_vector(1 downto 0);
	signal update : std_logic_vector(1 downto 0);
	-- FIFO signals
	signal frd_en,fwr_en,fempty,ffull : std_logic;
	signal fwr : std_logic_vector(er1_width-1 downto 0);
	signal frd : std_logic_vector(er1_width-1 downto 0);
	
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

	fifo : entity work.debug_fifo
	port map(
		reset_n => '1',
		rd_clk => jtck,
		rd_en => frd_en,
		dout => frd,
		empty => fempty,
		
		wr_clk => clk_i,
		wr_en => fwr_en,
		din => fwr,
		full => ffull
	);

	srcgen : block
		signal freerunning : unsigned(31 downto 0) := (others => '0');
		signal fval : unsigned(er1_width-33 downto 0) := X"00112233_44556677_8899aabb_ccddeeff_00112233_44556677_12345678";
	begin
		process(clk_i) begin
			if rising_edge(clk_i) then
				freerunning<=freerunning+1;
				if ffull='0' then
					fwr<=std_logic_vector(freerunning)&std_logic_vector(fval);
					fwr_en<='1';			
					fval<=fval+1;
				else
					fwr_en<='0';
				end if;
			end if;
		end process;
	end block;

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

		capture(1) <= jce2 and not jshift;
		capture(0) <= jce1 and not jshift;

		-- Record which register is being accessed, and filter jupdate accordingly.
		process(jtck) begin
			if rising_edge(jtck) then
				if (jce2 and jshift) = '1' then
					selectedreg<='1';
				end if;
				if (jce1 and jshift) = '1' then
					selectedreg<='0';
				end if;
			end if;
		end process;
		update(1) <= jupdate and selectedreg;
		update(0) <= jupdate and not selectedreg;

	end block;

		-- Create a pair of registers to be accessed over the JTAG chain

	reg1 : block
		-- First register, 256 bits long...
		signal shift_next : std_logic_vector(er1_width-1 downto 0);
		signal shift : std_logic_vector(er1_width-1 downto 0);
		signal d : std_logic_vector(er1_width-1 downto 0);
		signal q : std_logic_vector(er1_width-1 downto 0);
	begin

		jtdo1 <= shift(0);

		shift_next <= jtdi_mux & shift(er1_width-1 downto 1);

		process(jtck) begin
			if falling_edge(jtck) then
				frd_en<='0';
				if capture(0)='1' then
					shift<=frd;
					if fempty='0' then
						frd_en<='1';
					end if;
				end if;

				if jshift='1' and jce1='1' then
					shift<=shift_next;
				end if;
			end if;
		end process;

		process(jtck) begin
			if falling_edge(jtck) then
				if update(0)='1' then
					q<=shift_next;
				end if;
			end if;
		end	process;

		-- Make the results visible		
		led_red <= q(0);
		led_green <= q(1);
		led_blue <= q(2);

	end block;


		-- Second register, only 3 bits long...
	reg2 : block
		constant er2_width : integer := 3;
		signal shift2_next : std_logic_vector(er2_width-1 downto 0);
		signal shift2 : std_logic_vector(er2_width-1 downto 0);

		signal d2 : std_logic_vector(er2_width-1 downto 0) := (others=>'1');
		signal q2 : std_logic_vector(er2_width-1 downto 0);
	begin

		jtdo2 <= shift2(0);

		shift2_next <= jtdi_mux & shift2(er2_width-1 downto 1);
		
		process(jtck) begin
			if falling_edge(jtck) then
				if capture(1)='1' then
					shift2<=d2;
				end if;

				if jshift='1' and jce2='1' then
					shift2<=shift2_next;
				end if;
			end if;
		end process;
		
		process(jtck) begin
			if falling_edge(jtck) then
				if update(1)='1' then
					q2<=shift2_next;
				end if;
			end if;
		end process;

	end block;

end architecture;


