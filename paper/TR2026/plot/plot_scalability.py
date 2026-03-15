import matplotlib.pyplot as plt
import numpy as np
import os

# 确保目标目录存在
fig_dir = '../fig'
os.makedirs(fig_dir, exist_ok=True)

# 基础数据定义 (严禁更改字符串单引号约定)
scales = [128, 256, 512, 1024, 2048, 4096]
datasets = ['hg38', 'Bitcoin', 'COVID-19']
colors = ['#d62728', '#1f77b4', '#2ca02c'] # 对应红、蓝、绿
markers = ['o', 's', '^']

# (a) 加密总耗时数据 (ms) - 来自日志切面
time_enc_hg38 = [35920, 18108, 9292, 4593, 2285, 1239]
time_enc_bitcoin = [1219, 671, 408, 290, 149, 152]
time_enc_covid19 = [418, 286, 154, 150, 150, 144]

# (b) 插入 100 次操作耗时数据 (ms)
time_ins_hg38 = [12718, 12613, 12951, 12708, 12804, 12609]
time_ins_bitcoin = [12650, 12705, 12558, 12667, 12713, 12612]
time_ins_covid19 = [12662, 12578, 12621, 12760, 12803, 12627]

# (c) 删除 100 次操作耗时数据 (ms)
time_rmv_hg38 = [5673, 5531, 5438, 5410, 5354, 5325]
time_rmv_bitcoin = [5603, 5390, 5307, 5519, 5568, 5416]
time_rmv_covid19 = [5682, 5777, 5615, 5558, 5678, 5385]

# 初始化三联图布局，增加宽度以容纳柱状图的分组
fig, (ax1, ax2, ax3) = plt.subplots(1, 3, figsize=(18, 5))
plt.rcParams['font.family'] = 'serif' # 使用学术风格字体

# ==============================================================================
# 子图 (a) Encryption Scalability - 保持折线图 (Log-Log)
# ==============================================================================
ax1.plot(scales, time_enc_hg38, marker=markers[0], color=colors[0], label=datasets[0], linewidth=2, markersize=8)
ax1.plot(scales, time_enc_bitcoin, marker=markers[1], color=colors[1], label=datasets[1], linewidth=2, markersize=8)
ax1.plot(scales, time_enc_covid19, marker=markers[2], color=colors[2], label=datasets[2], linewidth=2, markersize=8)

# 设置 X 轴为对数坐标 (Base 2)
ax1.set_xscale('log', base=2)
# 设置 Y 轴为对数坐标 (Base 10)，以展示跨数量级的线性缩放关系
ax1.set_yscale('log', base=10)

# 显式设置 X 轴刻度，对应 Scales 数据点
ax1.set_xticks(scales)
ax1.set_xticklabels([str(s) for s in scales])

ax1.set_xlabel('Packing Scale (slots)', fontsize=12)
ax1.set_ylabel('Total Encryption Time (ms)', fontsize=12)
ax1.set_title('(a) Encryption Scalability', fontsize=14, fontweight='bold')
ax1.grid(True, which='both', linestyle=':', alpha=0.7)
ax1.legend(fontsize=11)

# ==============================================================================
# 为柱状图准备分组逻辑
# ==============================================================================
x_indices = np.arange(len(scales)) # X 轴类别的索引
group_width = 0.8 # 一组柱子的总相对宽度
bar_width = group_width / len(datasets) # 单个柱子的宽度

# 用于微调分组柱子位置的偏移量
offsets = [-bar_width, 0, bar_width]
# 增加舱底纹理以增强区分度 (可选，但建议)
hatches = ['//', '..', '\\\\']

# ==============================================================================
# 子图 (b) Insertion Scalability - 修改为分组柱状图
# ==============================================================================
# 按数据集循环绘制柱子
ins_rects_hg38 = ax2.bar(x_indices + offsets[0], time_ins_hg38, bar_width, color=colors[0], label=datasets[0], edgecolor='black', hatch=hatches[0], alpha=0.9)
ins_rects_bitcoin = ax2.bar(x_indices + offsets[1], time_ins_bitcoin, bar_width, color=colors[1], label=datasets[1], edgecolor='black', hatch=hatches[1], alpha=0.9)
ins_rects_covid19 = ax2.bar(x_indices + offsets[2], time_ins_covid19, bar_width, color=colors[2], label=datasets[2], edgecolor='black', hatch=hatches[2], alpha=0.9)

ax2.set_ylabel('Insertion Time for 100 ops (ms)', fontsize=12)
ax2.set_title('(b) Insertion Performance', fontsize=14, fontweight='bold')

# 设置 X 轴类别标签
ax2.set_xticks(x_indices)
ax2.set_xticklabels([str(s) for s in scales])
ax2.set_xlabel('Packing Scale (slots)', fontsize=12)

# Y 轴线性刻度，设置合适上限以突出平稳性
ax2.set_ylim(0, 16000)
# 仅开启 Y 轴网格线
ax2.grid(axis='y', linestyle='--', alpha=0.5)
# 将图例放在左上角，避免遮挡柱子
ax2.legend(fontsize=11, loc='upper left')

# ==============================================================================
# 子图 (c) Deletion Scalability - 修改为分组柱状图
# ==============================================================================
# 按数据集循环绘制柱子
rmv_rects_hg38 = ax3.bar(x_indices + offsets[0], time_rmv_hg38, bar_width, color=colors[0], label=datasets[0], edgecolor='black', hatch=hatches[0], alpha=0.9)
rmv_rects_bitcoin = ax3.bar(x_indices + offsets[1], time_rmv_bitcoin, bar_width, color=colors[1], label=datasets[1], edgecolor='black', hatch=hatches[1], alpha=0.9)
rmv_rects_covid19 = ax3.bar(x_indices + offsets[2], time_rmv_covid19, bar_width, color=colors[2], label=datasets[2], edgecolor='black', hatch=hatches[2], alpha=0.9)

ax3.set_ylabel('Deletion Time for 100 ops (ms)', fontsize=12)
ax3.set_title('(c) Deletion Performance', fontsize=14, fontweight='bold')

# 设置 X 轴类别标签
ax3.set_xticks(x_indices)
ax3.set_xticklabels([str(s) for s in scales])
ax3.set_xlabel('Packing Scale (slots)', fontsize=12)

# Y 轴线性刻度，上限设置合适
ax3.set_ylim(0, 8000)
# 仅开启 Y 轴网格线
ax3.grid(axis='y', linestyle='--', alpha=0.5)
# 图例左上角
ax3.legend(fontsize=11, loc='upper left')

# ==============================================================================
# 最终排版与保存
# ==============================================================================
plt.tight_layout()

# 指定输出路径，严禁更改文件名约定
output_path = os.path.join(fig_dir, 'eval_scalability.pdf')
plt.savefig(output_path, format='pdf', bbox_inches='tight')
plt.close() # 显式关闭图形对象以释放内存

print('Grouped bar and log-line scalability plot saved to: ' + output_path)