library ieee;
	use ieee.std_logic_1164.all;
--	use ieee.std_logic_unsigned.all;
	use ieee.numeric_std.all;
	
entity NetSIDCtrl is
  generic(
		Baud : integer := 600000
   );
	port (
		JOY_SELECT		: in  std_logic;	-- active low reset
		CLK				: in  std_logic;	-- main clock 32Mhz
		AUDIO1_LEFT		: out std_logic;	-- PWM audio out
		AUDIO1_RIGHT	: out std_logic;	-- PWM audio out
		LED1				: out std_logic;	-- output LED
		RX					: in  std_logic;	-- RS232 data to FPGA
		TX					: out std_logic;	-- RS232 data from FPGA
		LED2				: out std_logic;	-- output LED
		SW1				: in	std_logic;
		
		-----------------------------------------------------------------------------
		-- Clocks
		-----------------------------------------------------------------------------
		clk01				: in  std_logic;	--  1 Mhz
		clk04				: in  std_logic;	--  4 Mhz
		clk32				: in  std_logic;	-- 32 Mhz
		locked_pll		: in  std_logic;
		
		-----------------------------------------------------------------------------
		-- FIFO buffer
		-----------------------------------------------------------------------------
		ram_ai			: inout unsigned(13 downto 0);
		ram_ao			: inout unsigned(13 downto 0);
		ram_do			: in	  std_logic_vector( 7 downto 0);
		rx_data_to_RAM	: out   unsigned(7 downto 0);
		nrxdp				: out   std_logic
		
		);
	end;
	
architecture RTL of NetSIDCtrl is

	type uartsm is (
		st00,
		st01,
		st02,
		st03,
		st04
	);

	type RAMtoSIDState is (
		stInit,
		stDelay1,
		stDelay2,
		stSync,
		stWait1,
		stWait2,
		stAddr,
		stData,
		stWrite,
		stIdle,
		stSpecial
	);

	signal clk_div					: unsigned(4 downto 0) := (others => '0');
	--signal clk01					: std_logic := '0';	--  1 Mhz
	--signal clk04					: std_logic := '0';	--  4 Mhz
	--signal clk32					: std_logic := '0';	-- 32 Mhz
	--signal locked_pll				: std_logic := '0';

	signal stUARTnow				: uartsm := st01;
	signal stUARTnext				: uartsm := st01;
	signal tx_data					: unsigned(7 downto 0) := (others => '1');
	signal rx_data					: unsigned(7 downto 0) := (others => '1');

	signal TxD_busy				: std_logic := '0';
	signal write_to_uart			: std_logic := '0';
	signal rx_data_present		: std_logic := '0';

	signal stSIDnow				: RAMtoSIDState := stInit;
	signal stSIDnext				: RAMtoSIDState := stInit;
	
	signal sid_num					: unsigned(1 downto 0) := (others => '0');
	signal sid_addr				: unsigned(4 downto 0) := (others => '0');
	signal sid_din					: unsigned(7 downto 0) := (others => '0');

	signal sid1_addr				: unsigned(4 downto 0) := (others => '0');
	signal sid1_audio				: std_logic_vector(17 downto 0) := (others => '0');
	signal sid1_dout				: unsigned(7 downto 0) := (others => '0');
	signal sid1_din				: unsigned(7 downto 0) := (others => '0');
	signal sid1_we					: std_logic := '0';
	signal sid1_px					: unsigned(7 downto 0) := (others => '0');
	signal sid1_py					: unsigned(7 downto 0) := (others => '0');

	signal sid2_addr				: unsigned(4 downto 0) := (others => '0');
	signal sid2_audio				: std_logic_vector(17 downto 0) := (others => '0');
	signal sid2_dout				: unsigned(7 downto 0) := (others => '0');
	signal sid2_din				: unsigned(7 downto 0) := (others => '0');
	signal sid2_we					: std_logic := '0';
	signal sid2_px					: unsigned(7 downto 0) := (others => '0');
	signal sid2_py					: unsigned(7 downto 0) := (others => '0');

	signal cycle_cnt				: unsigned(20 downto 0) := (others => '0');
	signal rst						: std_logic := '0';
	signal sid_rst					: std_logic := '0';
	signal audio_pwm				: std_logic := '0';
	signal fifo_empty				: std_logic := '1';
	signal fifo_stop				: std_logic := '1';
	signal buf_full				: std_logic := '0';
	signal buf_full_last			: std_logic := '0';
	signal buf_full_fe			: std_logic := '0';
	signal buf_full_re			: std_logic := '0';
	
	signal rx_state				: unsigned(1 downto 0) := (others => '0');
	signal rx_special				: std_logic := '0';
	signal mode						: std_logic := '0';
	signal sid_swapped			: unsigned(1 downto 0) := (others => '0');
	signal mute_audio				: std_logic := '0';

	component async_receiver 
	generic(
        Baud        	: integer := Baud
    );
	port (
		clk				: in  std_logic;
		RxD				: in  std_logic;
		RxD_data			: out unsigned(7 downto 0);
		RxD_data_ready	: out std_logic
	);
	end component;
	
	
	component async_transmitter 
	generic(
        Baud       	: integer := Baud
    );
	port (
		clk				: in  std_logic;
		TxD				: out std_logic;
		TxD_start		: in  std_logic;
		TxD_data			: in unsigned(7 downto 0);
		TxD_busy			: out std_logic
	);
	end component;
   
  component SEG_Display
  port(
		clk	: in  std_logic;
		rst_n : in  std_logic;
		data  : in unsigned(15 downto 0);
		seg   : out std_logic_vector(7 downto 0); 
		cs 	: out std_logic_vector(3 downto 0)
	);
  end component;
  
  
