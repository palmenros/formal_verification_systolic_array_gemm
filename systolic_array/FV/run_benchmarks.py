from string import Template
from pathlib import Path
import os
import argparse
import subprocess
import time
import json
from datetime import datetime

def run_single_benchmark(tag, interface_sby_filename_without_extension, sby_command, SA_SIZE):
    PROVE_DEPTH = 2*(SA_SIZE + 1)
    BMC_EXPAND = 10
    BMC_DEPTH = 2*SA_SIZE + BMC_EXPAND

    SCRIPT_DIR = Path(os.path.dirname(os.path.realpath(__file__)))
    sby_template = (SCRIPT_DIR / f'{interface_sby_filename_without_extension}.sby.tpl').read_text()

    res = Template(sby_template).substitute(
        PROVE_DEPTH=PROVE_DEPTH,
        BMC_DEPTH=BMC_DEPTH,
        SA_SIZE=SA_SIZE
    )
    
    config_name = f'gen_fv_gemm_fixed_weights_each_cycle_driver_sa_size_{SA_SIZE}_prove_depth_{PROVE_DEPTH}_bmc_depth_{BMC_DEPTH}_tag_{tag}'

    RES_FILE = SCRIPT_DIR / f'{config_name}.sby'
    RES_FILE.write_text(res)

    bash_command = f'sby --prefix symbiyosys_{interface_sby_filename_without_extension} -f {RES_FILE} {sby_command}'

    start_time = time.perf_counter()

    try:
        process = subprocess.run(
            bash_command,
            shell=True,
            capture_output=True,
            text=True,
            check=True  # This will raise an exception if the command fails
        )
        success = True
        output = process.stdout
    except subprocess.CalledProcessError as e:
        success = False
        output = e.stderr

    elapsed_time = time.perf_counter() - start_time

    if success:
        print(f'SUCCESS: {config_name} in {elapsed_time:.3f} seconds')
    else:
        print(f'ERROR: {config_name}')

    date_time_str = time.strftime("%Y_%m_%d_%H.%M.%S")

    raw_log_file = SCRIPT_DIR / 'benchmark_output' / 'raw_logs' / f'{config_name}_{date_time_str}.txt'
    raw_log_file.write_text(output)

    benchmark_data = {
        'timestamp': datetime.now().isoformat(),
        'command': bash_command,
        'execution_time': elapsed_time,
        'success': success,
        'output': str(raw_log_file.relative_to(SCRIPT_DIR)),
        'units': 'seconds',
        'SA_SIZE': SA_SIZE,
        'cmd': sby_command,
        'tag': tag,
        'interface_sby_filename': interface_sby_filename_without_extension
    }

    bench_file = SCRIPT_DIR / 'benchmark_output' / 'bench_data' / f'{config_name}_{date_time_str}.txt'
    
    with open(bench_file, 'w') as f:
        json.dump(benchmark_data, f, indent=4, sort_keys=True)

    with open(SCRIPT_DIR / 'benchmark_output' / f'all_run_benchmarks_{interface_sby_filename_without_extension}.csv', 'a') as f:
        f.write(f'{interface_sby_filename_without_extension},{SA_SIZE},{sby_command},{tag},{bench_file}\n')

FIXED_WEIGHTS_EACH_CYCLE_INTERFACE = 'FV_GEMM_Fixed_Weights_Each_Cycle_driver'

INTERFACES = ['FV_GEMM_Fixed_Weights_Each_Cycle_driver', 'FV_GEMM_Fixed_Weights_driver', 'FV_GEMM_driver']

""" PROVE_CMD = 'prove'
LIVE_CMD = 'live'
BMC_CMD = 'bmc' """

DEFAULT_TAG = 'default'

parser = argparse.ArgumentParser(description='Run formal verification benchmarks.')
parser.add_argument('--interface', type=int, required=True, help='Interface type for the benchmark')
parser.add_argument('--command', type=str, required=True, help='Command to run for the benchmark')
parser.add_argument('--tag', type=str, required=True, help='Tag for the benchmark run')

args = parser.parse_args()

for size in [64]:
    run_single_benchmark(args.tag, INTERFACES[args.interface], args.command, size)