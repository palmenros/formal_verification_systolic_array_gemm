from string import Template
from pathlib import Path
import os
import argparse
import subprocess
import time
import json
from datetime import datetime
import psutil
import signal

def get_process_tree_memory(pid):
    """Get total memory usage of a process and all its children in MB"""
    try:
        parent = psutil.Process(pid)
        children = parent.children(recursive=True)  # Get all child processes recursively
        total_memory = parent.memory_info().rss  # Memory of parent process
        
        # Add memory of all child processes
        for child in children:
            try:
                total_memory += child.memory_info().rss
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
                
        return total_memory / (1024 * 1024)  # Convert to MB
    except (psutil.NoSuchProcess, psutil.AccessDenied):
        return 0.0
    
def kill_process_tree(pid):
    """Kill a process and all its children"""
    try:
        parent = psutil.Process(pid)
        children = parent.children(recursive=True)
        
        # Kill children first
        for child in children:
            try:
                os.kill(child.pid, signal.SIGTERM)
            except (psutil.NoSuchProcess, ProcessLookupError):
                pass
                
        # Kill parent
        os.kill(pid, signal.SIGTERM)
    except (psutil.NoSuchProcess, ProcessLookupError):
        pass

def run_single_benchmark(tag, interface_sby_filename_without_extension, sby_command, SA_SIZE, maximum_memory_limit_in_megabytes):
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
    
    config_name = f'gen_{interface_sby_filename_without_extension}_sa_size_{SA_SIZE}_prove_depth_{PROVE_DEPTH}_bmc_depth_{BMC_DEPTH}_tag_{tag}'

    RES_FILE = SCRIPT_DIR / f'{config_name}.sby'
    RES_FILE.write_text(res)

    bash_command = f'sby --prefix symbiyosys_{interface_sby_filename_without_extension} -f {RES_FILE} {sby_command}'

    start_time = time.perf_counter()
    max_memory = 0

    try:
        process = subprocess.Popen(
            bash_command,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

        memory_limit_exceeded = False

        # Poll process memory usage
        while process.poll() is None:  # While process is running
            current_memory = get_process_tree_memory(process.pid)
            max_memory = max(max_memory, current_memory)
            
            if current_memory > maximum_memory_limit_in_megabytes:
                out_of_memory_message = f'Memory limit of {maximum_memory_limit_in_megabytes}MB exceeded! (Current: {current_memory:.2f}MB). Killing process...'
                print(out_of_memory_message)
                kill_process_tree(process.pid)
                memory_limit_exceeded  = True
            
            time.sleep(0.1)  # Poll every 100ms
                
        # Get the output
        stdout, stderr = process.communicate()
        success = process.returncode == 0        
        output = stdout + '\n' + stderr

        if memory_limit_exceeded:
            output += '\n' + out_of_memory_message

    except Exception as e:
        success = False
        output = str(e)

    elapsed_time = time.perf_counter() - start_time

    if success:
        print(f'SUCCESS: {sby_command} {config_name} in {elapsed_time:.3f} seconds using {max_memory:.2f} MB')
    else:
        print(f'ERROR: {sby_command} {config_name}' + ' (Memory limit exceeded)' if memory_limit_exceeded else '')

    date_time_str = time.strftime("%Y_%m_%d_%H.%M.%S")
    
    raw_log_dir = SCRIPT_DIR / 'benchmark_output' / 'raw_logs'
    os.makedirs(raw_log_dir, exist_ok=True)
    raw_log_file = raw_log_dir / f'{config_name}_{date_time_str}.txt'
    raw_log_file.write_text(output)

    benchmark_data = {
        'timestamp': datetime.now().isoformat(),
        'command': bash_command,
        'execution_time': elapsed_time,
        'success': success,
        'output': str(raw_log_file.relative_to(SCRIPT_DIR)),
        'time_units': 'seconds (s)',
        'memory': max_memory,
        'memory_units': 'megabyte (MB)',
        'SA_SIZE': SA_SIZE,
        'cmd': sby_command,
        'tag': tag,
        'interface_sby_filename': interface_sby_filename_without_extension,
        'memory_limit_exceeded': memory_limit_exceeded
    }
    
    bench_file_dir = SCRIPT_DIR / 'benchmark_output' / 'bench_data'
    os.makedirs(bench_file_dir, exist_ok=True)
    bench_file = bench_file_dir / f'{config_name}_{date_time_str}.txt'
    
    with open(bench_file, 'w') as f:
        json.dump(benchmark_data, f, indent=4, sort_keys=True)

    with open(SCRIPT_DIR / 'benchmark_output' / f'all_run_benchmarks_{interface_sby_filename_without_extension}.csv', 'a') as f:
        f.write(f'{interface_sby_filename_without_extension},{SA_SIZE},{sby_command},{tag},{bench_file}\n')

FIXED_WEIGHTS_EACH_CYCLE_INTERFACE = 'FV_GEMM_Fixed_Weights_Each_Cycle_driver'

INTERFACES = [
    'FV_GEMM_Fixed_Weights_Each_Cycle_driver',
    'FV_GEMM_Fixed_Weights_driver',
    'FV_GEMM_driver',
    ]

for f in os.listdir(os.path.dirname(os.path.realpath(__file__))):
    if f.endswith('.sby.tpl'):
        interface_name = f.removesuffix('.sby.tpl')
        if interface_name not in INTERFACES:
            INTERFACES.append(interface_name)

""" PROVE_CMD = 'prove'
LIVE_CMD = 'live'
BMC_CMD = 'bmc' """

DEFAULT_TAG = 'default'

# Set the memory limit to 16 GiB
MAXIMUM_MEMORY_LIMIT_MEGABYTES = 16 * 1024

command_choices = ['bmc', 'prove', 'cover', 'live']

parser = argparse.ArgumentParser(description='Run formal verification benchmarks.')
parser.add_argument('--help-interfaces', action='store_true', help='Print the available interfaces for the benchmark.')
parser.add_argument('--interface', '-i', type=int, help='Interface type for the benchmark.')
parser.add_argument('--command', '-c', choices=command_choices, type=str, help='Command to run for the benchmark')
parser.add_argument('--tag', '-t', type=str, help='Tag for the benchmark run')

args = parser.parse_args()

if args.help_interfaces:
    print('Available interfaces:')
    for i, interface in enumerate(INTERFACES):
        print(f'\t{i}: {interface}')
    exit()
elif None in (args.interface, args.command, args.tag):
    parser.error('the following arguments are required: --interface, --command, --tag')

for size in [2, 4, 8, 16, 32]:
    run_single_benchmark(args.tag, INTERFACES[args.interface], args.command, size, MAXIMUM_MEMORY_LIMIT_MEGABYTES)