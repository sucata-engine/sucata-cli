package shader_builder

import "../common"
import "../filesystem"
import "core:fmt"
import "core:os"
import "core:path/filepath"

current_os_shader_lang :: proc() -> string {
	when ODIN_OS == .Windows {
		return "hlsl5"
	} else when ODIN_OS == .Darwin {
		return "metal_macos"
	} else {
		return "glsl430"
	}
}

current_os_build_langs :: proc() -> string {
	when ODIN_OS == .Windows {
		return "glsl430:hlsl5"
	} else when ODIN_OS == .Darwin {
		return "glsl430:metal_macos"
	} else {
		return "glsl430"
	}
}

build_sokol_shader :: proc(input_file: string, langs: string) -> (bool, string) {
	sucata_path := filesystem.get_sucata_folder()
	defer delete(sucata_path)
	if !os.exists(input_file) {
		common.print_error("Shader file does not exist: %s", input_file)
		return false, ""
	}
	temp_dir, _ := filepath.join({sucata_path, "temp"}, context.allocator)
	defer delete(temp_dir)
	if !os.exists(temp_dir) {
		os.make_directory(temp_dir)
	}
	temp_shader_path, _ := filepath.join({sucata_path, "temp", "shader"}, context.allocator)
	defer delete(temp_shader_path)

	sokol_shdc_path := get_sokol_shdc_path()
	defer delete(sokol_shdc_path)

	if sokol_shdc_path == "" {
		common.print_error("sokol-shdc for your OS was not found!")
		return false, ""
	}

	if !os.exists(sokol_shdc_path) {
		common.print_error("sokol-shdc is not installed!")
		return false, ""
	}

	process_desc := os.Process_Desc {
		command = {
			sokol_shdc_path,
			"-i",
			input_file,
			"-o",
			temp_shader_path,
			"-l",
			langs,
			"-f",
			"bare_yaml",
		},
	}

	process_state, stdout_file, stderr_file, err := os.process_exec(
		process_desc,
		context.allocator,
	)
	if err != nil {
		common.print_error("Failed to execute process: %s", err)
		os.exit(1)
	}

	defer delete(stdout_file)
	defer delete(stderr_file)

	if len(stdout_file) > 0 {
		common.print_info("[sokol-shdc] %s", string(stdout_file))
	}
	if len(stderr_file) > 0 {
		common.print_error("[sokol-shdc] %s", string(stderr_file))
	}

	if process_state.exit_code != 0 {
		return false, ""
	}

	output_temp_path := fmt.aprintf("{}_reflection.yaml", temp_shader_path)
	return true, output_temp_path
}


get_sokol_shdc_path :: proc() -> string {
	sucata_path := filesystem.get_sucata_folder()
	defer delete(sucata_path)

	shdc_path := ""

	when ODIN_OS == .Windows {
		shdc_path, _ = filepath.join({sucata_path, "sokol-shdc", "sokol-shdc-win.exe"}, context.allocator)
	} else when ODIN_OS == .Darwin {
		when ODIN_ARCH == .arm64 {
			shdc_path, _ = filepath.join({sucata_path, "sokol-shdc", "sokol-shdc-osx-arm"}, context.allocator)
		} else {
			shdc_path, _ = filepath.join({sucata_path, "sokol-shdc", "sokol-shdc-osx"}, context.allocator)
		}
	} else when ODIN_OS == .Linux {
		when ODIN_ARCH == .arm64 {
			shdc_path, _ = filepath.join({sucata_path, "sokol-shdc", "sokol-shdc-linux-arm"}, context.allocator)
		} else {
			shdc_path, _ = filepath.join({sucata_path, "sokol-shdc", "sokol-shdc-linux"}, context.allocator)
		}
	}

	return shdc_path
}
