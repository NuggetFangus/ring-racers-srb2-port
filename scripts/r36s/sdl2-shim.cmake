# O SDL2 do Debian 10 (2.0.9) não define o alvo importado SDL2::SDL2 que o
# projeto espera. Este arquivo (carregado via CMAKE_PROJECT_INCLUDE, logo após
# project()) cria o alvo a partir do pkg-config.
find_package(PkgConfig REQUIRED)
pkg_check_modules(SDL2PC REQUIRED IMPORTED_TARGET GLOBAL sdl2)

if(NOT TARGET SDL2::SDL2)
	add_library(SDL2::SDL2 INTERFACE IMPORTED GLOBAL)
	target_link_libraries(SDL2::SDL2 INTERFACE PkgConfig::SDL2PC)
endif()
