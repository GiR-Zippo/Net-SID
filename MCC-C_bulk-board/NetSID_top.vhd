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

begin

ctrl: entity work.NetSIDCtrl
	port map (
		JOY_SELECT		=> JOY_SELECT,
		CLK				=> CLK,
		AUDIO1_LEFT		=> AUDIO1_LEFT,
		AUDIO1_RIGHT	=> AUDIO1_RIGHT,
		LED1				=> LED1,
		RX					=> RX,
		TX					=> TX,
		LED2				=> LED2,
		SW1				=> SW1
	);

end RTL;