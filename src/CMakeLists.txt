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

# main executable
add_executable(linuxdeploy-plugin-appimage main.cpp)

target_link_libraries(linuxdeploy-plugin-appimage args)

install(
    TARGETS linuxdeploy-plugin-appimage
    RUNTIME DESTINATION bin
)
