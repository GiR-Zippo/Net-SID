# Introduction / Acknowledgments

This project is a port of the [Net-SID](https://github.com/benbaker76/NetSID) to the CycloneIV EPCE6.

More more informations, plz take a look into his documentation & read.me

# Pinout

The pinout for the rz-easyFPGA A2.2 board is:

110 - Audio Left

112 - Audio Right

It uses the on board serial to communicate with your computer.


The pinout for the MCC-C bulk board is:
86 - Audio Left
84 - Audio Right

87 - RX
85 - TX

88 - Clock
89 - !Reset

For this board you'll need an USB<->Serial/UART adaptor.


Plz change the speed according to your USB<->Serial cable in the 
[server_v2_HybridSID - handshake](https://github.com/GiR-Zippo/Net-SID/blob/master/server_v2_HybridSID%20-%20handshake.py) 
and [async.v](https://github.com/GiR-Zippo/Net-SID/blob/master/rtl/async.v) 
