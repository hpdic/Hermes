# ==============================================================================
# @file plot_enc.py
# @author Dongfang Zhao (dzhao@uw.edu)
#
# @brief Visualization script for homomorphic encryption throughput benchmarks.
#
# @details
# This Python script generates high quality academic figures comparing the 
# performance of Hermes packed encryption against singular FHE baselines. 
# It processes raw latency data from three datasets (COVID 19, Bitcoin, and 
# hg38) and calculates throughput in terms of tuples per second (TPS). 
# The script utilizes a dual axis logarithmic plot: bars represent total 
# execution time with distinct textures for accessibility, while a secondary 
# line plot tracks the throughput trajectory. The resulting multi panel figure 
# is exported as a vector PDF suitable for inclusion in LaTeX manuscripts.
#
# @dependencies
# * matplotlib : Used for generating the multi panel logarithmic plots.
# * numpy : Used for numerical coordinate calculations.
#
# @usage
# python3 plot_enc.py
# ==============================================================================

import matplotlib.pyplot as plt
import numpy as np
import os

fig_dir = '../fig'
os.makedirs(fig_dir, exist_ok=True)

methods = ['Singular FHE', 'Hermes (128)', 'Hermes (4096)']
colors = ['#d62728', '#6baed6', '#08519c']
hatches = ['//', '\\\\', 'xx']

time_covid19 = [40374, 418, 144]
time_bitcoin = [127788, 1219, 152]
time_hg38 = [4048408, 35920, 1239]

tps_covid19 = [int(341 / (t / 1000)) for t in time_covid19]
tps_bitcoin = [int(1086 / (t / 1000)) for t in time_bitcoin]
tps_hg38 = [int(34424 / (t / 1000)) for t in time_hg38]

fig, (ax1, ax2, ax3) = plt.subplots(1, 3, figsize=(16, 5))
plt.rcParams['font.family'] = 'serif'

def plot_rich_panel(ax, time_data, tps_data, title, show_ylabel_left, show_ylabel_right):
    x = np.arange(len(methods))
    
    bars = ax.bar(x, time_data, color=colors, edgecolor='black', hatch=hatches, width=0.5, alpha=0.9)
    ax.set_yscale('log', base=10)
    ax.set_title(title, fontsize=14, pad=15)
    ax.set_xticks(x)
    ax.set_xticklabels(methods, fontsize=11)
    ax.grid(axis='y', linestyle=':', alpha=0.5)
    
    ax.set_ylim(min(time_data) * 0.2, max(time_data) * 50)
    
    if show_ylabel_left:
        ax.set_ylabel('Total Encryption Time (ms)', fontsize=12)

    for bar in bars:
        yval = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2.0, yval * 1.2, str(int(yval)) + ' ms', ha='center', va='bottom', fontsize=10)

    ax2 = ax.twinx()
    line = ax2.plot(x, tps_data, color='#ff7f0e', marker='^', markersize=9, linestyle='-.', linewidth=2.5)
    ax2.set_yscale('log', base=10)
    
    ax2.set_ylim(min(tps_data) * 0.2, max(tps_data) * 50)
    
    for i, txt in enumerate(tps_data):
        ax2.text(x[i], txt * 1.3, str(txt) + ' tps', ha='center', va='bottom', color='#d95f02', fontsize=10)
        
    if show_ylabel_right:
        ax2.set_ylabel('Throughput (Tuples / Second)', fontsize=12, color='#d95f02')
    else:
        ax2.set_yticks([]) 
        
    return bars, line

b1, l1 = plot_rich_panel(ax1, time_covid19, tps_covid19, '(a) COVID 19 (341 tuples)', True, False)
b2, l2 = plot_rich_panel(ax2, time_bitcoin, tps_bitcoin, '(b) Bitcoin (1086 tuples)', False, False)
b3, l3 = plot_rich_panel(ax3, time_hg38, tps_hg38, '(c) hg38 (34424 tuples)', False, True)

fig.legend([b1[0], b1[1], b1[2], l1[0]], 
           ['Singular FHE', 'Hermes Packed (Conservative: 128)', 'Hermes Packed (Optimal: 4096)', 'Throughput Trajectory'], 
           loc='upper center', bbox_to_anchor=(0.5, 1.15), ncol=4, fontsize=11, frameon=False)

plt.tight_layout()
out_path = os.path.join(fig_dir, 'eval_encryption.pdf')
plt.savefig(out_path, format='pdf', bbox_inches='tight')
print('Rich throughput plot with textures saved successfully to: ' + out_path)