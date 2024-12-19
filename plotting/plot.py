from matplotlib import pyplot as plt
from pathlib import Path
from dataclasses import dataclass
import pprint
import csv
import re

RESULTS_DIR = Path(__file__).parent.parent / 'systolic_array' / 'FV' / 'benchmark_output'

# Set global font sizes
plt.rcParams.update({
    'font.size': 12,
    'axes.titlesize': 14,
    'axes.labelsize': 12,
    'xtick.labelsize': 11,
    'ytick.labelsize': 11,
    'legend.fontsize': 11,
    'figure.titlesize': 16
})

DOUBLE_PLOT_FIG_SIZE = (8, 4.5)

@dataclass
class Config:
    full_config_name: str
    short_name: str

@dataclass
class BenchResults:
    config: Config
    sa_size: int
    time_seconds: float
    memory_megabytes: float
    mode: str                  # in ['bmc', 'prove', 'live']
    success: bool

def parse_result_line(line, cfg_name):
    # Regular expression to match the line format
    pattern = r'(SUCCESS|ERROR): (\w+) (gen_' + cfg_name + r'_driver_sa_size_(\d+)_prove_depth_(\d+)_bmc_depth_(\d+)_tag_default)(?:\s+in\s+([\d.]+)\s+seconds\s+using\s+([\d.]+)\s+MB)?(?:\s+\((.*?)\))?'

    match = re.match(pattern, line)
    if not match:
        return None

    status, mode, full_name, sa_size, prove_depth, bmc_depth, time, memory, error = match.groups()

    # For error cases, set time and memory to -1
    time = float(time) if time else -1
    memory = float(memory) if memory else -1

    return [
        cfg_name,  # config name
        int(sa_size),  # sa_size
        mode,  # mode (bmc/prove/live)
        "default",  # tag
        time,  # time in seconds
        memory,  # memory in MB
        1 if status == "SUCCESS" else 0,  # success flag
        full_name  # full path
    ]

def convert_manual_results_txt_to_csv(results_file_path, cfg: Config):
    with open(results_file_path, 'r') as f:
        lines = f.readlines()

    results = []
    for line in lines:
        result = parse_result_line(line.strip(), cfg.full_config_name)
        if result:
            results.append(result)

    csv_output_file = RESULTS_DIR / f'all_run_benchmarks_{cfg.full_config_name}_driver.csv'

    with open(csv_output_file, 'w') as f:
        for row in results:
            f.write(','.join(str(x) for x in row) + '\n')

    print(f'Written results to {csv_output_file}')

def load_results(config: Config) -> [BenchResults]:
    results = []
    csv_path = RESULTS_DIR / f'all_run_benchmarks_{config.full_config_name}.csv'

    with open(csv_path, 'r') as f:
        for row in csv.reader(f):
            # CSV structure:
            # [0]: config_name
            # [1]: sa_size
            # [2]: bmc/prove/live
            # [3]: tag: default
            # [4]: time_seconds
            # [5]: memory_megabytes
            # [6]: success
            # [7]: log_path
            assert config.full_config_name == row[0]

            sa_size = int(row[1])
            time_seconds = float(row[4])
            memory_megabytes = float(row[5])
            mode = row[2]
            assert mode in ['bmc', 'live', 'prove']
            assert int(row[6]) in [0, 1]
            success = bool(int(row[6]))

            result = BenchResults(
                config=config,
                sa_size=sa_size,
                time_seconds=time_seconds,
                memory_megabytes=memory_megabytes,
                mode=mode,
                success=success
            )
            results.append(result)
    return results


