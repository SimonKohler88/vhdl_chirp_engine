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

REM ghdl -r --std=08 --time-resolution=ns %MODULE%_tb --vcd=func.vcd --stop-time=100us
ghdl -r --std=08 --time-resolution=ns %MODULE%_tb --wave=func.ghw --stop-time=100us

REM ghdl -r --std=08  --coverage --time-resolution=ns %MODULE%_tb   --stop-time=500us --wave=func.ghw --psl-report=psl_report.json --psl-report-uncovered

if %ERRORLEVEL%==1 (
PAUSE
) else (
    gtkwave func.ghw wave_save.gtkw
    REM gtkwave func.vcd wave_save.gtkw
)




:end
REM PAUSE

