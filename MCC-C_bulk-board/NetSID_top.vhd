-------------------------------------------------------------------------------
--
-- This is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License,
-- or any later version, see <http://www.gnu.org/licenses/>
--
-- This is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- Company:  N/A
-- Engineer: Alex
--
-- Create Date:   04/23/2020
-- Design Name:   
-- Module Name:   NetSID_top_papilio.vhd
-- Project Name:  NetSID
-- Target Device: xc6slx9-tqg144-2
-- Tool versions: ISE 14.7
-- Description:   
-- 
-- NetSID top module
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- 
-------------------------------------------------------------------------------
library ieee;
	use ieee.std_logic_1164.all;
--	use ieee.std_logic_unsigned.all;
	use ieee.numeric_std.all;


entity NetSID is
	port (
		JOY_SELECT		: in  std_logic;	-- active low reset
		CLK				: in  std_logic;	-- main clock 32Mhz
		AUDIO1_LEFT		: out std_logic;	-- PWM audio out
		AUDIO1_RIGHT	: out std_logic;	-- PWM audio out
		LED1				: out std_logic;	-- output LED
		RX					: in  std_logic;	-- RS232 data to FPGA
		TX					: out std_logic;	-- RS232 data from FPGA
		LED2				: out std_logic;	-- output LED
		SW1				: in	std_logic
		);
	end;

architecture RTL of NetSID is

	signal clk01					: std_logic := '0';	--  1 Mhz
	signal clk04					: std_logic := '0';	--  4 Mhz
	signal clk32					: std_logic := '0';	-- 32 Mhz
	signal locked_pll				: std_logic := '0';
	
	signal ram_ai					: unsigned(13 downto 0) := (others => '0');
	signal ram_ao					: unsigned(13 downto 0) := (others => '1');
	signal ram_do					: std_logic_vector( 7 downto 0) := (others => '0');
	
	signal nrxdp					: std_logic := '0';
	signal rx_data_to_RAM		: unsigned(7 downto 0) := (others => '1');

	component Ram2Port
	port (
		rdaddress  	: in  std_logic_vector(13 downto 0);
		wraddress  	: in  std_logic_vector(13 downto 0);
		rdclock		: in  std_logic;
		wrclock		: in  std_logic;
		data			: in  std_logic_vector(7 downto 0);
		wren			: in  std_logic;
		q  			: out std_logic_vector(7 downto 0)
	);
  end component;
	
begin

	-----------------------------------------------------------------------------
	-- Clocks
	-----------------------------------------------------------------------------
	--
	-- provides a selection of synchronous clocks 1, 4 and 32 Mhz
	-- could provide the baud clock for serial comms
	-- provides a timed reset signal until pll is locked
	--
	u_clocks: entity work.Pll
	port map (
		inclk0	=> CLK,
		areset	=> JOY_SELECT,
		--
		c0			=> clk01,
		c1			=> clk04,
		c2			=> clk32,
		locked 	=> locked_pll	-- timed active high reset
	);

	-----------------------------------------------------------------------------
	-- FIFO buffer
	-----------------------------------------------------------------------------
	--
	-- dual ported async read / write access
	--
	u_ram: Ram2Port
	port map (
		q				=> ram_do,
		rdaddress	=> std_logic_vector(ram_ao),
		rdclock		=> clk32,

		wraddress	=> std_logic_vector(ram_ai),
		wrclock		=> nrxdp,
		data			=> std_logic_vector(rx_data_to_RAM),
		wren			=> '1'
	);
	
	
	ctrl: entity work.NetSIDCtrl
	generic map(
		Baud => 600000 -- set Baudrate here --
	)
	port map (
		JOY_SELECT		=> JOY_SELECT,
		CLK				=> CLK,
		AUDIO1_LEFT		=> AUDIO1_LEFT,
		AUDIO1_RIGHT	=> AUDIO1_RIGHT,
		LED1				=> LED1,
		RX					=> RX,
		TX					=> TX,
		LED2				=> LED2,
		SW1				=> SW1,
		
		clk01				=> clk01,
		clk04				=> clk04,
		clk32				=> clk32,
		
		locked_pll		=> locked_pll,
		
		ram_ai			=> ram_ai,
		ram_ao			=> ram_ao,
		ram_do			=> ram_do,
		nrxdp				=> nrxdp,
		rx_data_to_RAM => rx_data_to_RAM
	);

end RTL;