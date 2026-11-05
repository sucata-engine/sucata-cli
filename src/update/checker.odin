package update

import "core:os"
import "core:strings"

VERSION_URL :: "https://github.com/sucata-engine/sucata-engine/raw/branch/main/VERSION"

get_curl :: proc() -> string {
	when ODIN_OS == .Windows {
		return "curl.exe"
	} else {
		return "curl"
	}
}

get_last_version :: proc() -> (string, bool) {
	state, stdout, stderr, err := os.process_exec(
		os.Process_Desc{command = {get_curl(), "-fsSL", VERSION_URL}},
		context.allocator,
	)
	defer delete(stdout)
	defer delete(stderr)

	if err != nil || state.exit_code != 0 {
		return strings.clone(""), true
	}

	return strings.clone(strings.trim_space(string(stdout))), false
}

check_version :: proc(current_version: string) -> bool {
	last_version, err := get_last_version()
	defer delete(last_version)

	if err {
		return false
	}

	return !strings.equal_fold(current_version, last_version)
}
