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

# main executable
add_executable(${_target_name} main.cpp)

target_link_libraries(${_target_name} args)

set(_cflags
    -static
    -static-libstdc++
    -static-libgcc
    -flto
)
target_compile_options(${_target_name} PUBLIC ${_cflags})
target_link_options(${_target_name} PUBLIC ${_cflags})

install(
    TARGETS ${_target_name}
    RUNTIME DESTINATION bin
)
