library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- FIFO queue for debug channel.
-- Asynchronous, fall-through semantics.
-- Enforces two cycles' downtime between reads and writes,
-- using the full and empty signals for flow control.
-- Wastes up to one quarter of the storage just for simplicity
-- of generating the full signals.

ENTITY debug_fifo IS
	generic (
		width : integer :=256;
		depth : integer :=3
	);
	PORT (
		reset_n : in std_logic := '1';
		-- Read-side signals
		rd_clk : IN STD_LOGIC;
		rd_en : IN STD_LOGIC;
		dout : OUT STD_LOGIC_VECTOR(width-1 DOWNTO 0);
		empty : OUT STD_LOGIC;
		-- Write-side signals
		wr_clk : IN STD_LOGIC;
		wr_en : IN STD_LOGIC;
		din : IN STD_LOGIC_VECTOR(width-1 DOWNTO 0);
		full : OUT STD_LOGIC
	);
END entity;

architecture rtl of debug_fifo is

function togray(d : unsigned) return unsigned is begin
	return d xor ('0'&d(d'high downto 1));
end function;

subtype element_t is std_logic_vector(width-1 downto 0);
type storage_t is array ((2**depth)-1 downto 0) of element_t;
signal storage : storage_t;

signal inptr_gray : unsigned(depth-1 downto 0) := (others=>'0');
signal outptr_gray : unsigned(depth-1 downto 0) := (others => '0');
signal outptr_gray_prev : unsigned(1 downto 0) := (others => '1');

begin

-- Read side logic

readlogic : block is

signal inptr_gray_sync : unsigned(depth-1 downto 0);
signal inptr_gray_sync2 : unsigned(depth-1 downto 0);
signal outptr : unsigned(depth-1 downto 0) := (others=>'0');
signal outptr_next : unsigned(depth-1 downto 0);
signal outptr_next_gray : unsigned(depth-1 downto 0);
signal empty_c : std_logic;
signal rd_trigger : std_logic;
signal rd_delay : std_logic_vector(1 downto 0);
signal reset_rd : std_logic_vector(1 downto 0);

begin

	process(rd_clk) begin
		if rising_edge(rd_clk) then
			reset_rd <= reset_rd(0) & reset_n;
			rd_delay<=rd_delay(rd_delay'high-1 downto 0)&rd_trigger;
			inptr_gray_sync2<=inptr_gray;
			inptr_gray_sync<=inptr_gray_sync2;			
		end if;
	end process;

	rd_trigger <= '1' when rd_en='1' and empty_c='0' and rd_delay="00" else '0';
	empty_c <= '1' when inptr_gray_sync = outptr_gray else'0';
	empty <= empty_c;

	outptr_next<=outptr+1;
	outptr_next_gray<=togray(outptr_next);

	process(rd_clk,reset_rd(1)) begin
		if reset_rd(1)='0' then
			outptr<=(others=>'0');
			outptr_gray<=(others=>'0');
			outptr_gray_prev<=(others=>'1');
		elsif rising_edge(rd_clk) then
			dout <= storage(to_integer(outptr_gray));
			if rd_trigger='1' then
				outptr<=outptr_next;
				outptr_gray <= outptr_next_gray;

				-- Grey counter's two MSBs will follow the pattern: 00 01 11 10 00 ... which reverses to 00 10 11 01 00
				-- The lower bit of each term is the higher bit of the previous term
				-- The higher bit of each term is the complement of the previous term's lower bit
				-- The grey counter MSBs of (outptr-1) is thus easy to compute.  We consider the FIFO full when
				-- the two MSBs of inptr == the two MSBs of (outptr-1)

				outptr_gray_prev <= not outptr_gray(outptr_gray'high-1) & outptr_gray(outptr_gray'high);
				
			end if;
		end if;
	end process;

end block;


-- Write side logic;

writelogic : block is

signal outptr_gray_sync : unsigned(1 downto 0);
signal outptr_gray_sync2 : unsigned(1 downto 0);
signal inptr : unsigned(depth-1 downto 0) := (others=>'0');
signal inptr_next : unsigned(depth-1 downto 0);
signal wr_delay : std_logic_vector(1 downto 0);
signal reset_wr : std_logic_vector(1 downto 0);
begin

	process(wr_clk) begin
		if rising_edge(wr_clk) then
			reset_wr <= reset_wr(0) & reset_n;
			wr_delay<=wr_delay(wr_delay'high-1 downto 0)&wr_en;
			outptr_gray_sync2<=outptr_gray_prev;
			outptr_gray_sync<=outptr_gray_sync2;
		end if;
	end process;

	-- We consider the FIFO full when the upper bits of outptr_gray_prev == the upper bits of inptr_gray,
	-- which we take to mean the write pointer is close to catching up the read pointer.)
	full <= '1' when inptr_gray(depth-1 downto depth-2) = outptr_gray_sync else '0';

	inptr_next<=inptr+1;

	process(wr_clk,reset_wr(1)) begin
		if reset_wr(1)='0' then
			inptr<=(others=>'0');
			inptr_gray<=(others=>'0');
		elsif rising_edge(wr_clk) then
			if wr_en='1' then
				storage(to_integer(inptr_gray))<=din;
				inptr<=inptr_next;
				inptr_gray <= togray(inptr_next);
			end if;
		end if;
	end process;

end block;

end architecture;