begin
	AUDIO1_LEFT		<= audio_pwm when mute_audio = '0' else '0';
	AUDIO1_RIGHT	<= audio_pwm when mute_audio = '0' else '0';
	nrxdp				<= not rx_data_present;
	rst 				<= not locked_pll;
	LED2 				<= not buf_full;
	LED1 				<= not sid_swapped(0);


  -----------------------------------------------------------------------------
  -- UART RS232 rx and tx
  -----------------------------------------------------------------------------
  --
  -- 8-bit, 1 stop-bit, no parity transmit and receive macros.
  -- Each contains an embedded 16-byte FIFO buffer.
  --
	
	des: async_receiver 
	port map (
		clk				=> CLK,
		RxD				=> RX,

		RxD_data			=> rx_data,				-- received byte
		RxD_data_ready	=> rx_data_present	-- one clock pulse when RxD_data is valid
	);

	ser: async_transmitter port map (
		clk				=> CLK,
		TxD				=> TX,

		TxD_start		=> write_to_uart,		--	start send when set
		TxD_data			=> tx_data,				-- data byte to send
		TxD_busy			=> TxD_busy				-- busy when set
	);

	u_audiomixer: entity work.audiomixer
	port map(
		clk				=> CLK,
		rst				=> rst,
		ena				=> '1',
		data_in1			=> sid1_audio,
		data_in2			=> sid2_audio,
		audio_out		=> audio_pwm
	);

	-----------------------------------------------------------------------------
	-- SID 6581
	-----------------------------------------------------------------------------
	--
	-- Implementation of SID sound chip
	--
	u_sid1: entity work.sid6581
	port map (
		clk_1mhz		=> clk01,		-- main SID clock
		clk32			=> CLK,			-- main clock signal
--		clk_DAC		=> clk32,		-- DAC clock signal, must be as high as possible for the best results
		reset			=> rst or sid_rst, -- high active reset signal (reset when reset = '1')
		cs				=> '1',			-- "chip select", when this signal is '1' this model can be accessed
		we				=> sid1_we,		-- when '1' this model can be written to, otherwise access is considered as read
		addr			=> sid1_addr,	-- address lines (5 bits)
		di				=> sid1_din,	-- data in (to chip, 8 bits)
		do				=> sid1_dout,	-- data out	(from chip, 8 bits)
		pot_x			=> sid1_px,		-- paddle input-X
		pot_y			=> sid1_py,		-- paddle input-Y
		mode			=> mode,
--		audio_out	=> audio_pwm,	-- this line outputs the PWM audio-signal
		std_logic_vector(audio_data)	=> sid1_audio	-- audio out 18 bits
	);
		
	--
	u_sid2: entity work.sid8580
	port map (
		clk_1mhz		=> clk01,		-- main SID clock
		clk32			=> CLK,			-- main clock signal
--		clk_DAC		=> clk32,		-- DAC clock signal, must be as high as possible for the best results
		reset			=> rst or sid_rst, -- high active reset signal (reset when reset = '1')
		cs				=> '1',			-- "chip select", when this signal is '1' this model can be accessed
		we				=> sid2_we,		-- when '1' this model can be written to, otherwise access is considered as read
		addr			=> sid2_addr,	-- address lines (5 bits)
		di				=> sid2_din,	-- data in (to chip, 8 bits)
		do				=> sid2_dout,	-- data out	(from chip, 8 bits)
		pot_x			=> sid2_px,		-- paddle input-X
		pot_y			=> sid2_py,		-- paddle input-Y
		mode			=> mode,
--		audio_out	=> audio_pwm,	-- this line outputs the PWM audio-signal
		std_logic_vector(audio_data)	=> sid2_audio	-- audio out 18 bits
	);
		
	-----------------------------------------------------------------------------
	-- state machine control for ram_to_sid process
	sm_control: process (clk32, rst)
	begin
		if falling_edge(clk32) then
			if rst = '1' then
				stSIDnow <= stInit;
			else
				stSIDnow <= stSIDnext;
			end if;
		end if;
	end process;

	-- detect FIFO empty state
	fifo_control: process(clk32)
	begin
		if falling_edge(clk32) then
			if (ram_ai = ram_ao) then
					fifo_empty <= '1';
				else
					fifo_empty <= '0';
			end if;
		end if;
	end process;

	-- copy data from FIFO to SID at cycle accurate rate
	-- read pointer cannot overtake write pointer and will block (wait)
	ram_to_sid: process (clk04, stSIDnow, rst, sid_rst)
	begin
		if rst = '1' then
			ram_ao <= (others => '1');
			stSIDnext	<= stInit;
		elsif sid_rst = '1' then
			ram_ao <= (others => '1');
			stSIDnext	<= stInit;
		elsif rising_edge(clk04) then
			if fifo_empty = '0' then
				case stSIDnow is
					when stInit		=>
						sid1_we			<= '0';
						sid2_we			<= '0';
						ram_ao			<= (others => '0');
						cycle_cnt		<= (others => '0');
						stSIDnext		<= stDelay1;
					when stDelay1	=>
						sid1_we			<= '0';
						sid2_we			<= '0';
						cycle_cnt(17 downto 10) <= unsigned(ram_do);		-- delay high
						ram_ao			<= ram_ao + 1;
						stSIDnext		<= stDelay2;
					when stDelay2	=>
						cycle_cnt(9 downto 2)  <= unsigned(ram_do);		-- delay low
						ram_ao			<= ram_ao + 1;
						stSIDnext		<= stAddr;
					when stAddr		=>
						sid_num			<= unsigned(ram_do(6 downto 5));
						sid_addr			<= unsigned(ram_do(4 downto 0));	-- address
						ram_ao			<= ram_ao + 1;
						stSIDnext		<= stData;
					when stData		=>
						sid_din			<= unsigned(ram_do);					-- value
						ram_ao			<= ram_ao + 1;
						stSIDnext		<= stSync;
					when stSync		=>
						if cycle_cnt = x"0000" then
							stSIDnext 	<= stWrite;
						else
							cycle_cnt 	<= cycle_cnt - 1;						-- wait cycles x4 (since this runs at clk04)
							stSIDnext 	<= stSync;
						end if;	
					when stWrite	=>
						case sid_num xor sid_swapped is
							when "00"	=>
								sid1_addr	<= sid_addr;
								sid1_din		<= sid_din;
								sid1_we		<= '1';
							when "01"	=>
								sid2_addr	<= sid_addr;
								sid2_din		<= sid_din;
								sid2_we		<= '1';
							when others	=> null;
						end case;
						stSIDnext		<= stDelay1;
					when others		=> null;
				end case;
			end if;
		end if;
	end process;

	-----------------------------------------------------------------------------
	-- data is streaming in from serial at 2000000-8N1 as a byte quad "DD DD RR VV"
	-- DDDD is a big-endian delay in SID clock cycles (985248 Hz PAL or 1022727 Hz NTSC)
	-- RR is a SID register
	-- VV is the value to be written to that register
	--
	-- example: 00 08 04 ff 
	--					means: delay 0008 cycles then write ff to register 04

	-- this receives data from the serial port and buffers
	-- it into 16K of RAMB FIFO
	--
	uart_to_ram: process(clk32, rx_data_present, rst)
	begin
		if rst = '1' then
			ram_ai <= (others => '1');
			rx_state <= "00";
			mode <= '0';
			sid_swapped <= "00";
		elsif rising_edge(rx_data_present) then

			-- special commands
			if rx_state = "00" and rx_data = "11111111" then
				rx_special <= '1';
			elsif rx_state = "01" and rx_special = '1' then
				sid_rst 	   <= rx_data(7);
				mute_audio  <= rx_data(6);
				mode 			<= rx_data(0);
				sid_swapped <= rx_data(2 downto 1);
			elsif rx_state = "00" and rx_special = '1' then
				rx_special <= '0';
			end if;
			
			--ab in den RAM
			if rx_special = '0' then
				rx_data_to_RAM <= rx_data;
				ram_ai <= ram_ai + 1;
			end if;

			--keep track of the state
			rx_state <= rx_state+1;
		end if;
	end process;

	-- debug test points

	-----------------------------------------------------------------------------

	-- detect rising and falling edges of buf_full
	buf_full_fe <=     buf_full_last and not buf_full;
	buf_full_re <= not buf_full_last and     buf_full;

	detect_edges: process(clk32)
	begin
		if falling_edge(clk32) then
			buf_full_last <= buf_full;
		end if;
	end process;

	-- transmit a serial byte to stop or start incoming data flow
	uart_fifo_tx: process(clk32)
	begin
		if falling_edge(clk32) then
			if buf_full_re = '1' or buf_full_fe = '1' then
				stUARTnow <= st00;
			else
				stUARTnow <= stUARTnext;
			end if;
		end if;
	end process;

	-- strobe uart we line for exactly one clock cycle
	uart_fifo_we: process(clk32)
	begin
		if rising_edge(clk32) then
			case stUARTnow is
				when st00		=>
					write_to_uart <= '1';
					stUARTnext <= st01;
				when st01		=>
					write_to_uart <= '0';
					stUARTnext <= st01;
				when others		=> null;
			end case;
		end if;		
	end process;

	-- detect a buffer almost full condition
	fifo_handshake: process(clk32)
	begin
		if falling_edge(clk32) then
			if (ram_ai - ram_ao) > 14288 then
				tx_data <= x"45"; -- End TX
				buf_full <= '1';
			elsif (ram_ai - ram_ao) < 4096 then
				tx_data <= x"53"; -- Start TX
				buf_full <= '0';
			end if;
		end if;
	end process;

end RTL;