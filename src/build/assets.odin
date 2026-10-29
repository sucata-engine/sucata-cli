package build

import "../common"
import "../filesystem"
import "core:bytes"
import "core:crypto/hash"
import "core:encoding/hex"
import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:text/regex"
import "vendor:compress/lz4"
import lua "vendor:lua/5.4"

LUA_REQUIRE_REGEX :: `require\s*\(\s*["']([^"']+)["']\s*\)`
FILES_REGEX :: `["']((?:src)://[^"']+)["']`

generate_assets :: proc(src_path: string, main_file: string, output_path: string) -> string {
	files := make([dynamic]string)
	defer delete(files)

	collect_paths(main_file, &files)

	common.print_info("Packaging assets...")
	common.print_info("Found %d files to package. src: %s", len(files), src_path)

	L := lua.L_newstate()
	if L == nil {
		common.print_error("Failed to create Lua state")
		return ""
	}
	defer lua.close(L)

	lua.L_openlibs(L)

	entries := make([dynamic]common.Asset_Entry)
	defer {
		for entry in entries {
			delete(entry.path)
		}
		delete(entries)
	}

	buf: bytes.Buffer
	bytes.buffer_init_allocator(&buf, 0, 0, context.allocator)
	defer bytes.buffer_destroy(&buf)

	total_size := 0

	for file in files {
		source_file := file
		shader_rel_path := ""
		shader_schd_file := ""
		if strings.has_suffix(file, ".glsl") {
			rel, schd, built := build_project_shader(src_path, file)
			if !built {
				delete(rel)
				delete(schd)
				continue
			}
			shader_rel_path = rel
			shader_schd_file = schd
			source_file = schd
		}
		defer if shader_schd_file != "" {
			delete(shader_schd_file)
		}

		data, read_err := os.read_entire_file_from_path(source_file, context.allocator)
		defer delete(data)

		if read_err != nil {
			common.print_warning("File %s was not found!", file)
			continue
		}

		rel_path, rel_err := filepath.rel(src_path, file)
		if rel_err != nil {
			delete(rel_path)
			rel_path = file
		}
		if main_file == file {
			delete(rel_path)
			rel_path = strings.clone("main.lua")
		}

		normalized_path, was_allocated := strings.replace_all(rel_path, "\\", "/")
		if was_allocated {
			delete(rel_path)
			rel_path = normalized_path
		}

		if shader_rel_path != "" {
			delete(rel_path)
			rel_path = shader_rel_path
		}

		final_data: []byte
		bytecode_buf: [dynamic]byte
		is_bytecode := false

		is_lua := strings.has_suffix(file, ".lua")
		if is_lua {
			bc, compiled := compile_lua_to_bytecode(L, data, rel_path)
			if compiled {
				bytecode_buf = bc
				final_data = bytecode_buf[:]
				is_bytecode = true
				common.print_info("  [lua] %s -> bytecode (%d bytes)", rel_path, len(bc))
			} else {
				common.print_warning("  [lua] %s compile failed, using source", rel_path)
				final_data = data
			}
		} else {
			final_data = data
		}

		defer if is_bytecode {
			delete(bytecode_buf)
		}

		entry := common.Asset_Entry {
			path   = rel_path,
			size   = len(final_data),
			offset = total_size,
		}
		append(&entries, entry)

		bytes.buffer_write(&buf, final_data)
		total_size += len(final_data)
	}

	uncompressed_data := bytes.buffer_to_bytes(&buf)

	max_compressed_size := lz4.compressBound(cast(i32)len(uncompressed_data))
	compressed_buffer := make([]byte, max_compressed_size)
	defer delete(compressed_buffer)

	compressed_size := lz4.compress_default(
		raw_data(uncompressed_data),
		raw_data(compressed_buffer),
		cast(i32)len(uncompressed_data),
		max_compressed_size,
	)

	archive_data := compressed_buffer[:compressed_size]

	output_file_path, _ := filepath.join({output_path, DEFAULT_ASSETS_PATH}, context.allocator)
	defer delete(output_file_path)
	output_handle, open_err := os.open(output_file_path, os.O_WRONLY | os.O_CREATE | os.O_TRUNC)
	defer os.close(output_handle)

	json_data, json_err := json.marshal(entries[:])
	defer delete(json_data)

	header_size := u64(len(json_data))
	header_bytes := mem.ptr_to_bytes(&header_size)

	os.write(output_handle, header_bytes)
	os.write(output_handle, json_data)
	os.write(output_handle, archive_data)

	hash_string := get_assets_hash(output_file_path)

	return hash_string
}

get_assets_hash :: proc(assets_path: string) -> string {
	file_data, _ := os.read_entire_file_from_path(assets_path, context.allocator)
	defer delete(file_data)

	hash_bytes: [32]byte
	hash.hash(hash.Algorithm.SHA256, file_data, hash_bytes[:])

	hash_string := hex.encode(hash_bytes[:])
	hash_bytes = {}

	return string(hash_string)
}

lua_path_to_dir_path :: proc(req: string) -> string {
	base_dir := filesystem.location.src
	path, ok := strings.replace_all(req, ".", "/")
	defer {
		if path != req {
			delete(path)
		}
	}

	init_lua := fmt.tprintf("%s/%s/init.lua", base_dir, path)
	if os.exists(init_lua) {
		return init_lua
	}

	return fmt.tprintf("%s/%s.lua", base_dir, path)
}

contains_file :: proc(path: string, files: ^[dynamic]string) -> bool {
	for file in files {
		if strings.equal_fold(path, file) {
			return true
		}
	}
	return false
}

collect_paths :: proc(file_path: string, files: ^[dynamic]string) -> os.Error {
	file_content, read_err := os.read_entire_file_from_path(file_path, context.allocator)
	defer delete(file_content)
	if read_err != nil {
		return nil
	}

	if !contains_file(file_path, files) {
		append(files, file_path)
	}

	content := string(file_content)

	interator_files, err := regex.create_iterator(content, FILES_REGEX)
	defer regex.destroy_iterator(interator_files)
	if err == nil {
		for match in regex.match_iterator(&interator_files) {
			match_path := filesystem.get_path(match.groups[1])
			if !contains_file(match_path, files) {
				append(files, match_path)
			}
		}
	}

	interator_lua, err_lua := regex.create_iterator(content, LUA_REQUIRE_REGEX)
	defer regex.destroy_iterator(interator_lua)
	if err_lua == nil {
		for match in regex.match_iterator(&interator_lua) {
			match_path := lua_path_to_dir_path(match.groups[1])
			err_collect_paths := collect_paths(match_path, files)
			if err_collect_paths != nil {
				return err_collect_paths
			}
		}
	}

	return nil
}
