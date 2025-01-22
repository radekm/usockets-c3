A C3 binding to uSockets library. UDP and QUIC are not included.

Note: This is probably a temporary solution. I plan to create a TCP/TLS
library in C3 from scratch but with similar API.

## Usage

**Copy directories** `libs` and `usockets.c3l` to you project.
`libs` contains C and C++ code of BoringSSL, uSockets and libuv.
libuv is only needed on Windows.
`usockets.c3l` contains C3 signatures.

`usockets.c3l` depends on static libraries, so you must build those
libraries before using `usockets.c3l`.

### Bulding static libraries

Let's build static libraries in directory `build/libs`.

On macOS and Linux:

```bash
mkdir -p build/libs
cd build/libs
cmake ../../libs -DCMAKE_BUILD_TYPE=Release
cmake --build .
cd ../..
```

On Windows:

```cmd
md build\libs
cd build\libs
cmake ..\..\libs
cmake --build . --config Release
cd ..\..
```

### Building C3 code

After you have built static libraries you can build C3 code
which depends on `usockets.c3l`.
Let's build your code in directory `build`.

On macOS, Linux and Windows:

```bash
cd build
c3c compile -O1 --macos-min-version 13.0 -L libs --libdir .. --lib usockets [your-c3-files] -o [name-of-your-executable]
cd ..
```

Explanation:
- `--macos-min-version 13.0` may be omitted on Linux and Windows.
- `-L libs` specifies the path to static libraries built in the previous step by CMake.
- `--libdir ..` specifies the path to C3 libraries.
- `--lib usockets` says that we want to compile with C3 library `usockets.c3l`.
- `[your-c3-files]` is a placeholder for a list of your C3 source files.
- `[name-of-your-executable]` is a placeholder for a name of your executable.

## Contributions

We accept:

- ✅ Bug reports for the following platforms:
  - macOS on arm64
  - Windows 11 on x64
  - Linux on x64

We don't accept:

- ❌ Pull requests
- ❌ Feature requests
