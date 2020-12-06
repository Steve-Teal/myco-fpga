---------------------------------------------------------------------------------------------------
--
-- timer.vhd
--
-- Timer circuit for the myco-fpga project
--
-- This circuit stops the CPU for a programable number of milli-seconds.
-- Set the generic 'divisor' to your system clock frequency divided by 1000 (eg 12MHz = 12000)
--
---------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity timer is
	generic (
		divisor : integer range 1 to 150000 := 12000);
	port (
		clock     : in std_logic;
		reset     : in std_logic;
		data      : in std_logic_vector(15 downto 0);
		we        : in std_logic;
		cpu_ce    : out std_logic);
end entity;

architecture rtl of timer is

	signal clock_divider : integer range 0 to divisor-1;
	signal counter       : unsigned(15 downto 0);
	signal dec_counter   : std_logic;
	signal timer_run     : std_logic;

begin

	cpu_ce <= not timer_run;

	process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' then
				timer_run <= '0';
				counter <= X"0000";
			elsif we = '1' then
				timer_run <= '1';
				counter <= unsigned(data);
			elsif timer_run = '1' and dec_counter = '1' then
				if counter = X"0000" then
					timer_run <= '0';
				else
					counter <= counter - 1;
				end if;
			end if;
		end if;
	end process;

	--
	-- Clock Divider: while timer is runing dec_counter is high for one clock cycle every mS
	--

	process(clock)
	begin
		if rising_edge(clock) then
			if timer_run = '1' then
				if clock_divider >= divisor-1 then
					clock_divider <= 0;
					dec_counter <= '1';
				else
					clock_divider <= clock_divider + 1;
					dec_counter <= '0';
				end if;
			else
				clock_divider <= 0;
				dec_counter <= '0';
			end if;
		end if;
	end process;

end rtl;

-- End of file