def plot_performance_metrics(results: [BenchResults], mode: str = None, output_path: Path = None):
    """
    Plot memory (in GB) and CPU consumption (in minutes) for given benchmark results.
    Only shows successful results for the specified mode.

    Args:
        results: List of BenchResults objects
        mode: One of ['bmc', 'live', 'prove']. If None, shows all modes
        output_path: Optional path to save the plot
    """
    # Filter for successful results and specified mode
    filtered_results = [r for r in results if r.success]
    if mode:
        if mode not in ['bmc', 'live', 'prove']:
            raise ValueError(f"Invalid mode: {mode}. Must be one of: bmc, live, prove")
        filtered_results = [r for r in filtered_results if r.mode == mode]

    if not filtered_results:
        print(f"No successful results found{'for mode ' + mode if mode else ''}")
        return

    # Sort results by SA size for proper line plotting
    sorted_results = sorted(filtered_results, key=lambda x: x.sa_size)

    # Extract data for plotting
    sa_sizes = [r.sa_size for r in sorted_results]
    # Convert seconds to minutes
    times = [r.time_seconds / 60.0 for r in sorted_results]
    # Convert MB to GB
    memories = [r.memory_megabytes / 1024.0 for r in sorted_results]

    # Create figure and primary y-axis
    fig, ax1 = plt.subplots(figsize=(5, 4))

    # Plot CPU time on primary y-axis
    color1 = '#1f77b4'  # Blue
    ax1.set_xlabel('Systolic Array Size')
    ax1.set_ylabel('CPU Time (minutes)', color=color1)
    line1 = ax1.plot(sa_sizes, times, color=color1, marker='o', label='CPU Time')
    ax1.tick_params(axis='y', labelcolor=color1)

    # Create secondary y-axis and plot memory
    ax2 = ax1.twinx()
    color2 = '#ff7f0e'  # Orange
    ax2.set_ylabel('Memory Usage (GB)', color=color2)
    line2 = ax2.plot(sa_sizes, memories, color=color2, marker='s', label='Memory Usage')
    ax2.tick_params(axis='y', labelcolor=color2)

    # Add title and grid
    mode_str = f" ({mode})" if mode else "(all modes)"
    plt.title(f'Performance Metrics for {sorted_results[0].config.short_name}{mode_str}')
    ax1.grid(True, alpha=0.3)

    # Combine legends from both axes
    lines = line1 + line2
    labels = [l.get_label() for l in lines]
    ax1.legend(lines, labels, loc='upper left')

    # Adjust layout to prevent label cutoff
    plt.tight_layout()

    # Save plot if output path is provided
    if output_path:
        plt.savefig(output_path)
        print(f"Plot saved to {output_path}")

    # Show plot
    plt.show()


def plot_bmc_prove_mode_comparison(results: [BenchResults], output_path: Path = None):
    """
    Creates a side-by-side comparison of BMC vs prove performance metrics.
    Shows both memory usage and CPU time for successful results only.
    Uses different colors to distinguish BMC and prove modes.

    Args:
        results: List of BenchResults objects
        output_path: Optional path to save the plot
    """
    # Filter successful results and separate by mode
    bmc_results = sorted([r for r in results if r.success and r.mode == 'bmc'],
                         key=lambda x: x.sa_size)
    prove_results = sorted([r for r in results if r.success and r.mode == 'prove'],
                           key=lambda x: x.sa_size)

    if not bmc_results or not prove_results:
        print("Insufficient data: Need both BMC and prove results for comparison")
        return

    # Create figure with two subplots side by side
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=DOUBLE_PLOT_FIG_SIZE)

    # Colors for BMC and prove modes
    bmc_color = '#1f77b4'    # Blue
    prove_color = '#ff7f0e'  # Orange

    # --- CPU Time Comparison (Left Plot) ---
    ax1.set_title('CPU Time')
    ax1.set_xlabel('Systolic Array Size')
    ax1.set_ylabel('CPU Time (minutes)')

    # Plot BMC and prove times with different colors
    bmc_sizes = [r.sa_size for r in bmc_results]
    bmc_times = [r.time_seconds / 60.0 for r in bmc_results]
    ax1.plot(bmc_sizes, bmc_times, color=bmc_color, marker='o',
             label='BMC', linestyle='-')

    prove_sizes = [r.sa_size for r in prove_results]
    prove_times = [r.time_seconds / 60.0 for r in prove_results]
    ax1.plot(prove_sizes, prove_times, color=prove_color, marker='s',
             label='Prove', linestyle='-')

    ax1.grid(True, alpha=0.3)
    ax1.legend()

    # --- Memory Usage Comparison (Right Plot) ---
    ax2.set_title('Memory Usage')
    ax2.set_xlabel('Systolic Array Size')
    ax2.set_ylabel('Memory Usage (GB)')

    # Plot BMC and prove memory with same colors as corresponding time plots
    bmc_memory = [r.memory_megabytes / 1024.0 for r in bmc_results]
    ax2.plot(bmc_sizes, bmc_memory, color=bmc_color, marker='o',
             label='BMC', linestyle='-')

    prove_memory = [r.memory_megabytes / 1024.0 for r in prove_results]
    ax2.plot(prove_sizes, prove_memory, color=prove_color, marker='s',
             label='Prove', linestyle='-')

    ax2.grid(True, alpha=0.3)
    ax2.legend()

    # Add overall title
    fig.suptitle(f'BMC vs Prove Performance Comparison for {results[0].config.short_name}',
                 weight='bold')

    # Adjust layout
    plt.tight_layout()

    # Save if output path provided
    if output_path:
        plt.savefig(output_path, bbox_inches='tight')
        print(f"Plot saved to {output_path}")

    plt.show()

