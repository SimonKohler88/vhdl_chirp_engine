#!/usr/bin/python3
# -*- coding: utf-8 -*-


from pynq import MMIO

BASE_ADDR = 0x43C00000  # example — use your actual address from Vivado
mmio = MMIO(BASE_ADDR, 0x20)

# Write registers
mmio.write(0x00, 1000)   # start_freq
mmio.write(0x04, 6000)   # stop_freq
mmio.write(0x08, 10)     # freq_step
mmio.write(0x0C, 100)    # freq_step_down

# Trigger chirp
mmio.write(0x10, 1)      # do_chirp (auto-clears next cycle)

# Read status
status = mmio.read(0x14)
ready          = (status >> 0) & 1
chirp_finished = (status >> 1) & 1
print(f"ready={ready}, chirp_finished={chirp_finished}")

