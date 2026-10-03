echo off

Set MODULE=chirp_engine
Set FILES=%MODULE%.vhd %MODULE%_tb.vhd 
Set PACKAGES=sine_table_pkg.vhd

ghdl -a --std=08 %PACKAGES%
ghdl -a --std=08 %FILES%

IF %ERRORLEVEL%==1 (
PAUSE
goto end
)

ghdl -r --std=08 --time-resolution=ns %MODULE%_tb --vcd=func.vcd --stop-time=100us
REM ghdl -r --std=08 --time-resolution=ns %MODULE%_tb --wave=func.ghw --stop-time=100us


if %ERRORLEVEL%==1 (
PAUSE
) else (
    REM gtkwave func.ghw wave_save.gtkw
    gtkwave func.vcd wave_save_vcd.gtkw
)




:end
REM PAUSE