def print_benchmark_summary(config: Config, results: [BenchResults]):
    """
    Prints a compact summary of benchmark results for each mode.
    Only shows successful runs with time in minutes and memory in GB.
    """
    # Print banner
    print()
    banner = f"=== Benchmark Results for {config.short_name} ==="
    print("=" * len(banner))
    print(banner)
    print("=" * len(banner))
    print()

    # Group results by mode
    for mode in ['live', 'bmc', 'prove']:
        # Filter successful results for this mode
        mode_results = [r for r in results if r.success and r.mode == mode]

        if not mode_results:
            continue

        # Sort by systolic array size
        mode_results.sort(key=lambda x: x.sa_size)

        print(f"{mode.upper()} MODE:")
        print(f"{'SA Size':>8} | {'Time (min)':>10} | {'Memory (GB)':>10}")
        print("-" * 35)

        for result in mode_results:
            time_min = result.time_seconds / 60.0
            mem_gb = result.memory_megabytes / 1024.0
            print(f"{result.sa_size:>8} | {time_min:>10.2f} | {mem_gb:>10.2f}")
        print()


def plot_config_comparison(config1_results: [BenchResults], config2_results: [BenchResults], mode='prove',
                           output_path: Path = None):
    """
    Creates side-by-side comparison plots of CPU time and memory usage between two configurations.
    Only shows successful results for the specified mode (defaults to 'prove').

    Args:
        config1_results: List of BenchResults for first configuration
        config2_results: List of BenchResults for second configuration (baseline)
        mode: Analysis mode to compare ('prove' by default)
        output_path: Optional path to save the plot
    """
    # Filter successful results for specified mode
    results1 = sorted([r for r in config1_results if r.success and r.mode == mode],
                      key=lambda x: x.sa_size)
    results2 = sorted([r for r in config2_results if r.success and r.mode == mode],
                      key=lambda x: x.sa_size)

    if not results1 or not results2:
        print(f"Insufficient data: Need results from both configurations for {mode} mode")
        return

    # Create figure with two subplots side by side
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=DOUBLE_PLOT_FIG_SIZE)

    # Colors for consistent styling
    config1_color = '#1f77b4'  # Blue
    config2_color = '#ff7f0e'  # Orange

    # --- CPU Time Comparison (Left Plot) ---
    ax1.set_title('CPU Time Comparison', fontsize=14, pad=10)
    ax1.set_xlabel('Systolic Array Size', fontsize=12)
    ax1.set_ylabel('CPU Time (minutes)', fontsize=12)

    # Plot config2 time
    sizes2 = [r.sa_size for r in results2]
    times2 = [r.time_seconds / 60.0 for r in results2]
    ax1.plot(sizes2, times2, color=config2_color, marker='s',
             label='Baseline', linestyle='--', linewidth=2)

    # Plot config1 time
    sizes1 = [r.sa_size for r in results1]
    times1 = [r.time_seconds / 60.0 for r in results1]
    ax1.plot(sizes1, times1, color=config1_color, marker='o',
             label=results1[0].config.short_name, linestyle='-', linewidth=2)

    ax1.grid(True, alpha=0.3)
    ax1.legend(fontsize=11)
    ax1.tick_params(labelsize=11)

    # --- Memory Usage Comparison (Right Plot) ---
    ax2.set_title('Memory Usage Comparison', fontsize=14, pad=10)
    ax2.set_xlabel('Systolic Array Size', fontsize=12)
    ax2.set_ylabel('Memory Usage (GB)', fontsize=12)

    # Plot config2 memory
    memory2 = [r.memory_megabytes / 1024.0 for r in results2]
    ax2.plot(sizes2, memory2, color=config2_color, marker='s',
             label='Baseline', linestyle='--', linewidth=2)

    # Plot config1 memory
    memory1 = [r.memory_megabytes / 1024.0 for r in results1]
    ax2.plot(sizes1, memory1, color=config1_color, marker='o',
             label=results1[0].config.short_name, linestyle='-', linewidth=2)

    ax2.grid(True, alpha=0.3)
    ax2.legend(fontsize=11)
    ax2.tick_params(labelsize=11)

    # Add overall title
    fig.suptitle(f'{results1[0].config.short_name} Comparison ({mode})',
                 fontsize=16, weight='bold')

    # Adjust layout
    plt.tight_layout()

    # Save if output path provided
    if output_path:
        plt.savefig(output_path, dpi=300, bbox_inches='tight')
        print(f"Plot saved to {output_path}")

    plt.show()


