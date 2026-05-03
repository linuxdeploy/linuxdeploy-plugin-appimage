# support for ccache
# call CMake with -DUSE_CCACHE=OFF to explicitly disable it
set(USE_CCACHE ON CACHE BOOL "Use CCache to speed up builds")
if(USE_CCACHE)
    find_program(CCACHE ccache)
    if(CCACHE)
        message(STATUS "Using ccache")
        set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ${CCACHE})
        set_property(GLOBAL PROPERTY RULE_LAUNCH_LINK ${CCACHE})
    else()
        message(WARNING "USE_CCACHE set, but could not find ccache")
    endif()
endif()

set(_target_name linuxdeploy-plugin-appimage)

# Clang does not support -static-libstdc++ and -static-libgcc, but just -static
# is enough to link everything statically. We check for these flags and only
# use them if they're supported.
include(CheckCXXCompilerFlag)
check_cxx_compiler_flag(-static-libstdc++ STATIC_LIBSTDCXX_SUPPORTED)
check_cxx_compiler_flag(-static-libgcc STATIC_LIBGCC_SUPPORTED)

# main executable
add_executable(${_target_name} main.cpp)

target_link_libraries(${_target_name} args)

set(_cflags
    -static
    -flto
)
if(STATIC_LIBSTDCXX_SUPPORTED)
    list(APPEND _cflags -static-libstdc++)
endif()
if(STATIC_LIBGCC_SUPPORTED)
    list(APPEND _cflags -static-libgcc)
endif()
target_compile_options(${_target_name} PUBLIC ${_cflags})
target_link_options(${_target_name} PUBLIC ${_cflags})

install(
    TARGETS ${_target_name}
    RUNTIME DESTINATION bin
)
