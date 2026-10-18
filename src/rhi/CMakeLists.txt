target_sources(SRB2SDL2 PRIVATE
	handle.hpp
	rhi.cpp
	rhi.hpp
	shader_load_context.cpp
	shader_load_context.hpp
)

if(ANDROID OR SRB2_CONFIG_GLES2)
	add_subdirectory(gles2)
else()
	add_subdirectory(gl2)
endif()
