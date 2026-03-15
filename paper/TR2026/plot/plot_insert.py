import matplotlib.pyplot as plt
import numpy as np
import os

fig_dir = '../fig'
os.makedirs(fig_dir, exist_ok=True)

methods = ['Plaintext', 'Singular', 'Hermes (Amortized)']
colors = ['#2ca02c', '#d62728', '#1f77b4']
hatches = ['\\\\', '//', '']

ins_covid19 = [1.12, 124.12, 0.0308]
ins_bitcoin = [1.12, 123.98, 0.0308]
ins_hg38 = [1.01, 123.93, 0.0308]

fig, (ax1, ax2, ax3) = plt.subplots(1, 3, figsize=(15, 4.5))
plt.rcParams['font.family'] = 'serif'

def plot_amortized_insert(ax, data, title, show_ylabel):
    x = np.arange(len(methods))
    bars = ax.bar(x, data, color=colors, edgecolor='black', hatch=hatches, width=0.6, alpha=0.9)
    ax.set_yscale('log', base=10)
    ax.set_title(title, fontsize=14, pad=15)
    ax.set_xticks(x)
    ax.set_xticklabels(methods, fontsize=11)
    ax.grid(axis='y', linestyle=':', alpha=0.6)
    
    # 调整 Y 轴下限以容纳极小的均摊数值
    ax.set_ylim(0.005, 1000)
    
    if show_ylabel:
        ax.set_ylabel('Amortized Latency per Tuple (ms)', fontsize=12)

    for bar in bars:
        yval = bar.get_height()
        # 针对小于 1 的数值保留四位小数，大于 1 的保留两位
        label_str = '{:.4f}'.format(yval) if yval < 0.1 else '{:.2f}'.format(yval)
        ax.text(bar.get_x() + bar.get_width()/2.0, yval * 1.2, label_str, ha='center', va='bottom', fontsize=11)
    
    return bars

b1 = plot_amortized_insert(ax1, ins_covid19, '(a) COVID 19', True)
b2 = plot_amortized_insert(ax2, ins_bitcoin, '(b) Bitcoin', False)
b3 = plot_amortized_insert(ax3, ins_hg38, '(c) hg38', False)

fig.legend([b1[0], b1[1], b1[2]], ['Plaintext Baseline', 'Singular FHE', 'Hermes Packed (4096)'], 
           loc='upper center', bbox_to_anchor=(0.5, 1.15), ncol=3, fontsize=12, frameon=False)

plt.tight_layout()
out_path = os.path.join(fig_dir, 'eval_insert.pdf')
plt.savefig(out_path, format='pdf', bbox_inches='tight')
print('Amortized insert latency plot saved to: ' + out_path)