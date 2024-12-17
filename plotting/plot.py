from matplotlib import pyplot as plt
from pathlib import Path
from dataclasses import dataclass
import pprint
import csv
import re

RESULTS_DIR = Path(__file__).parent.parent / 'systolic_array' / 'FV' / 'benchmark_output'

@dataclass
class BenchResults:
    config_name: str
    sa_size: int
    time_seconds: float
    memory_megabytes: float


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

def convert_manual_results_txt_to_csv(results_file_path, cfg_name):
    with open(results_file_path, 'r') as f:
        lines = f.readlines()

    results = []
    for line in lines:
        result = parse_result_line(line.strip(), cfg_name)
        if result:
            results.append(result)

    csv_output_file = RESULTS_DIR / f'all_run_benchmarks_{cfg_name}_driver.csv'

    with open(csv_output_file, 'w') as f:
        for row in results:
            f.write(','.join(str(x) for x in row) + '\n')

    print(f'Written results to {csv_output_file}')

def load_results(config_name: str) -> [BenchResults]:
    results = []
    csv_path = RESULTS_DIR / f'all_run_benchmarks_{config_name}.csv'

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
            assert config_name == row[0]

            sa_size = int(row[1])
            time_seconds = float(row[4])
            memory_megabytes = float(row[5])

            result = BenchResults(
                config_name=config_name,
                sa_size=sa_size,
                time_seconds=time_seconds,
                memory_megabytes=memory_megabytes
            )
            results.append(result)
    return results

# Convert the results.txt file to a CSV
# convert_manual_results_txt_to_csv(RESULTS_DIR.parent / 'results.txt', 'FV_GEMM_Fixed_Weights_Each_Cycle')

CONFIG_NAMES = ['FV_GEMM_FWEC_driver_verif1']

for cfg in CONFIG_NAMES:
    res = load_results(cfg)
    print(f'Config "{cfg}" has {len(res)} results:')
    pprint.pprint(res)
