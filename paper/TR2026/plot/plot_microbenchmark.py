import matplotlib.pyplot as plt
import numpy as np
import os

fig_dir = '../fig'
os.makedirs(fig_dir, exist_ok=True)

slots = [128, 256, 512, 1024, 2048, 4096, 8192]

paillier_add = [1.94735, 3.79137, 7.55414, 15.2528, 30.2376, 60.1356, 120.567]
hermes_add = [1.72359, 1.54893, 1.64355, 1.55728, 1.5579, 1.57927, 1.56857]

std_fhe_agg = [630.192, 725.202, 809.227, 899.136, 986.457, 1078.02, 1165.94]
hermes_agg = [1.58602, 1.78463, 1.59773, 1.57844, 1.57942, 1.57126, 1.57973]

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(8, 3.2))
plt.rcParams['font.family'] = 'serif'

ax1.plot(slots, paillier_add, marker='o', color='#d62728', linewidth=2, markersize=5, label='Paillier Add')
ax1.plot(slots, hermes_add, marker='s', color='#08519c', linewidth=2, markersize=5, label='Hermes SIMD Add')
ax1.set_xscale('log', base=2)
ax1.set_yscale('log', base=10)
ax1.set_xticks(slots)
ax1.set_xticklabels(slots, rotation=45, fontsize=10)
ax1.set_xlabel('Packing Scale (slots)', fontsize=11)
ax1.set_ylabel('Execution Time (ms)', fontsize=11)
ax1.set_title('(a) Addition', fontsize=12)
ax1.grid(True, which='both', linestyle=':', alpha=0.6)

speedup_add = int(paillier_add[-1] / hermes_add[-1])
bbox_props = dict(boxstyle='round,pad=0.3', facecolor='#fff5eb', edgecolor='#fd8d3c', alpha=1.0)
ax1.text(256, 40, f'Speedup: {speedup_add}x', ha='center', va='center', fontsize=10, color='#d94801', bbox=bbox_props)

ax2.plot(slots, std_fhe_agg, marker='^', color='#ff7f0e', linewidth=2, markersize=5, label='Standard FHE Agg')
ax2.plot(slots, hermes_agg, marker='D', color='#2ca02c', linewidth=2, markersize=5, label='Hermes Agg')
ax2.set_xscale('log', base=2)
ax2.set_yscale('log', base=10)
ax2.set_xticks(slots)
ax2.set_xticklabels(slots, rotation=45, fontsize=10)
ax2.set_xlabel('Packing Scale (slots)', fontsize=11)
ax2.set_title('(b) Aggregation', fontsize=12)
ax2.grid(True, which='both', linestyle=':', alpha=0.6)

speedup_agg = int(std_fhe_agg[-1] / hermes_agg[-1])
ax2.text(1024, 30, f'Speedup: {speedup_agg}x', ha='center', va='center', fontsize=10, color='#d94801', bbox=bbox_props)

fig.legend(loc='upper center', bbox_to_anchor=(0.5, 1.2), ncol=2, fontsize=10, frameon=False)

plt.tight_layout()
out_path = os.path.join(fig_dir, 'eval_microbenchmarks.pdf')
plt.savefig(out_path, format='pdf', bbox_inches='tight')