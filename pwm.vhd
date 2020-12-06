---------------------------------------------------------------------------------------------------
--
-- pwm.vhd
--
-- 4-bit PWM circuit for the myco-fpga project
-- PWM frequency is set at build time by the divisor generic,
--     divisor = clock_frequency / (pwm_frequency * 15) 
-- Example: = 12MHz / (16Khz * 15) = 50
--
-- A 4-bit value (data[3:0]) is loaded when we = '1'. Output is fully off (0) to fully on (15)
--
---------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm is
	generic (
		divisor : integer range 1 to 512 := 50);
	port (
		clock     : in std_logic;
		reset     : in std_logic;
		data      : in std_logic_vector(15 downto 0);
		we        : in std_logic;
		pwm_out   : out std_logic);
end entity;

architecture rtl of pwm is

	signal clock_divider : integer range 0 to divisor-1;
	signal en_pwm_count  : std_logic;
	signal pwm_counter   : unsigned(3 downto 0);
	signal pwm_reg       : unsigned(3 downto 0);

begin

	--
	-- Clock divider 
	--
	process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' then
				clock_divider <= 0;
				en_pwm_count <= '0';
			elsif clock_divider >= divisor-1 then
				clock_divider <= 0;
				en_pwm_count <= '1';
			else
				clock_divider <= clock_divider + 1;
				en_pwm_count <= '0';
			end if;
		end if;
	end process;
	
	--
	-- PWM Counter
	--
	process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' then
				pwm_counter <= "0000";
			elsif en_pwm_count = '1' then
				if pwm_counter(3 downto 1) = "111" then
					pwm_counter <= "0000";
				else
					pwm_counter <= pwm_counter + 1;
				end if;
			end if;
		end if;
	end process;
	
	--
	-- PWM Output
	--
	process(clock)
	begin
		if rising_edge(clock) then
			if pwm_reg > pwm_counter then
				pwm_out <= '1';
			else
				pwm_out <= '0';
			end if;
		end if;
	end process;
	
	--
	-- PWM Register
	--
	process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' then
				pwm_reg <= "0000";
			elsif we = '1' then
				pwm_reg <= unsigned(data(3 downto 0));
			end if;
		end if;
	end process;

end rtl;

-- End of file