package build

import "../common"
import "../filesystem"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:strings"

BUILD_HEADER :: "SUCATA_BUILD_"
LUA_DLL_FILE_NAME :: "lua51.dll"
SDL_DLL_FILE_NAME :: "SDL3.dll"

DEFAULT_ICON_WINDOWS :: #load("../../assets/icons/sucata.ico")
DEFAULT_ICON_LINUX :: #load("../../assets/icons/sucata.png")
DEFAULT_ICON_MAC :: #load("../../assets/icons/sucata.icns")

clone_engine :: proc(output_dir: string, assets_hash: string, icon_path: string = "") {
	player_path := filesystem.get_sucata_player_path()
	defer delete(player_path)
	common.print_info("Cloning engine from: %s", player_path)

	engine_data, _ := os.read_entire_file_from_path(player_path, context.allocator)
	defer delete(engine_data)

	engine_name := filesystem.location.name
	if filesystem.location.system == "windows" {
		engine_name = fmt.tprintf("{0}.exe", engine_name)
	}
	output_path, _ := filepath.join({output_dir, engine_name}, context.allocator)
	defer delete(output_path)

	if filesystem.location.system == "darwin" {
		create_macos_app_bundle(output_dir, engine_name, engine_data, assets_hash, icon_path)
		return
	}

	output_handle, open_err := os.open(output_path, os.O_WRONLY | os.O_CREATE | os.O_TRUNC)
	defer os.close(output_handle)

	os.write(output_handle, engine_data)
	write_build_header(output_handle, assets_hash)

	if filesystem.location.system == "windows" {
		remove_console_window(output_path)
		clone_lua_dll(output_dir)
		clone_sdl_dll(output_dir)
		if icon_path != "" {
			embed_windows_icon(output_path, icon_path)
		} else {
			embed_windows_default_icon(output_path)
		}
	} else if filesystem.location.system == "linux" {
		if icon_path != "" {
			embed_linux_icon(output_path, icon_path)
		} else {
			embed_linux_default_icon(output_path)
		}
	}
}

clone_lua_dll :: proc(output_dir: string) {
	source_path := filesystem.get_sucata_folder()
	defer delete(source_path)
	lua_dll_path, _ := filepath.join({source_path, LUA_DLL_FILE_NAME}, context.allocator)
	defer delete(lua_dll_path)

	lua_dll_data, _ := os.read_entire_file_from_path(lua_dll_path, context.allocator)
	defer delete(lua_dll_data)

	output_path, _ := filepath.join({output_dir, LUA_DLL_FILE_NAME}, context.allocator)
	defer delete(output_path)

	output_handle, open_err := os.open(output_path, os.O_WRONLY | os.O_CREATE | os.O_TRUNC)
	defer os.close(output_handle)

	os.write(output_handle, lua_dll_data)
}

clone_sdl_dll :: proc(output_dir: string) {
	source_path := filesystem.get_sucata_folder()
	defer delete(source_path)
	sdl_dll_path, _ := filepath.join({source_path, SDL_DLL_FILE_NAME}, context.allocator)
	defer delete(sdl_dll_path)

	sdl_dll_data, _ := os.read_entire_file_from_path(sdl_dll_path, context.allocator)
	defer delete(sdl_dll_data)

	output_path, _ := filepath.join({output_dir, SDL_DLL_FILE_NAME}, context.allocator)
	defer delete(output_path)

	output_handle, open_err := os.open(output_path, os.O_WRONLY | os.O_CREATE | os.O_TRUNC)
	defer os.close(output_handle)

	os.write(output_handle, sdl_dll_data)
}

write_build_header :: proc(output_handle: $H, assets_hash: string) {
	build_header_hash := fmt.aprintf("{0}{1}", BUILD_HEADER, assets_hash)
	defer delete(build_header_hash)

	header_bytes := transmute([]byte)build_header_hash
	header_size := u64(len(header_bytes))

	os.write(output_handle, header_bytes)
	os.write(output_handle, mem.ptr_to_bytes(&header_size))
}

