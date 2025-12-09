# --- SCRIPT METADATA (FOR REAPACK/DOCUMENTATION) ---
# @description    Matchering 2.0 Worker (Python Subprocess)
# @author         Hosi
# @version        1.0
# @reaper_version 6.12+ (Requires `reaper_python` environment)
# @extensions     SWS/ReaPack (Python script support)
# @about
#   # Matchering 2.0 Worker
#   This Python script is designed to be called non-interactively by the Matchering 2.0 Lua GUI.
#   It handles the external execution of the `matchering-cli` subprocess in a non-blocking way,
#   using REAPER's ExtState for communication and RPR_defer for process status polling.
#
#   **DO NOT RUN THIS SCRIPT MANUALLY.**
#
# @changelog
#   + v1.0 (2025-11-12) - Initial release with non-blocking Popen and ExtState communication.
#
# --- END SCRIPT METADATA ---

# REAPER SCRIPT: Matchering 2.0 Worker (Python)
# DESCRIPTION: This script is CALLED BY THE LUA GUI. DO NOT RUN MANUALLY.
# It reads Target/Reference paths from ExtState and runs the process.


import os
import sys
import subprocess
import time
import re # Import regex for cleaning filenames

# --- REAPER API import is mandatory ---
try:
    from reaper_python import *
except ImportError:
    # If run outside REAPER, RPR_ functions will not work
    # print("Error: Could not import reaper_python API. Script must be run from REAPER.") # CONSOLE OFF
    # Dummy definitions to avoid syntax errors
    def RPR_ShowConsoleMsg(msg): pass # print(msg) # CONSOLE OFF
    def RPR_SetExtState(sect, key, val, persist): pass
    def RPR_GetExtState(sect, key): return ""
    def RPR_GetProjectPath(buf, buf_sz): return None, 0
    def RPR_Main_OnCommandEx(cmd_id, flag, proj): pass
    def RPR_InsertMedia(file_path, mode): return None
    def RPR_UpdateArrange(): pass
    def RPR_defer(func_name_str): pass

# --- USER CONFIGURATION BLOCK ---
PATH_TO_VENV_PYTHON = r"C:\vpy\matchering_venv\Scripts\python.exe"
PATH_TO_MG_CLI = r"C:\vpy\matchering-cli\mg_cli.py"
# DEFAULT_BIT_DEPTH = "-b24" # REMOVED (Now read from GUI)
OUTPUT_SUBFOLDER = "Matchering_Masters"
# --- END CONFIGURATION BLOCK ---

# --- Global variables for the process ---
g_process = None
g_result_path = None

# --- Helper Functions ---
def log(msg):
    """Logs a message to the Reaper Console."""
    # RPR_ShowConsoleMsg(str(msg) + "\n") # --- CONSOLE OFF ---
    pass # Do nothing

def set_status(status_msg):
    """Sends status back to the Lua GUI."""
    RPR_SetExtState("MatcheringWorker", "Status", status_msg, False)
        
def get_project_path():
    """Gets the current project path."""
    (project_path_buf, buf_size) = RPR_GetProjectPath("", 4096)
    if not project_path_buf:
        log("Error: Could not get project path.")
        return None
    return project_path_buf

def finalize_import(result_path):
    """Imports the resulting file into REAPER."""
    log(f"Importing mastered file from: {result_path}")

    RPR_Main_OnCommandEx(40297, 0, 0) # Item: Unselect all items
    RPR_Main_OnCommandEx(40001, 0, 0) # Track: Insert new track
    RPR_Main_OnCommandEx(40042, 0, 0) # Go to start of project
    new_item = RPR_InsertMedia(result_path, 0)

    if not new_item:
        log(f"Matchering succeeded, but failed to import result file: {result_path}")
        set_status("Error: Succeeded, but failed to import file.")
    else:
        log("Done! Mastered file added on a new track.")
        RPR_UpdateArrange()
        set_status("Done")

# --- Polling Logic (Non-Blocking) ---

def on_process_finished(return_code):
    """Called by poll_process() when the process completes."""
    global g_result_path
    
    if return_code == 0:
        log(f"Worker: Matchering completed successfully (Code: {return_code}).")
        set_status("Completed! Importing file...")
        finalize_import(g_result_path)
    else:
        log(f"--- WORKER: MATCHERING FAILED (Error Code: {return_code}) ---")
        set_status(f"Error: Matchering failed (Code: {return_code}).")

