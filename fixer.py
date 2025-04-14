
import ctypes, os, subprocess, sys, winreg, time

SCRIPT_NAME = "error43-fixer"
NV_KEY = "RM1774520"
NV_KEY_DATA = 0x1
NV_KEY_TYPE = winreg.REG_DWORD

def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False

def elevate():
    script = os.path.abspath(sys.argv[0])
    params = " ".join([f'"{arg}"' for arg in sys.argv[1:]])
    ctypes.windll.shell32.ShellExecuteW(None, "runas", sys.executable, f'"{script}" {params}', None, 1)
    sys.exit()

def query_registry_keys():
    gpu_keys = []
    base_path = r"SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
    try:
        with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, base_path) as key:
            i = 0
            while True:
                try:
                    subkey_name = winreg.EnumKey(key, i)
                    subkey_path = f"{base_path}\\{subkey_name}"
                    with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, subkey_path) as subkey:
                        try:
                            driver_desc, _ = winreg.QueryValueEx(subkey, "DriverDesc")
                            if "nvidia" in driver_desc.lower():
                                gpu_keys.append(subkey_path)
                        except FileNotFoundError:
                            pass
                    i += 1
                except OSError:
                    break
    except Exception as e:
        print("Registry access failed:", e)
    return gpu_keys

def read_registry_value(key_path, value_name):
    try:
        with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, key_path) as key:
            value, val_type = winreg.QueryValueEx(key, value_name)
            return value
    except FileNotFoundError:
        return None

def write_registry_value(key_path, name, value, value_type):
    try:
        with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, key_path, 0, winreg.KEY_WRITE) as key:
            winreg.SetValueEx(key, name, 0, value_type, value)
        return True
    except Exception as e:
        print("Failed to write registry:", e)
        return False

def get_hw_id(dev_key):
    try:
        output = subprocess.check_output(['reg', 'query', dev_key, '/v', 'MatchingDeviceId'], text=True)
        return output.strip().split()[-1]
    except:
        return None

def get_driver_desc(dev_key):
    try:
        output = subprocess.check_output(['reg', 'query', dev_key, '/v', 'DriverDesc'], text=True)
        return " ".join(output.strip().split()[2:])
    except:
        return "Unknown"

def check_error43(hw_id):
    try:
        output = subprocess.check_output(['devset', 'status', hw_id], text=True)
        return "code 43" in output.lower()
    except:
        return False

def restart_gpu(hw_id):
    subprocess.call(['devset', 'restart', hw_id])
    time.sleep(2)
    try:
        output = subprocess.check_output(['devset', 'status', hw_id], text=True)
        return "Driver is running." in output
    except:
        return False

def patch_nv_adapter(dev_key):
    hw_id = get_hw_id(dev_key)
    adapter_name = get_driver_desc(dev_key)

    if not check_error43(hw_id):
        return False, False

    current_val = read_registry_value(dev_key, NV_KEY)
    if current_val == NV_KEY_DATA:
        print(f"[{adapter_name}] is already registry patched but still has error code 43.")
        return True, False

    print(f"[{adapter_name}] has error code 43. Applying registry patch...")
    success = write_registry_value(dev_key, NV_KEY, NV_KEY_DATA, NV_KEY_TYPE)
    if not success:
        print(f"[{adapter_name}] ERROR. Registry patch failed. Please manually add in regedit:")
        print(f"Key: {dev_key}")
        print(f"Data: {NV_KEY} = {NV_KEY_DATA} (REG_DWORD)")
        return False, False

    print(f"[{adapter_name}] restarting adapter...")
    if restart_gpu(hw_id):
        print(f"[{adapter_name}] is fixed. Driver is running.")
        return True, True
    else:
        print(f"[{adapter_name}] still has a problem after patch.")
        return True, False

def main():
    if not is_admin():
        print("Requesting administrative privileges...")
        elevate()

    print(f"\n=== {SCRIPT_NAME} ===\n")
    adapters = query_registry_keys()
    if not adapters:
        print("No Nvidia GPUs found. Please attach one and ensure its driver is installed.")
        input("Press any key to exit...")
        return

    patched_any = False
    fixed_any = False

    for dev_key in adapters:
        patched, fixed = patch_nv_adapter(dev_key)
        patched_any |= patched
        fixed_any |= fixed

    if patched_any:
        print("\nRegistry changes have been made.\n")
        print("  1. RE-RUN this script if you delete or reinstall this GPU & error code 43 reappears.")
        print("  2. To UNDO this change, uninstall the adapter in Device Manager -> Display adapters & restart.")
    elif not fixed_any:
        print("No Nvidia GPUs in error code 43 state found. Nothing to do.")

    input("\nPress any key to exit...")

if __name__ == "__main__":
    main()
