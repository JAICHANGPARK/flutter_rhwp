# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. Do not increase this version unless plugin clients can follow.
cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "flutter_rhwp")
project(${PROJECT_NAME} LANGUAGES CXX)

include("../cargokit/cmake/cargokit.cmake")
apply_cargokit(${PROJECT_NAME} ../rust flutter_rhwp "")

set(flutter_rhwp_bundled_libraries
  "${${PROJECT_NAME}_cargokit_lib}"
  PARENT_SCOPE
)
