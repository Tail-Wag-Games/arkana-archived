import std/[os, strutils]

when defined(emscripten):
  --os:linux
  --cpu:wasm32
  --cc:clang
  --threads:off
  when defined(windows):
    switch("clang.exe", "emcc.bat")
    switch("clang.cpp.exe", "em++.bat")
    switch("clang.linkerexe", "emcc.bat")
    switch("clang.cpp.linkerexe", "em++.bat")

    when defined(server):
      switch("passC", "-D_DEBUG_ -D_DEBUG -s ASSERTIONS=1 -DNBN_DISABLE_STALE_CONNECTION_DETECTION=1 -fstrict-aliasing -fsanitize=undefined -Wall -Wextra -Wno-multichar -Wno-unknown-pragmas -Wno-ignored-qualifiers -Wno-long-long -Wno-overloaded-virtual -Wno-deprecated-writable-strings -Wno-unused-volatile-lvalue -Wno-warn-absolute-paths -Wno-expansion-to-defined -O1 -g -o ../arkanet/priv/static/assets/server.js -s USE_WEBGL2=1 -sNO_EXIT_RUNTIME=1 -s ALLOW_MEMORY_GROWTH=1 -s EXPORTED_RUNTIME_METHODS=ccall,cwrap -s DEFAULT_LIBRARY_FUNCS_TO_INCLUDE=$writeArrayToMemory -s WASM=1 -sFORCE_FILESYSTEM -s MIN_WEBGL_VERSION=2 -s MAX_WEBGL_VERSION=2 -s INITIAL_MEMORY=536870912 --pre-js ./src/pre.js --js-library ./src/server_api.js --js-library ./src/client_api.js -sSTACK_SIZE=1000000 --embed-file etc/sokol/shaders --preload-file etc/assets")
      switch("passL", "./thirdparty/ozz.a -D_DEBUG_ -D_DEBUG -s ASSERTIONS=1 -DNBN_DISABLE_STALE_CONNECTION_DETECTION=1 -fsanitize=undefined -g -o ../arkanet/priv/static/assets/server.js -s USE_WEBGL2=1 -sNO_EXIT_RUNTIME=1 -s ALLOW_MEMORY_GROWTH=1 -s EXPORTED_RUNTIME_METHODS=ccall,cwrap -s DEFAULT_LIBRARY_FUNCS_TO_INCLUDE=$writeArrayToMemory -s WASM=1 -s MIN_WEBGL_VERSION=2 -s MAX_WEBGL_VERSION=2 -s INITIAL_MEMORY=536870912 --pre-js ./src/pre.js --js-library ./src/server_api.js --js-library ./src/client_api.js -sSTACK_SIZE=1000000 --embed-file etc/sokol/shaders")
    else:
      switch("passC", "-D_DEBUG_ -D_DEBUG -s ASSERTIONS=1 -DNBN_DISABLE_STALE_CONNECTION_DETECTION=1 -fstrict-aliasing -fsanitize=undefined -Wall -Wextra -Wno-multichar -Wno-unknown-pragmas -Wno-ignored-qualifiers -Wno-long-long -Wno-overloaded-virtual -Wno-deprecated-writable-strings -Wno-unused-volatile-lvalue -Wno-warn-absolute-paths -Wno-expansion-to-defined -O1 -g -o ../arkanet/priv/static/assets/client.js -s USE_WEBGL2=1 -sNO_EXIT_RUNTIME=1 -s ALLOW_MEMORY_GROWTH=1 -s EXPORTED_RUNTIME_METHODS=ccall,cwrap -s DEFAULT_LIBRARY_FUNCS_TO_INCLUDE=$writeArrayToMemory -s WASM=1 -sFORCE_FILESYSTEM -s MIN_WEBGL_VERSION=2 -s MAX_WEBGL_VERSION=2 -s INITIAL_MEMORY=536870912 --pre-js ./src/pre.js --js-library ./src/client_api.js -sSTACK_SIZE=1000000 --embed-file etc/sokol/shaders --preload-file etc/assets")
      switch("passL", "./thirdparty/ozz.a -D_DEBUG_ -D_DEBUG -s ASSERTIONS=1 -DNBN_DISABLE_STALE_CONNECTION_DETECTION=1 -fsanitize=undefined -O1 -g -o ../arkanet/priv/static/assets/client.js -s USE_WEBGL2=1 -sNO_EXIT_RUNTIME=1 -s ALLOW_MEMORY_GROWTH=1 -s EXPORTED_RUNTIME_METHODS=ccall,cwrap -s DEFAULT_LIBRARY_FUNCS_TO_INCLUDE=$writeArrayToMemory -s WASM=1 -s MIN_WEBGL_VERSION=2 -s MAX_WEBGL_VERSION=2 -s INITIAL_MEMORY=536870912 --pre-js ./src/pre.js --js-library ./src/client_api.js -sSTACK_SIZE=1000000 --embed-file etc/sokol/shaders")

    # switch("clang.options.always", "-g2 -O1 -s DEMANGLE_SUPPORT=1 -s ASSERTIONS=1 -s ALLOW_MEMORY_GROWTH=1 -s BINARYEN_MEM_MAX=2147418112 -s EXTRA_EXPORTED_RUNTIME_METHODS=\"['intArrayFromString', 'ALLOC_NORMAL', 'allocate']\" -s SINGLE_FILE=1 -s WASM=1 -s BINARYEN_ASYNC_COMPILATION=1 -s DISABLE_EXCEPTION_CATCHING=0")
    # switch("clang.options.linker", "-g2 -O1 -s DEMANGLE_SUPPORT=1 -s ASSERTIONS=1 -s ALLOW_MEMORY_GROWTH=1 -s BINARYEN_MEM_MAX=2147418112 -s EXTRA_EXPORTED_RUNTIME_METHODS=\"['intArrayFromString', 'ALLOC_NORMAL', 'allocate']\" -s SINGLE_FILE=1 -s WASM=1 -s BINARYEN_ASYNC_COMPILATION=1 -s DISABLE_EXCEPTION_CATCHING=0")
    # switch("clang.cpp.options.always", "-g2 -O1 -s DEMANGLE_SUPPORT=1 -s ASSERTIONS=1 -std=c++14 -s ALLOW_MEMORY_GROWTH=1 -s BINARYEN_MEM_MAX=2147418112 -s EXTRA_EXPORTED_RUNTIME_METHODS=\"['intArrayFromString', 'ALLOC_NORMAL', 'allocate']\" -s SINGLE_FILE=1 -s WASM=1 -s BINARYEN_ASYNC_COMPILATION=1 -s DISABLE_EXCEPTION_CATCHING=0")
    # switch("clang.cpp.options.linker", "-g2 -O1 -s DEMANGLE_SUPPORT=1 -s ASSERTIONS=1 -s ALLOW_MEMORY_GROWTH=1 -s BINARYEN_MEM_MAX=2147418112 -s EXTRA_EXPORTED_RUNTIME_METHODS=\"['intArrayFromString', 'ALLOC_NORMAL', 'allocate']\" -s SINGLE_FILE=1 -s WASM=1 -s BINARYEN_ASYNC_COMPILATION=1 -s DISABLE_EXCEPTION_CATCHING=0")

--gc:arc
--exceptions:goto
--stackTrace:off
--define:noSignalHandler
--define:useMalloc
--tlsEmulation:off
# --debugger:native


let
  thirdPartyPath = projectDir() / ".." / "thirdparty"
  mimallocPath = thirdPartyPath / "mimalloc" 
  # Quote the paths so we support paths with spaces
  # TODO: Is there a better way of doing this?
  # mimallocStatic = "mimallocStatic=\"" & (mimallocPath / "src" / "static.c") & '"'
  # mimallocIncludePath = "mimallocIncludePath=\"" & (mimallocPath / "include") & '"'

# switch("define", mimallocStatic)
# switch("define", mimallocIncludePath)
# patchFile("stdlib", "malloc", "alloc")

switch("path", thirdPartyPath)
switch("path", thirdPartyPath / "jsbind")
switch("path", thirdPartyPath / "nim-cppstl")
switch("path", thirdPartyPath / "sokol-nim" / "src")