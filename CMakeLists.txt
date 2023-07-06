cmake_minimum_required(VERSION 3.0)
project(linuxdeploy-plugin-appimage)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# can be enabled globally, we do not expose any libraries
set(flags "-Wall -Wextra -Werror")
mark_as_advanced(flags)
set(CMAKE_C_FLAGS ${flags})
set(CMAKE_CXX_FLAGS ${flags})

add_subdirectory(lib)

add_subdirectory(src)
