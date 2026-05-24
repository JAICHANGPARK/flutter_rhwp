# The Flutter tooling requires a Visual Studio install with CMake 3.14 or later.
cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "flutter_rhwp")
project(${PROJECT_NAME} LANGUAGES CXX)

include("../cargokit/cmake/cargokit.cmake")
apply_cargokit(${PROJECT_NAME} ../rust flutter_rhwp "")

set(flutter_rhwp_bundled_libraries
  "${${PROJECT_NAME}_cargokit_lib}"
  PARENT_SCOPE
)
