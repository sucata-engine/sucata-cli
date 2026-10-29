package build

import "../common"
import "../filesystem"
import "../shaderbuilder"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:time"

SHADER_BUILD_DIR :: ".sucata/shaders"

shader_build_relative_path :: proc(src_path: string, glsl_file: string) -> string {
	rel_path, rel_err := filepath.rel(src_path, glsl_file)
	if rel_err != nil {
		delete(rel_path)
		rel_path = strings.clone(filepath.base(glsl_file))
	}
	defer delete(rel_path)

	normalized, was_allocated := strings.replace_all(rel_path, "\\", "/")
	defer if was_allocated {
		delete(normalized)
	}

	return fmt.aprintf("%s/%s.schd", SHADER_BUILD_DIR, strings.trim_suffix(normalized, ".glsl"))
}

shader_is_up_to_date :: proc(glsl_file: string, schd_file: string) -> bool {
	if !os.exists(schd_file) {
		return false
	}

	glsl_time, glsl_err := os.modification_time_by_path(glsl_file)
	schd_time, schd_err := os.modification_time_by_path(schd_file)
	if glsl_err != nil || schd_err != nil || time.time_to_unix_nano(schd_time) < time.time_to_unix_nano(glsl_time) {
		return false
	}

	schd_data, read_err := os.read_entire_file_from_path(schd_file, context.allocator)
	if read_err != nil {
		return false
	}
	defer delete(schd_data)

	lang_marker := fmt.tprintf("\"%s\"", shaderbuilder.current_os_shader_lang())
	return strings.contains(string(schd_data), lang_marker)
}

build_project_shader :: proc(src_path: string, glsl_file: string) -> (string, string, bool) {
	rel_path := shader_build_relative_path(src_path, glsl_file)
	schd_file, _ := filepath.join({src_path, rel_path}, context.allocator)

	if shader_is_up_to_date(glsl_file, schd_file) {
		return rel_path, schd_file, true
	}

	if !os.exists(glsl_file) {
		common.print_error("Shader file %s was not found!", glsl_file)
		return rel_path, schd_file, false
	}

	os.make_directory_all(filepath.dir(schd_file))

	common.print_info("  [shader] %s -> %s", glsl_file, rel_path)
	ok := shaderbuilder.build_shader_to(
		glsl_file,
		schd_file,
		shaderbuilder.current_os_build_langs(),
		shaderbuilder.current_os_shader_lang(),
	)
	if !ok {
		common.print_error("Failed to build shader: %s", glsl_file)
	}

	return rel_path, schd_file, ok
}

build_project_shaders :: proc(main_file: string) -> bool {
	files := make([dynamic]string)
	defer delete(files)

	collect_paths(main_file, &files)

	all_ok := true
	for file in files {
		if !strings.has_suffix(file, ".glsl") {
			continue
		}

		rel_path, schd_file, ok := build_project_shader(filesystem.location.src, file)
		delete(rel_path)
		delete(schd_file)
		if !ok {
			all_ok = false
		}
	}

	return all_ok
}
