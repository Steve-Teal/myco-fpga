---------------------------------------------------------------------------------------------------
--
-- myco.vhd
--
-- Top level circuit for the myco-fpga project: 'A 4-bit computer system for FPGAs'
--
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity myco is
    port (
        clock    : in std_logic;
        n_reset  : in std_logic;
        dout     : out std_logic_vector(3 downto 0);
		din      : in std_logic_vector(3 downto 0);
        sw1      : in std_logic;
        sw2      : in std_logic;
        pwm_out  : out std_logic);
end entity;

architecture rtl of myco is

	component pumpkin is	
		generic(
			stack_depth  : integer := 6;
			program_size : integer := 12);
		port (
			clock 			: in std_logic;
			clock_enable	: in std_logic;
			reset 			: in std_logic;
			program_data_in	: in std_logic_vector(15 downto 0);
			data_out        : out std_logic_vector(15 downto 0);
			program_address : out std_logic_vector(program_size-1 downto 0);
			program_wr      : out std_logic;
			io_data_in      : in std_logic_vector(15 downto 0);
			io_address      : out std_logic_vector(15 downto 0);
			io_rd           : out std_logic;
			io_wr           : out std_logic);  
	end component;
	
	component myco_mem is
		port (
			clock        : in std_logic;
			clock_enable : in std_logic;
			address      : in std_logic_vector(9 downto 0);
			data_out     : out std_logic_vector(15 downto 0);
			data_in      : in std_logic_vector(15 downto 0);
			write_enable : in std_logic);
	end component;
	
	component timer is
		generic (
			divisor : integer range 1 to 150000 := 12000);
		port (
			clock     : in std_logic;
			reset     : in std_logic;
			data      : in std_logic_vector(15 downto 0);
			we        : in std_logic;
			cpu_ce    : out std_logic);
	end component;
	
	component pwm is
		generic (
			divisor : integer range 1 to 512 := 47);
		port (
			clock     : in std_logic;
			reset     : in std_logic;
			data      : in std_logic_vector(15 downto 0);
			we        : in std_logic;
			pwm_out   : out std_logic);
	end component;

    signal reset       : std_logic;
    signal cpu_data    : std_logic_vector(15 downto 0);
    signal ram_data    : std_logic_vector(15 downto 0);
    signal io_data     : std_logic_vector(15 downto 0);
    signal ram_address : std_logic_vector(9 downto 0);
    signal io_address  : std_logic_vector(15 downto 0);
    signal ram_wr      : std_logic;
    signal io_rd       : std_logic;
    signal io_wr       : std_logic;
	signal reset_done  : std_logic;
	signal reset_counter : integer range 0 to 15;
	signal dout_register : std_logic_vector(3 downto 0);
	signal clock_enable  : std_logic;
	signal timer_we      : std_logic;
	signal pwm_we        : std_logic;
	signal din_comp 	  : std_logic_vector(3 downto 0);
	
	constant io_switch  : std_logic_vector(3 downto 0) := X"0";
	constant io_dout    : std_logic_vector(3 downto 0) := X"1";
	constant io_din     : std_logic_vector(3 downto 0) := X"2"; 
	constant io_timer   : std_logic_vector(3 downto 0) := X"3";
	constant io_pwm     : std_logic_vector(3 downto 0) := X"4";

begin

    reset <= not reset_done;
	dout <= dout_register;
	din_comp <= not din;

--
-- CPU instantiation 
--
u1: pumpkin generic map (
            stack_depth => 4,
            program_size => 10)
        port map(
            clock => clock,
            clock_enable => clock_enable,
            reset => reset,
            program_data_in => ram_data,
            data_out => cpu_data,
            program_address => ram_address,
            program_wr => ram_wr,
            io_data_in => io_data,
            io_address => io_address,
            io_rd => io_rd,
            io_wr => io_wr);
			
u2: myco_mem port map (
		clock => clock,
		clock_enable => clock_enable,
		address => ram_address,
		data_out => ram_data,
		data_in  => cpu_data,
		write_enable => ram_wr);
		
u3: timer generic map (
		divisor => 12000)
	port map (
		clock => clock,
		reset => reset,
		data => cpu_data,
		we => timer_we,
		cpu_ce => clock_enable);
		
u4: pwm generic map (
		divisor => 50)
	port map (
		clock => clock,
		reset => reset,
		data => cpu_data,
		we => pwm_we,
		pwm_out => pwm_out);
		
	--
	-- Reset timer
	--
	process(clock)
	begin
		if rising_edge(clock) then
			if n_reset = '0' then
				reset_counter <= 0;
				reset_done <= '0';
			elsif reset_counter = 15 then
				reset_done <= '1';
			else
				reset_counter <= reset_counter + 1;
			end if;
		end if;
	end process;
	
	--
	-- DOUT
	--
	process(clock)
	begin
		if rising_edge(clock) then
			if n_reset = '0' then
				dout_register <= "0000";
			elsif io_wr = '1' and io_address(3 downto 0) = io_dout then
				dout_register <= cpu_data(3 downto 0);
			end if;
		end if;
	end process;
	
	timer_we <= '1' when io_address(3 downto 0) = io_timer and io_wr = '1' else '0';
	pwm_we <= '1' when io_address(3 downto 0) = io_pwm and io_wr = '1' else '0';
	
	--
	-- IO - inputs
	--
	
	with io_address(3 downto 0) select io_data <=
		(15 downto 2 => '0') & sw2 & sw1 when io_switch,
		X"000" & dout_register when io_dout,
		X"000" & din_comp when io_din,
		X"0000" when others;
	
end rtl;

--- End of file ---
