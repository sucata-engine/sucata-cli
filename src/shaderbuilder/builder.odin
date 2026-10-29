package shader_builder

import "core:os"
import "core:path/filepath"

build_shader_to :: proc(
	input_file: string,
	output_path: string,
	langs: string,
	keep_lang: string,
) -> bool {
	ok, temp_path := build_sokol_shader(input_file, langs)
	defer delete(temp_path)

	if !ok {
		return false
	}

	_, json_ok := generate_json(temp_path, output_path, keep_lang)
	remove_temp_folder(filepath.dir(temp_path))
	return json_ok
}

remove_temp_folder :: proc(temp_path: string) {
	if os.exists(temp_path) {
		os.remove_all(temp_path)
	}
}
