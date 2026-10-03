echo off

Set MODULE=axi_lite_top
Set FILES=chirp_reg.vhd %MODULE%.vhd %MODULE%_tb.vhd
@REM Set PACKAGES=sine_table_pkg.vhd

@REM ghdl -a --std=08 %PACKAGES%
ghdl -a --std=08 %FILES%

IF %ERRORLEVEL%==1 (
PAUSE
goto end
)

ghdl -r --std=08 --time-resolution=ns %MODULE%_tb --vcd=func.vcd --stop-time=1ms
REM ghdl -r --std=08 --time-resolution=ns %MODULE%_tb --wave=func.ghw --stop-time=100us


if %ERRORLEVEL%==1 (
PAUSE
) else (
    REM gtkwave func.ghw wave_save.gtkw
    gtkwave func.vcd wave_save_vcd.gtkw
)




:end
REM PAUSE

