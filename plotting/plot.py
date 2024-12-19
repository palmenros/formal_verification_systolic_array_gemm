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
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(8, 5))

    # Colors for consistent styling
    time_color = '#1f77b4'  # Blue
    memory_color = '#ff7f0e'  # Orange

    # --- CPU Time Comparison (Left Plot) ---
    ax1.set_title('CPU Time')
    ax1.set_xlabel('Systolic Array Size')
    ax1.set_ylabel('CPU Time (minutes)')

    # Plot BMC time
    bmc_sizes = [r.sa_size for r in bmc_results]
    bmc_times = [r.time_seconds / 60.0 for r in bmc_results]
    ax1.plot(bmc_sizes, bmc_times, color=time_color, marker='o',
             label='BMC', linestyle='-')

    # Plot prove time
    prove_sizes = [r.sa_size for r in prove_results]
    prove_times = [r.time_seconds / 60.0 for r in prove_results]
    ax1.plot(prove_sizes, prove_times, color=time_color, marker='s',
             label='Prove', linestyle='--')

    ax1.grid(True, alpha=0.3)
    ax1.legend()

    # --- Memory Usage Comparison (Right Plot) ---
    ax2.set_title('Memory Usage')
    ax2.set_xlabel('Systolic Array Size')
    ax2.set_ylabel('Memory Usage (GB)')

    # Plot BMC memory
    bmc_memory = [r.memory_megabytes / 1024.0 for r in bmc_results]
    ax2.plot(bmc_sizes, bmc_memory, color=memory_color, marker='o',
             label='BMC', linestyle='-')

    # Plot prove memory
    prove_memory = [r.memory_megabytes / 1024.0 for r in prove_results]
    ax2.plot(prove_sizes, prove_memory, color=memory_color, marker='s',
             label='Prove', linestyle='--')

    ax2.grid(True, alpha=0.3)
    ax2.legend()

    # Add overall title
    fig.suptitle(f'BMC vs Prove Performance Comparison for {results[0].config.short_name}', weight='bold')

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

# Convert the results.txt file to a CSV
# convert_manual_results_txt_to_csv(RESULTS_DIR.parent / 'results.txt', 'FV_GEMM_Fixed_Weights_Each_Cycle')

CONFIG_NAMES = [
    Config('FV_GEMM_Fixed_Weights_Each_Cycle', 'Interface 1')
]

for cfg in CONFIG_NAMES:
    res = load_results(cfg)
    print_benchmark_summary(cfg, res)

    for mode in ['bmc', 'live', 'prove']:
        plot_performance_metrics(res, mode=mode)
    plot_bmc_prove_mode_comparison(res)