package build

import "../common"
import "core:c"
import "core:strings"
import lua "../luajit"

compile_lua_to_bytecode :: proc(
	L: ^lua.State,
	source: []byte,
	name: string,
) -> (
	result: [dynamic]byte,
	ok: bool,
) {
	top := lua.gettop(L)
	defer lua.settop(L, top)

	chunk_name := strings.clone_to_cstring(strings.concatenate({"@", name}, context.temp_allocator), context.temp_allocator)

	lua.getglobal(L, "string")
	lua.getfield(L, -1, "dump")

	if lua.L_loadbuffer(L, raw_data(source), c.size_t(len(source)), chunk_name) != .OK {
		common.print_warning("Lua compile error em %s: %s", name, lua.tostring(L, -1))
		return {}, false
	}

	lua.pushboolean(L, true)

	if lua.pcall(L, 2, 1, 0) != 0 {
		common.print_warning("Lua dump error em %s: %s", name, lua.tostring(L, -1))
		return {}, false
	}

	size: c.size_t
	bytes := lua.tolstring(L, -1, &size)
	if bytes == nil {
		common.print_warning("Lua dump error em %s", name)
		return {}, false
	}

	data := make([dynamic]byte, int(size))
	copy(data[:], (cast([^]byte)bytes)[:int(size)])
	return data, true
}
