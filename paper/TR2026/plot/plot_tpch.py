import os
import matplotlib.pyplot as plt
import numpy as np

# Scalability data points (Tuple Counts: 1000, 5000, 10000, 15000)
tuple_counts = [1000, 5000, 10000, 15000]

# Workload 1: Q1 Aggregation latency (ms) from 3 runs
q1_plain = [[21, 19, 21], [33, 31, 33], [50, 49, 49], [79, 78, 82]]
q1_hermes = [[45, 41, 41], [42, 41, 41], [42, 42, 39], [42, 43, 43]]

# Workload 2: Insertion (5 ops) - Scalar FHE baseline scaled to O(N) oblivious cost
ins_base_raw = [[12628, 12605, 12577], [12760, 12630, 12792], [12581, 12754, 12638], [12751, 12658, 12815]]
ins_hermes = [[713, 682, 697], [694, 693, 686], [699, 694, 666], [690, 690, 693]]

# Workload 3: Deletion (5 ops)
del_base_raw = [[12686, 12698, 12645], [12751, 12525, 12735], [12652, 12759, 12621], [12750, 12659, 12793]]
del_hermes = [[329, 348, 314], [373, 381, 364], [91, 63, 87], [89, 90, 79]]

def get_stats(data_list):
    means = [np.mean(d) for d in data_list]
    stds = [np.std(d) for d in data_list]
    return np.array(means), np.array(stds)

def scale_baseline(raw_data, tc_list):
    scaled_data = []
    for i, tc in enumerate(tc_list):
        scaled_run = [(val / 100.0) * (tc * 5.0) for val in raw_data[i]]
        scaled_data.append(scaled_run)
    return scaled_data

# Process stats
q1_p_mean, q1_p_std = get_stats(q1_plain)
q1_h_mean, q1_h_std = get_stats(q1_hermes)

ins_b_scaled = scale_baseline(ins_base_raw, tuple_counts)
ins_b_mean, ins_b_std = get_stats(ins_b_scaled)
ins_h_mean, ins_h_std = get_stats(ins_hermes)

del_b_scaled = scale_baseline(del_base_raw, tuple_counts)
del_b_mean, del_b_std = get_stats(del_b_scaled)
del_h_mean, del_h_std = get_stats(del_hermes)

# Increase font sizes for academic publication standards
plt.rcParams.update({'font.size': 14})
plt.rcParams.update({'axes.titlesize': 16})
plt.rcParams.update({'axes.labelsize': 15})
plt.rcParams.update({'legend.fontsize': 12})
plt.rcParams.update({'xtick.labelsize': 13})
plt.rcParams.update({'ytick.labelsize': 13})

# Generate 1x3 Chart with adjusted size
fig, axes = plt.subplots(1, 3, figsize=(15, 5))

# Q1 Aggregation Plot
axes[0].errorbar(tuple_counts, q1_p_mean, yerr=q1_p_std, label='Plaintext', marker='o', capsize=4, linestyle='--', color='#d62728', linewidth=2)
axes[0].errorbar(tuple_counts, q1_h_mean, yerr=q1_h_std, label='Hermes', marker='s', capsize=4, linestyle='-', color='#1f77b4', linewidth=2)
axes[0].set_title('Q1 Aggregation')
axes[0].set_xlabel('Tuple Count')
axes[0].set_ylabel('Latency (ms)')
axes[0].grid(True, linestyle=':', alpha=0.6)
axes[0].legend()

# Insertion Plot (Log Scale)
axes[1].errorbar(tuple_counts, ins_b_mean, yerr=ins_b_std, label='Scalar FHE (O(N))', marker='o', capsize=4, linestyle='--', color='#d62728', linewidth=2)
axes[1].errorbar(tuple_counts, ins_h_mean, yerr=ins_h_std, label='Hermes (O(1))', marker='s', capsize=4, linestyle='-', color='#1f77b4', linewidth=2)
axes[1].set_yscale('log')
axes[1].set_title('Orders Insertion (5 ops)')
axes[1].set_xlabel('Tuple Count')
axes[1].set_ylabel('Latency (ms) [Log]')
axes[1].grid(True, which="both", linestyle=':', alpha=0.6)
axes[1].legend()

# Deletion Plot (Log Scale)
axes[2].errorbar(tuple_counts, del_b_mean, yerr=del_b_std, label='Scalar FHE (O(N))', marker='o', capsize=4, linestyle='--', color='#d62728', linewidth=2)
axes[2].errorbar(tuple_counts, del_h_mean, yerr=del_h_std, label='Hermes (O(1))', marker='s', capsize=4, linestyle='-', color='#1f77b4', linewidth=2)
axes[2].set_yscale('log')
axes[2].set_title('Orders Deletion (5 ops)')
axes[2].set_xlabel('Tuple Count')
axes[2].set_ylabel('Latency (ms) [Log]')
axes[2].grid(True, which="both", linestyle=':', alpha=0.6)
axes[2].legend()

plt.tight_layout()
output_path = os.path.expanduser('~/hpdic/Hermes/paper/TR2026/fig/')
if not os.path.exists(output_path):
    os.makedirs(output_path)
plt.savefig(os.path.join(output_path, 'eval_tpch.pdf'), bbox_inches='tight')