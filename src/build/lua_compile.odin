package build

import "../common"
import "base:runtime"
import "core:c"
import "core:fmt"
import "core:slice"
import "core:strings"
import lua "vendor:lua/5.4"

@(private)
Dump_Buffer :: struct {
	data: [dynamic]byte,
}

@(private)
lua_writer :: proc "c" (L: ^lua.State, p: rawptr, sz: ^c.size_t, ud: rawptr) -> c.int {
	context = runtime.default_context()

	size := int(uintptr(sz))
	if p == nil || size == 0 {
		return 0
	}

	buf := cast(^Dump_Buffer)ud
	if buf == nil {
		return 1
	}

	chunk := slice.from_ptr(cast(^byte)p, size)
	append(&buf.data, ..chunk)
	return 0
}

compile_lua_to_bytecode :: proc(
	L: ^lua.State,
	source: []byte,
	name: string,
) -> (
	result: [dynamic]byte,
	ok: bool,
) {
	nm := strings.clone_to_cstring(name, context.temp_allocator)

	status := lua.L_loadbuffer(L, raw_data(source), c.size_t(len(source)), nm)
	if status != .OK {
		err := lua.tostring(L, -1)
		common.print_warning("Lua compile error em %s: %s", name, err)
		lua.pop(L, 1)
		return {}, false
	}

	buf: Dump_Buffer
	buf.data = make([dynamic]byte)

	dump_status := lua.dump(L, lua_writer, &buf, true)
	lua.pop(L, 1)

	if dump_status != .OK {
		common.print_warning("Lua dump error em %s", name)
		delete(buf.data)
		return {}, false
	}

	return buf.data, true
}
