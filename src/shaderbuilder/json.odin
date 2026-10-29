package shader_builder

import "../common"
import "core:encoding/json"
import "core:os"
import "core:strings"

replace_path_with_data :: proc(func: ^map[string]YamlValue) -> bool {
	path_value, has_path := func["path"]
	if !has_path {
		return true
	}

	path, is_string := path_value.(string)
	if !is_string {
		return false
	}

	data, err := os.read_entire_file_from_path(path, context.allocator)
	if err != nil {
		common.print_error("Failed to read shader file: %s", path)
		return false
	}

	removed_key, removed_value := delete_key(func, "path")
	delete(removed_key)
	free_yaml_value(&removed_value)

	func[strings.clone("data")] = data
	return true
}

get_yaml_map :: proc(value: ^YamlValue) -> ^map[string]YamlValue {
	if m, ok := &value.(map[string]YamlValue); ok {
		return m
	}
	return nil
}

get_yaml_list :: proc(m: ^map[string]YamlValue, key: string) -> []YamlValue {
	if value, ok := m[key]; ok {
		if list, is_list := value.([]YamlValue); is_list {
			return list
		}
	}
	return nil
}

get_first_program :: proc(shader: ^YamlValue) -> ^map[string]YamlValue {
	shader_map := get_yaml_map(shader)
	if shader_map == nil {
		return nil
	}
	programs := get_yaml_list(shader_map, "programs")
	if len(programs) == 0 {
		return nil
	}
	return get_yaml_map(&programs[0])
}

get_shader_slang :: proc(shader: ^YamlValue) -> string {
	shader_map := get_yaml_map(shader)
	if shader_map == nil {
		return ""
	}
	if slang, ok := shader_map["slang"].(string); ok {
		return slang
	}
	return ""
}

inject_shader_data :: proc(yaml_data: ^YamlValue) -> bool {
	root := get_yaml_map(yaml_data)
	if root == nil {
		return false
	}

	shaders := get_yaml_list(root, "shaders")
	for &shader in shaders {
		program := get_first_program(&shader)
		if program == nil {
			continue
		}

		for func_name in ([]string{"vertex_func", "fragment_func"}) {
			func, ok := &program[func_name]
			if !ok {
				continue
			}
			func_map := get_yaml_map(func)
			if func_map == nil || !replace_path_with_data(func_map) {
				return false
			}
		}
	}

	return true
}

copy_attr_names :: proc(from_program: ^map[string]YamlValue, to_program: ^map[string]YamlValue) {
	from_attrs := get_yaml_list(from_program, "attrs")
	to_attrs := get_yaml_list(to_program, "attrs")

	for &to_attr in to_attrs {
		to_map := get_yaml_map(&to_attr)
		if to_map == nil {
			continue
		}
		to_slot, _ := to_map["slot"].(i64)

		for &from_attr in from_attrs {
			from_map := get_yaml_map(&from_attr)
			if from_map == nil {
				continue
			}
			from_slot, _ := from_map["slot"].(i64)
			if from_slot != to_slot {
				continue
			}
			if name, has_name := from_map["glsl_name"].(string); has_name {
				if _, exists := to_map["glsl_name"]; !exists {
					to_map[strings.clone("glsl_name")] = strings.clone(name)
				}
			}
			break
		}
	}
}

keep_only_lang :: proc(yaml_data: ^YamlValue, lang: string) {
	root := get_yaml_map(yaml_data)
	if root == nil {
		return
	}

	shaders := get_yaml_list(root, "shaders")

	glsl_program: ^map[string]YamlValue
	for &shader in shaders {
		if get_shader_slang(&shader) == "glsl430" {
			glsl_program = get_first_program(&shader)
		}
	}

	if glsl_program != nil && lang != "glsl430" {
		for &shader in shaders {
			if get_shader_slang(&shader) == lang {
				if program := get_first_program(&shader); program != nil {
					copy_attr_names(glsl_program, program)
				}
			}
		}
	}

	kept := make([dynamic]YamlValue, 0, 1)
	for &shader in shaders {
		if get_shader_slang(&shader) == lang {
			append(&kept, shader)
		} else {
			free_yaml_value(&shader)
		}
	}

	delete(shaders)
	root["shaders"] = kept[:]
}

generate_json :: proc(yaml_path: string, output_path: string, keep_lang: string = "") -> (string, bool) {
	data, data_ok := os.read_entire_file_from_path(yaml_path, context.allocator)

	if data_ok != nil {
		common.print_error("Failed to read generated shader file: %s", yaml_path)
		return "", false
	}
	defer delete(data)

	yaml_data := parse_yaml(string(data))
	defer free_yaml_value(&yaml_data)

	if !inject_shader_data(&yaml_data) {
		return "", false
	}

	if keep_lang != "" {
		keep_only_lang(&yaml_data, keep_lang)
	}

	json_data, json_ok := json.marshal(yaml_data)
	defer delete(json_data)

	if json_ok != json.Marshal_Data_Error.None {
		common.print_error("Failed to convert YAML to JSON for shader: %s", yaml_path)
		return "", false
	}

	if write_err := os.write_entire_file(output_path, json_data); write_err != nil {
		common.print_error("Failed to write shader file: %s", output_path)
		return "", false
	}

	return output_path, true
}
