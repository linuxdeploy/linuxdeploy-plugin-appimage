cmake_minimum_required(VERSION 3.0)
project(linuxdeploy-plugin-appimage)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_subdirectory(lib)

add_subdirectory(src)
