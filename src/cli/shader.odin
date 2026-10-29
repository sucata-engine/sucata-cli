package cli

import "../common"
import "../shaderbuilder"
import "core:fmt"
import "core:path/filepath"
import "core:strings"

SHADER_COMMAND :: Command {
	command = "shader",
	args_size = 1,
	info_msg = "sucata shader <file> [--post-processing/-pp] [--font/-f] - Create a base .glsl shader file",
	error_msg = "Error: 'shader' command requires a <file> argument.",
	handler = proc(args: []string) {
		file_path_args := args[0]
		if !strings.has_suffix(file_path_args, ".glsl") {
			file_path_args = fmt.tprintf("%s.glsl", file_path_args)
		}
		current_directory, _ := filepath.abs(".", context.allocator)
		defer delete(current_directory)
		file_path, _ := filepath.join({current_directory, file_path_args}, context.allocator)
		defer delete(file_path)

		is_post_processing := false
		is_font_shader := false
		for flag in args[1:] {
			if flag == "--post-processing" || flag == "-pp" {
				is_post_processing = true
				break
			}
			if flag == "--font" || flag == "-f" {
				is_font_shader = true
				break
			}
		}

		file_name := filepath.base(file_path)
		if is_post_processing {
			shaderbuilder.create_default_post_processing(file_path)
			common.print_success("%s post processing shader created!", file_name)
		} else if is_font_shader {
			shaderbuilder.create_default_font_shader(file_path)
			common.print_success("%s font shader created!", file_name)
		} else {
			shaderbuilder.create_default_quad(file_path)
			common.print_success("%s custom shader created!", file_name)
		}
	},
}