create_macos_app_bundle :: proc(
	output_dir: string,
	engine_name: string,
	engine_data: []byte,
	assets_hash: string,
	icon_path: string = "",
) {
	app_name := fmt.tprintf("{0}.app", engine_name)
	app_path, _ := filepath.join({output_dir, app_name}, context.allocator)

	contents_path, _ := filepath.join({app_path, "Contents"}, context.allocator)
	macos_path, _ := filepath.join({contents_path, "MacOS"}, context.allocator)
	resources_path, _ := filepath.join({contents_path, "Resources"}, context.allocator)

	os.make_directory(app_path)
	os.make_directory(contents_path)
	os.make_directory(macos_path)
	os.make_directory(resources_path)

	executable_path, _ := filepath.join({macos_path, engine_name}, context.allocator)
	exe_handle, open_err := os.open(executable_path, os.O_WRONLY | os.O_CREATE | os.O_TRUNC)
	if open_err != nil {
		common.print_error("Error opening executable for writing: %s", open_err)
		return
	}

	bytes_written, write_err := os.write(exe_handle, engine_data)
	if write_err != nil {
		common.print_error("Error writing engine data: %s", write_err)
		os.close(exe_handle)
		return
	}
	common.print_info("Written %d bytes of engine data", bytes_written)

	write_build_header(exe_handle, assets_hash)
	os.close(exe_handle)

	assets_src, _ := filepath.join({output_dir, DEFAULT_ASSETS_PATH}, context.allocator)
	assets_dst, _ := filepath.join({macos_path, DEFAULT_ASSETS_PATH}, context.allocator)
	if assets_data, err := os.read_entire_file_from_path(assets_src, context.allocator);
	   err == nil {
		_ = os.write_entire_file(assets_dst, assets_data)
		delete(assets_data)
		os.remove(assets_src)
	}

	icon_file_name := ""
	if icon_path != "" && os.exists(icon_path) {
		if strings.has_suffix(icon_path, ".icns") {
			icon_file_name = "app.icns"
			if icon_data, err := os.read_entire_file_from_path(icon_path, context.allocator);
			   err == nil {
				icns_path, _ := filepath.join({resources_path, icon_file_name}, context.allocator)
				defer delete(icns_path)
				_ = os.write_entire_file(icns_path, icon_data)
				delete(icon_data)
			}
		} else if strings.has_suffix(icon_path, ".png") {
			icon_file_name = "app.png"
			if icon_data, err := os.read_entire_file_from_path(icon_path, context.allocator);
			   err == nil {
				png_path, _ := filepath.join({resources_path, icon_file_name}, context.allocator)
				defer delete(png_path)
				_ = os.write_entire_file(png_path, icon_data)
				delete(icon_data)
			}
		}
	} else {
		icon_file_name = "app.icns"
		icns_path, _ := filepath.join({resources_path, icon_file_name}, context.allocator)
		defer delete(icns_path)
		_ = os.write_entire_file(icns_path, DEFAULT_ICON_MAC)
	}

	icon_plist_entry :=
		icon_file_name != "" ? fmt.tprintf(`
	<key>CFBundleIconFile</key>
	<string>{0}</string>`, icon_file_name) : ""
	defer if icon_plist_entry != "" do delete(icon_plist_entry)

	info_plist_content := fmt.aprintf(
		`<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>{0}</string>
	<key>CFBundleIdentifier</key>
	<string>dev.sucata.{0}</string>
	<key>CFBundleName</key>
	<string>{0}</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>LSMinimumSystemVersion</key>
	<string>10.15</string>
	<key>NSHighResolutionCapable</key>
	<true/>{1}
</dict>
</plist>`,
		engine_name,
		icon_plist_entry,
	)
	defer delete(info_plist_content)

	info_plist_path, _ := filepath.join({contents_path, "Info.plist"}, context.allocator)
	_ = os.write_entire_file(info_plist_path, transmute([]byte)info_plist_content)
}

embed_linux_default_icon :: proc(output_path: string) {
	output_dir := filepath.dir(output_path)
	icon_output, _ := filepath.join({output_dir, "icon.png"}, context.allocator)
	defer delete(icon_output)
	_ = os.write_entire_file(icon_output, DEFAULT_ICON_LINUX)
}

embed_linux_icon :: proc(output_path: string, icon_path: string) {
	if !os.exists(icon_path) {
		common.print_warning("Icon file not found: %s", icon_path)
		return
	}

	output_dir := filepath.dir(output_path)
	icon_output, _ := filepath.join({output_dir, "icon.png"}, context.allocator)
	defer delete(icon_output)
	if icon_data, err := os.read_entire_file_from_path(icon_path, context.allocator); err == nil {
		_ = os.write_entire_file(icon_output, icon_data)
		delete(icon_data)
	}
}

embed_windows_default_icon :: proc(exe_path: string) {
	exe_dir := filepath.dir(exe_path)
	icon_output, _ := filepath.join({exe_dir, "icon.ico"}, context.allocator)
	defer delete(icon_output)
	_ = os.write_entire_file(icon_output, DEFAULT_ICON_WINDOWS)
}

embed_windows_icon :: proc(exe_path: string, icon_path: string) {
	if !os.exists(icon_path) {
		common.print_warning("Icon file not found: %s", icon_path)
		return
	}

	if !strings.has_suffix(icon_path, ".ico") {
		common.print_warning("Windows requires .ico format for icons. Provided: %s", icon_path)
		return
	}

	exe_dir := filepath.dir(exe_path)
	icon_output, _ := filepath.join({exe_dir, "icon.ico"}, context.allocator)
	defer delete(icon_output)
	if icon_data, err := os.read_entire_file_from_path(icon_path, context.allocator); err == nil {
		_ = os.write_entire_file(icon_output, icon_data)
		delete(icon_data)
		common.print_info("Icon copied to: %s", icon_output)
	}
}

remove_console_window :: proc(exe_path: string) {
	data, read_err := os.read_entire_file_from_path(exe_path, context.allocator)
	if read_err != nil {
		common.print_warning("Could not read executable to remove console: %s", exe_path)
		return
	}
	defer delete(data)

	if len(data) < 0x40 {
		return
	}

	pe_offset :=
		u32(data[0x3C]) | u32(data[0x3D]) << 8 | u32(data[0x3E]) << 16 | u32(data[0x3F]) << 24

	if pe_offset + 4 >= u32(len(data)) {
		return
	}
	if data[pe_offset] != 'P' || data[pe_offset + 1] != 'E' {
		return
	}

	machine_offset := pe_offset + 4
	opt_hdr_size_offset := pe_offset + 20
	optional_header_offset := pe_offset + 24
	subsystem_offset := optional_header_offset + 68

	if subsystem_offset + 2 >= u32(len(data)) {
		return
	}

	if data[subsystem_offset] == 3 {
		data[subsystem_offset] = 2
		_ = os.write_entire_file(exe_path, data)
	}
}
