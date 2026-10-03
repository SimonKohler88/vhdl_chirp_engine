import os
import numpy as np
import matplotlib.pyplot as plt


def calc_sine_table(addr_range, amplitude_bitwidth, amplitude_bitwidth_name='AMP_WIDTH'):
    ampl = (2 ** amplitude_bitwidth - 2)/2 # todo range of signed
    s = ''
    for i in range(addr_range):
        phase = 2* np.pi / addr_range * i
        # 62 => to_signed( -6393,16),
        s += f'\t\t{i:<5} => to_signed({round(ampl* np.sin(phase)):>7}, {amplitude_bitwidth_name})'
        if i != addr_range - 1:
            s += ',\n'
        else:
            s += '\n'
    print(s)

if __name__ == '__main__':
    ramp_time_s = 0.001
    fs = 125e6
    f_start = 11.4e6
    f_stop = 11.68e6
    phase_width = 16
    f_start_n = f_start / fs
    f_stop_n = f_stop / fs
    
    # calc_sine_table(1024, 16)
    
    # f*2**PW /f_s = f_numerical
    print('f_start numerical: ', f_start * 2**phase_width /fs)
    print('f_stop numerical: ',f_stop * 2**phase_width /fs)
    
    
    
    
    