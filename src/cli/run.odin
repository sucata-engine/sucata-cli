package cli

import build "../build"
import "../common"
import "../filesystem"
import "core:fmt"
import "core:os"
import "core:path/filepath"

RUN_COMMAND :: Command {
	command = "run",
	args_size = 1,
	info_msg = "sucata run <file> - Run a Sucata Lua script file",
	error_msg = "Error: 'run' command requires a <file> argument.",
	handler = proc(args: []string) {
		file_path_args := args[0]
		current_directory, err := os.get_working_directory(context.allocator)
		defer delete(current_directory)
		file_path, err2 := filepath.join({current_directory, file_path_args}, context.allocator)
		defer delete(file_path)

		filesystem.init_run_paths(file_path)
		if !build.build_project_shaders(filesystem.location.file) {
			common.print_warning("Some shaders failed to build, the game may not render them")
		}
		filesystem.uninit_paths()

		sucata_path := filesystem.get_sucata_player_path()
		defer delete(sucata_path)

		process_desc := os.Process_Desc {
			command = {sucata_path, file_path},
			stdout  = os.stdout,
			stderr  = os.stderr,
		}
		process, _ := os.process_start(process_desc)
		state, _ := os.process_wait(process)

		if state.exited {
			fmt.printfln("Process exited with code: %d", state.exit_code)
		}
	},
}