def plot_multi_config_comparison(configs_results: [[BenchResults]], baseline_results: [BenchResults],
                                 mode='prove', output_path: Path = None):
    """
    Creates side-by-side comparison plots of CPU time and memory usage between multiple configurations
    and a baseline. Only shows successful results for the specified mode.

    Args:
        configs_results: List of lists of BenchResults for each configuration to compare
        baseline_results: List of BenchResults for baseline configuration
        mode: Analysis mode to compare ('prove' by default)
        output_path: Optional path to save the plot
    """
    # Filter successful results for specified mode for baseline
    baseline = sorted([r for r in baseline_results if r.success and r.mode == mode],
                      key=lambda x: x.sa_size)

    # Filter successful results for specified mode for each config
    configs = []
    for config_results in configs_results:
        filtered = sorted([r for r in config_results if r.success and r.mode == mode],
                          key=lambda x: x.sa_size)
        if filtered:
            configs.append(filtered)

    if not baseline or not configs:
        print(f"Insufficient data: Need baseline and at least one config results for {mode} mode")
        return

    # Create figure with two subplots side by side
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=DOUBLE_PLOT_FIG_SIZE)

    # Color palette for configurations (excluding baseline color)
    # Using colorblind-friendly palette
    config_colors = ['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd', '#8c564b']
    baseline_color = '#7f7f7f'  # Gray for baseline

    # --- CPU Time Comparison (Left Plot) ---
    ax1.set_title('CPU Time Comparison', fontsize=14, pad=10)
    ax1.set_xlabel('Systolic Array Size', fontsize=12)
    ax1.set_ylabel('CPU Time (minutes)', fontsize=12)

    # Plot baseline time
    baseline_sizes = [r.sa_size for r in baseline]
    baseline_times = [r.time_seconds / 60.0 for r in baseline]
    ax1.plot(baseline_sizes, baseline_times, color=baseline_color, marker='s',
             label='Baseline', linestyle='--', linewidth=2)

    # Plot each config's time
    for idx, config in enumerate(configs):
        sizes = [r.sa_size for r in config]
        times = [r.time_seconds / 60.0 for r in config]
        ax1.plot(sizes, times, color=config_colors[idx % len(config_colors)],
                 marker='o', label=config[0].config.short_name, linewidth=2)

    ax1.grid(True, alpha=0.3)
    ax1.legend(fontsize=10, loc='upper left')
    ax1.tick_params(labelsize=11)

    # --- Memory Usage Comparison (Right Plot) ---
    ax2.set_title('Memory Usage Comparison', fontsize=14, pad=10)
    ax2.set_xlabel('Systolic Array Size', fontsize=12)
    ax2.set_ylabel('Memory Usage (GB)', fontsize=12)

    # Plot baseline memory
    baseline_memory = [r.memory_megabytes / 1024.0 for r in baseline]
    ax2.plot(baseline_sizes, baseline_memory, color=baseline_color, marker='s',
             label='Baseline', linestyle='--', linewidth=2)

    # Plot each config's memory
    for idx, config in enumerate(configs):
        sizes = [r.sa_size for r in config]
        memory = [r.memory_megabytes / 1024.0 for r in config]
        ax2.plot(sizes, memory, color=config_colors[idx % len(config_colors)],
                 marker='o', label=config[0].config.short_name, linewidth=2)

    ax2.grid(True, alpha=0.3)
    ax2.legend(fontsize=10, loc='upper left')
    ax2.tick_params(labelsize=11)

    # Add overall title
    fig.suptitle(f'Multi-Configuration Comparison ({mode})',
                 fontsize=16, weight='bold')

    # Adjust layout
    plt.tight_layout()

    # Save if output path provided
    if output_path:
        plt.savefig(output_path, dpi=300, bbox_inches='tight')
        print(f"Plot saved to {output_path}")

    plt.show()


