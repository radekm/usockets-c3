cmake_minimum_required(VERSION 3.20)
project(libs)

set(CMAKE_C_STANDARD 17)
set(CMAKE_CXX_STANDARD 17)

# For macOS. Must be also set in both `manifest.json` files.
set(CMAKE_OSX_DEPLOYMENT_TARGET "13.0")

# Otherwise on Windows static libraries end up in `Debug` or `Release` subfolder.
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_DEBUG ${CMAKE_BINARY_DIR})
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_RELEASE ${CMAKE_BINARY_DIR})

if(WIN32)
    # On Windows, prefer cl over gcc if both are available. By default most of
    # the CMake generators prefer gcc, even on Windows.
    set(CMAKE_GENERATOR_CC cl)
endif()

include(boringssl/gen/sources.cmake)

if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    set(CLANG 1)
endif()

if(CMAKE_SYSTEM_NAME STREQUAL "Emscripten")
    set(EMSCRIPTEN 1)
endif()

if(CMAKE_COMPILER_IS_GNUCXX OR CLANG)
    if(MSVC)
        set(C_CXX_FLAGS "${C_CXX_FLAGS} -fmsc-version=1900")
    else()
        if(EMSCRIPTEN)
            # emscripten's emcc/clang does not accept the "-ggdb" flag.
            set(C_CXX_FLAGS "${C_CXX_FLAGS} -g")
        else()
            set(C_CXX_FLAGS "${C_CXX_FLAGS} -ggdb")
        endif()

        set(C_CXX_FLAGS "${C_CXX_FLAGS} -fvisibility=hidden -fno-common")
    endif()
elseif(MSVC)
    set(CMAKE_C_FLAGS "-utf-8")
    # Without /Zc:__cplusplus, MSVC does not define the right value for
    # __cplusplus. See https://devblogs.microsoft.com/cppblog/msvc-now-correctly-reports-__cplusplus/
    # If this becomes too problematic for downstream code, we can look at
    # _MSVC_LANG.
    set(CMAKE_CXX_FLAGS "-utf-8 -Zc:__cplusplus")
endif()

if(WIN32)
    add_definitions(-D_HAS_EXCEPTIONS=0)
    add_definitions(-DWIN32_LEAN_AND_MEAN)
    add_definitions(-DNOMINMAX)
    # Allow use of fopen.
    add_definitions(-D_CRT_SECURE_NO_WARNINGS)
endif()

# pthread_rwlock_t on Linux requires a feature flag. We limit this to Linux
# because, on Apple platforms, it instead disables APIs we use. See compat(5)
# and sys/cdefs.h. Reportedly, FreeBSD also breaks when this is set. See
# https://crbug.com/boringssl/471.
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -D_XOPEN_SOURCE=700")
endif()

add_definitions(-DBORINGSSL_IMPLEMENTATION)

# On x86 and x86_64 Windows, we use the NASM output.
if(WIN32 AND CMAKE_SYSTEM_PROCESSOR MATCHES "AMD64|x86_64|amd64|x86|i[3-6]86")
    enable_language(ASM_NASM)
    set(OPENSSL_NASM TRUE)
    set(CMAKE_ASM_NASM_FLAGS "${CMAKE_ASM_NASM_FLAGS} -gcv8")
else()
    enable_language(ASM)
    set(OPENSSL_ASM TRUE)
    if(NOT WIN32)
        set(CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS} -Wa,--noexecstack")
    endif()
    # Clang's integerated assembler does not support debug symbols.
    if(NOT CMAKE_ASM_COMPILER_ID MATCHES "Clang")
        set(CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS} -Wa,-g")
    endif()
endif()

if(OPENSSL_ASM)
    set(CRYPTO_SOURCES_ASM_USED ${CRYPTO_SOURCES_ASM})
    set(BCM_SOURCES_ASM_USED ${BCM_SOURCES_ASM})
elseif(OPENSSL_NASM)
    set(CRYPTO_SOURCES_ASM_USED ${CRYPTO_SOURCES_NASM})
    set(BCM_SOURCES_ASM_USED ${BCM_SOURCES_NASM})
endif()

list(TRANSFORM BCM_SOURCES PREPEND "${PROJECT_SOURCE_DIR}/boringssl/")
list(TRANSFORM BCM_SOURCES_ASM_USED PREPEND "${PROJECT_SOURCE_DIR}/boringssl/")
add_library(fipsmodule OBJECT ${BCM_SOURCES} ${BCM_SOURCES_ASM_USED})
# The C++ code in libcrypto shouldn't depend on libstdc++.
target_compile_options(fipsmodule PRIVATE $<$<COMPILE_LANGUAGE:CXX>:${NO_CXX_RUNTIME_FLAGS}>)
target_include_directories(fipsmodule PRIVATE ${PROJECT_SOURCE_DIR}/boringssl/include)
set(CRYPTO_FIPS_OBJECTS $<TARGET_OBJECTS:fipsmodule>)

list(TRANSFORM CRYPTO_SOURCES PREPEND "${PROJECT_SOURCE_DIR}/boringssl/")
list(TRANSFORM CRYPTO_SOURCES_ASM_USED PREPEND "${PROJECT_SOURCE_DIR}/boringssl/")
add_library(crypto STATIC ${CRYPTO_SOURCES} ${CRYPTO_FIPS_OBJECTS} ${CRYPTO_SOURCES_ASM_USED})

# The C++ code in libcrypto shouldn't depend on libstdc++.
target_compile_options(crypto PRIVATE $<$<COMPILE_LANGUAGE:CXX>:${NO_CXX_RUNTIME_FLAGS}>)
target_include_directories(crypto PUBLIC
    $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/boringssl/include>
)
set_property(TARGET crypto PROPERTY EXPORT_NAME Crypto)

if(WIN32)
    target_link_libraries(crypto ws2_32)
endif()

list(TRANSFORM SSL_SOURCES PREPEND "${PROJECT_SOURCE_DIR}/boringssl/")
add_library(ssl STATIC ${SSL_SOURCES})
# Although libssl also provides headers that require an include directory, the
# flag is already specified by libcrypto, so we omit target_include_directories
# here.
set_property(TARGET ssl PROPERTY EXPORT_NAME SSL)
target_link_libraries(ssl crypto)

if(WIN32)
    file(GLOB UV_SOURCES "libuv/src/*.c" "libuv/src/win/*.c")
    add_library(uv STATIC ${UV_SOURCES})
    target_include_directories(uv PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/libuv/include)
    target_include_directories(uv PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/libuv/src)
endif()

file(GLOB_RECURSE USOCKETS_SOURCES "usockets/*.c" "usockets/*.cpp")
add_library(usockets STATIC ${USOCKETS_SOURCES})
target_compile_definitions(usockets PRIVATE LIBUS_USE_OPENSSL=1)
if(WIN32)
    target_link_libraries(usockets uv)
endif()
target_include_directories(usockets PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/usockets)
target_link_libraries(usockets ssl crypto)
