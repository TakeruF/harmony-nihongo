load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc:cc_toolchain_config_lib.bzl", "feature", "flag_set", "flag_group", "tool_path")
load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")
SDK = "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native"
def _impl(ctx):
    compile_actions = [ACTION_NAMES.c_compile, ACTION_NAMES.cpp_compile, ACTION_NAMES.assemble, ACTION_NAMES.preprocess_assemble]
    link_actions = [ACTION_NAMES.cpp_link_executable, ACTION_NAMES.cpp_link_dynamic_library, ACTION_NAMES.cpp_link_nodeps_dynamic_library]
    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        toolchain_identifier = "ohos-arm64", host_system_name = "darwin-arm64", target_system_name = "aarch64-linux-ohos",
        target_cpu = "aarch64", target_libc = "musl", compiler = "clang", abi_version = "", abi_libc_version = "",
        cxx_builtin_include_directories = [SDK + "/llvm/lib/clang/15.0.4/include", SDK + "/llvm/include/c++/v1", SDK + "/llvm/include/libcxx-ohos/include/c++/v1", SDK + "/sysroot/usr/include", SDK + "/sysroot/usr/include/aarch64-linux-ohos"],
        tool_paths = [tool_path(name = n, path = SDK + "/llvm/bin/" + p) for n,p in [("gcc","clang++"),("ld","ld.lld"),("ar","llvm-ar"),("cpp","clang++"),("gcov","llvm-profdata"),("nm","llvm-nm"),("objdump","llvm-objdump"),("strip","llvm-strip")]],
        features = [
            feature(name = "ohos_flags", enabled = True, flag_sets = [
                flag_set(actions = compile_actions + link_actions, flag_groups = [flag_group(flags = ["--target=aarch64-linux-ohos", "--sysroot=" + SDK + "/sysroot", "-D__MUSL__", "-fPIC"])]),
                flag_set(actions = [ACTION_NAMES.cpp_compile], flag_groups = [flag_group(flags = ["-std=c++20"])]),
                flag_set(actions = [ACTION_NAMES.c_compile], flag_groups = [flag_group(flags = ["-x", "c", "-std=c11"])]),
                flag_set(actions = compile_actions, flag_groups = [flag_group(flags = ["-O2", "-DNDEBUG", "-funsigned-char", "-Wno-deprecated-declarations"])]),
                flag_set(actions = link_actions, flag_groups = [flag_group(flags = ["-stdlib=libc++", "-lc++_shared", "-lm", "-Wl,-z,defs"])]),
            ]),
        ],
    )
ohos_config = rule(implementation = _impl, attrs = {})