def poll_process():
    """Polling function (non-blocking) using RPR_defer."""
    global g_process

    if g_process is None:
        log("Worker: g_process is None. Stopping poll.")
        return

    # *** NEW (11/11/2025): Check for Cancel command from GUI ***
    command = RPR_GetExtState("MatcheringWorker", "Command")
    if command == "Cancel":
        log("Worker: Received Cancel command from GUI.")
        try:
            g_process.kill() # Kill the subprocess
            log("Worker: Subprocess killed.")
        except Exception as e:
            log(f"Worker: Error while killing process: {e}")
        
        g_process = None # Stop polling
        set_status("Error: Operation cancelled by user.")
        RPR_SetExtState("MatcheringWorker", "Command", "", False) # Clear command
        return # Stop the poll loop
    # *** END NEW ***

    return_code = g_process.poll()

    if return_code is None:
        # Still running
        set_status(f"Running... (PID: {g_process.pid})")
        # Reschedule self
        RPR_defer("poll_process()") 
    else:
        # Finished
        on_process_finished(return_code)
        g_process = None # Clear the process to stop the loop

# --- MAIN EXECUTION FUNCTION ---

def main_worker():
    """Main worker function, called when the script runs."""
    global g_process, g_result_path
    
    log("Python worker script started (Internal REAPER mode).")
    
    # 1. Read paths AND BitDepth from ExtState (written by Lua GUI)
    target_path = RPR_GetExtState("MatcheringWorker", "Target")
    ref_path = RPR_GetExtState("MatcheringWorker", "Reference")
    # *** NEW: Idea 1 (Dynamic Naming) ***
    ref_name = RPR_GetExtState("MatcheringWorker", "ReferenceName")
    if not ref_name or ref_name == "":
        ref_name = "ref" # Fallback
    # *** END NEW ***
    
    # *** NEW: Read Bit Depth from GUI ***
    bit_depth = RPR_GetExtState("MatcheringWorker", "BitDepth")
    if not bit_depth or bit_depth == "":
        bit_depth = "-b24" # Fallback just in case
        log("Warning: Bit depth not received from GUI, defaulting to -b24.")
    # *** END NEW ***

    # 2. Validation
    if not target_path or not ref_path or target_path == "" or ref_path == "":
        set_status("Error: Worker received invalid paths from ExtState.")
        log("Error: Worker received invalid paths from ExtState.")
        return

    if target_path.lower().endswith(".mp3") or ref_path.lower().endswith(".mp3"):
        set_status("Error: .mp3 files are not supported. Use .wav or .flac.")
        log("Error: .mp3 files are not supported.")
        return

    project_path_buf = get_project_path()
    if not project_path_buf:
        set_status("Error: Could not get project path. Please save project.")
        log("Error: Could not get project path from worker.")
        return

    # 3. Build Paths and Command
    output_dir = os.path.join(project_path_buf, OUTPUT_SUBFOLDER)
    if not os.path.exists(output_dir):
        try:
            os.makedirs(output_dir)
        except OSError as e:
            set_status(f"Error: Could not create output directory: {e}")
            log(f"Error: Could not create output directory: {e}")
            return

    # *** NEW: Idea 1 (Dynamic Naming) ***
    # Clean filenames to be safe
    target_filename_base = os.path.splitext(os.path.basename(target_path))[0]
    ref_filename_base = os.path.splitext(os.path.basename(ref_name))[0]
    # Remove characters that are bad for filenames
    target_filename_base = re.sub(r'[\\/*?:"<>|]', "", target_filename_base)
    ref_filename_base = re.sub(r'[\\/*?:"<>|]', "", ref_filename_base)

    result_name = f"{target_filename_base}_mastered_REF_{ref_filename_base}.wav"
    g_result_path = os.path.join(output_dir, result_name) # Save to global variable
    # *** END NEW ***

    # *** FIX: Use the 'bit_depth' variable from ExtState ***
    command_list = [
        PATH_TO_VENV_PYTHON, "-X", "utf8",
        PATH_TO_MG_CLI, bit_depth, # Use the selected bit depth
        target_path, ref_path, g_result_path
    ]

    log("Worker building command: " + " ".join(f'"{c}"' for c in command_list))

    # 4. Execute Popen (just like Hosi_...py file)
    g_process = None
    try:
        my_env = os.environ.copy()
        my_env["PYTHONIOENCODING"] = "utf-8"
        creation_flags = 0
        if sys.platform == "win32":
            creation_flags = subprocess.CREATE_NO_WINDOW

        g_process = subprocess.Popen(
            command_list,
            env=my_env,
            creationflags=creation_flags
        )
        
        log(f"Worker starting Matchering process (PID: {g_process.pid})...")
        set_status("Running...") # Send initial status to GUI
        
    except Exception as e:
        log(f"Critical error launching subprocess: {e}")
        set_status(f"Error: Popen failed: {e}")
        return

    # 5. Start the polling loop (NON-BLOCKING)
    RPR_defer("poll_process()")
    
    log("Python worker 'main' function finished. Handing over to poll_process().")

# --- Script Entry Point ---
if __name__ == "__main__":
    # This script is called from REAPER, it will run main_worker
    main_worker()