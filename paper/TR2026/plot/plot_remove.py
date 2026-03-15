import matplotlib.pyplot as plt
import numpy as np
import os

fig_dir = '../fig'
os.makedirs(fig_dir, exist_ok=True)

methods = ['Plaintext', 'Singular', 'Hermes-128', 'Hermes-4096']
colors = ['#2ca02c', '#d62728', '#6baed6', '#08519c']
hatches = ['\\\\', '//', 'xx', '++']

rmv_covid19 = [0.97, 3.89, 0.4439, 0.01315]
rmv_bitcoin = [1.26, 4.02, 0.4377, 0.01322]
rmv_hg38 = [1.63, 4.80, 0.4432, 0.01300]

speedup_covid19 = int(rmv_covid19[1] / rmv_covid19[3])
speedup_bitcoin = int(rmv_bitcoin[1] / rmv_bitcoin[3])
speedup_hg38 = int(rmv_hg38[1] / rmv_hg38[3])

fig, (ax1, ax2, ax3) = plt.subplots(1, 3, figsize=(16, 5))
plt.rcParams['font.family'] = 'serif'

x_pos = np.array([0, 1.5, 3.0, 4.5])

def plot_rich_remove(ax, data, speedup, title, show_ylabel):
    bars = ax.bar(x_pos, data, color=colors, edgecolor='black', hatch=hatches, width=0.7, alpha=0.9)
    ax.set_yscale('log', base=10)
    ax.set_title(title, fontsize=14, pad=15)
    ax.set_xticks(x_pos)
    ax.set_xticklabels(methods, fontsize=11)
    ax.grid(axis='y', linestyle=':', alpha=0.6)
    
    ax.set_ylim(0.005, 50)
    
    if show_ylabel:
        ax.set_ylabel('Latency per Tuple (ms)', fontsize=12)

    for bar in bars:
        yval = bar.get_height()
        if yval < 0.1:
            label_str = '{:.5f}'.format(yval)
        elif yval < 2:
            label_str = '{:.4f}'.format(yval)
        else:
            label_str = '{:.2f}'.format(yval)
        ax.text(bar.get_x() + bar.get_width()/2.0, yval * 1.3, label_str, ha='center', va='bottom', fontsize=10)
    
    x_sing = x_pos[1]
    x_h4096 = x_pos[3]
    y_line = max(data) * 2.5
    y_drop_sing = data[1] * 1.5
    y_drop_h4096 = data[3] * 1.5
    
    ax.plot([x_sing, x_sing, x_h4096, x_h4096], 
            [y_drop_sing, y_line, y_line, y_drop_h4096], 
            color='#d94801', linewidth=1.5)
    
    bbox_props = dict(boxstyle='round,pad=0.3', facecolor='#fff5eb', edgecolor='#fd8d3c', alpha=1.0)
    ax.text((x_sing + x_h4096)/2.0, y_line * 1.3, 'Speedup: ' + str(speedup) + 'x', 
            ha='center', va='bottom', fontsize=11, color='#d94801', bbox=bbox_props)
    
    return bars

b1 = plot_rich_remove(ax1, rmv_covid19, speedup_covid19, '(a) COVID-19', True)
b2 = plot_rich_remove(ax2, rmv_bitcoin, speedup_bitcoin, '(b) Bitcoin', False)
b3 = plot_rich_remove(ax3, rmv_hg38, speedup_hg38, '(c) hg38', False)

fig.legend([b1[0], b1[1], b1[2], b1[3]], methods, loc='upper center', bbox_to_anchor=(0.5, 1.12), ncol=4, fontsize=12, frameon=False)

plt.tight_layout()
out_path = os.path.join(fig_dir, 'eval_remove.pdf')
plt.savefig(out_path, format='pdf', bbox_inches='tight')
print('Corrected remove latency plot saved to: ' + out_path)