# Example usage:
# config1_results = load_results(CONFIG_NAMES[0])
# config2_results = load_results(CONFIG_NAMES[1])
# plot_config_comparison(config1_results, config2_results, mode='prove')

# Convert the results.txt file to a CSV
# convert_manual_results_txt_to_csv(RESULTS_DIR.parent / 'results.txt', 'FV_GEMM_Fixed_Weights_Each_Cycle')

INTERFACE_CONFIGS = [
    Config('FV_GEMM_Fixed_Weights_Each_Cycle', 'Interface 1'),
    Config('FV_GEMM_Fixed_Weights_driver', 'Interface 2'),
    Config('FV_GEMM_driver', 'Interface 3')
]


VERIF_CONFIGS = [
    Config('FV_GEMM_FWEC_driver_verif1', 'Verif 1'),
    Config('FV_GEMM_FWEC_driver_verif2', 'Verif 2'),
    Config('FV_GEMM_FWEC_driver_verif3', 'Verif 3'),
    Config('FV_GEMM_FWEC_driver_verif4', 'Verif 4'),
]

#########################################
# PLOT BMC VS PROOF FOR INTERFACE 1
#########################################

interface1_cfg = INTERFACE_CONFIGS[0]
interface1_res = load_results(interface1_cfg)

print_benchmark_summary(interface1_cfg, interface1_res)
plot_bmc_prove_mode_comparison(interface1_res)

#########################################
# PLOT COMPARISON OF OTHER INTERFACES
#########################################

for cfg in INTERFACE_CONFIGS[1:]:
    res = load_results(cfg)
    print_benchmark_summary(cfg, res)
    plot_config_comparison(res, interface1_res, mode='bmc')

#########################################
# PLOT ADDITIONAL ASSERTIONS COMPARISON
#########################################

interface1_cfg = INTERFACE_CONFIGS[0]
interface1_res = load_results(interface1_cfg)

comparison_res = []

for cfg in VERIF_CONFIGS:
    res = load_results(cfg)
    plot_config_comparison(res, interface1_res, mode='prove')
    print_benchmark_summary(cfg, res)
    comparison_res.append(res)

plot_multi_config_comparison(comparison_res, interface1_res)