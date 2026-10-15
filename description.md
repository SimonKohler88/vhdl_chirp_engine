# Chirp Engine

Current VHDL Module represents a Frequency Chirp Module with following characteristics:

* The start Frequency is always present. Only on command the Chirp occurs.
* the Slope is configurable.
* The Downslope is configurable as well, making it possible to make Updown-Chirps.
* The start of Chirp is signaled to the outside.

This Module has been developed to use on RedPitaya for a Radar Project, where the Frequency controls a PLL, which
is controling the Analog Frontend. Constant Output of Basefrequency as well as additional Downslope makes it possible
so that the PLL never loses Lock.

## Directory Structure

In each Directory there are several files. Testbenches are marked with \"_tb\" appendix. The batch files are to
simulate the testbench with ghdl (VHDL compiler) and gtkwave (Waveform Viewer). Two batchfiles are provided: \"_ghw\"
and \"_vcd\". The difference lies in the produced File:

* .vcd : This Standard has correct Timescale but does not support typed variables e.g. state machine states.
* .ghw : Has incorrect Timescale but supports typed variables.

Other files include .gtkw files (savefiles of the Viewer) and .cf Files (ghdl work files)

## VHDL overview

* chirp_engine_top.vhd : Connecting Submodules
* axi_lite/axi_lite_top.vhd : Base functionality of the AXI 4 Lite interface
* axi_lite/chirp_reg.vhd :    Definition of the available Configuration Registers
* chirp_engine/chirp_engine.vhd : the Chirp functionality
* chirp_engine/sine_table_pkg.vhd: Constant definitions of the module like Sine Table, Address Width, Phase Accumulator
  Width, ...

## Parameters

Base Address: 0x60000000

Offset Name R/W Function
0x00 Start Frequency R+W Frequency where the Chirp is starting from
0x04 Stop Frequency R+W Frequency where the Chirp ending
0x08 Frequency Step Up R+W slope of the frequency rise
0x0C Frequency Step Down R+W slope of the frequency fall
0x10 Do Chirp W initiates a chirp on rising edge
0x14 Repeat Chirp W repeats the chirp until set to 0
0x18 Enable Chirp Module W redirects the chirp output to DAC.
0x1C Status R Bit Function
0 chirp module ready
1 chirp finished pulse
2 do chirp loopback
3 repeat chirp loopback
4 enable module loopback

## Python

The Python implementation uses the Library MMIO to write the settings. Current implementation is crude but furfills the
cause.

## Howto implement on RedPitaya

* put SD-Card into computer.
  * on Boot Partition, navigate to fpga/Z10_125/ and create a folder called `chirp engine`
  * Put the provided `fpga.bin` , `fpga.dtbo` and the gitfile (I forgot the name) in this folder.
* Put the SD Card into RedPitaya and start jupyterlab (Lab, not tree!)
* Drag and drop the Jupyter file into the Files-Panel on the left.
* The Jupyter File should be executable. Inspect the code for an example.

Note: In the case of ValidTHz Project, the Python code moved to the thz Library.

## Errata and possible improvements

In conjunction with RedPitaya:

* lower frequencies produce a lower amplitude. Current implementation produces approx +/- 1V @ 12 MHz. 500kHz will
  produce around +/- 0.3 V Amplitude. Reason unknown and not investigated, since it works for the FHNW ThzValid Usecase.
* The Phase Accumulator is with 32+5 = 37 Bit a bit small. With the Settings of
    * start Freq: 11.475 MHz
    * end Freq : 12.025 MHz
    * freq step up: 8

  it will prduce a chirp of 10 ms with a band of 650 kHz. The small phase accumulator does not leave room for longer
  chirps.
* Maybe a table for different freq steps per frequency can be implemented, so that nonlinearities of the VCO's can be
  egalized
