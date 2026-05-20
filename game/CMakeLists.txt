cmake_minimum_required(VERSION 3.15)

file(GLOB SOURCE_FILES
	"*.cc"
	"graphic/*.cc"
	"songorder/*.cc"
	"utils/*.cc"
)
file(GLOB HEADER_FILES
	"*.hh"
	"graphic/*.hh"
	"songorder/*.hh"
	"utils/*.hh"
	"libda/*.hpp"
)

if(WIN32)
	# We want to support all these version numbers:
	# 1.0 1.0.1 1.0+ 1.0.1+ 1.0-2-g123abcd 1.0.1-5-g123abcd
	# We use the 2-3 digits of the version as MAJOR.MINOR.PATCH
	# and the git patch number as TWEAK
	set(SUBSYSTEM_WIN32 WIN32)
	if (DEFINED CMAKE_SOURCE_DIR)
		if(DEFINED ENV{ORIGINAL_TEMP})
			set (TMP_LOCATION $ENV{ORIGINAL_TEMP})
		elseif(DEFINED ENV{TEMP})
			set (TMP_LOCATION $ENV{TEMP})
		else()
			message(WARNING "Temp folder not found. CPack won't be able to create a proper installer.")
		endif()
		file(WRITE "${TMP_LOCATION}/source.txt" "${CMAKE_SOURCE_DIR}")
		file(WRITE "${TMP_LOCATION}/mingwroot.txt" "${CPACK_MINGW_SYSTEM_PREFIX}")
	endif()
	string(REGEX REPLACE "\\." ";"  VERSIONING ${PROJECT_VERSION})
	list(GET VERSIONING -1 LAST_ENTRY)
	list(REMOVE_AT VERSIONING -1)
	string(REGEX REPLACE "^([0-9]+)(.*)$" "\\1;\\2"  LAST_ENTRIES ${LAST_ENTRY})
	list(GET LAST_ENTRIES 0 LAST_ENTRY_NUM)
	list(GET LAST_ENTRIES 1 LAST_ENTRY_ADD)
	list(APPEND VERSIONING ${LAST_ENTRY_NUM})

	list(GET VERSIONING 0 VERSION_MAJOR)
	list(LENGTH VERSIONING VERSION_LENGTH)
	if(VERSION_LENGTH GREATER 1)
		list(GET VERSIONING 1 VERSION_MINOR)
	endif()
	if(VERSION_LENGTH GREATER 2)
		list(GET VERSIONING 2 VERSION_PATCH)
	endif()

	string(REGEX REPLACE "^-([0-9]+)-.*$" "\\1" VERSION_TWEAK "${LAST_ENTRY_ADD}")

	set(VERSIONS "MAJOR" "MINOR" "PATCH" "TWEAK")
	foreach(v ${VERSIONS})
		if(NOT VERSION_${v} MATCHES "^[0-9]+$")
			set(VERSION_${v} "0")
		endif()
	endforeach()
	message(STATUS "Setting .exe version: ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}.${VERSION_TWEAK}")

	set(RESOURCE_FILES "${CMAKE_BINARY_DIR}/performous.rc")
	configure_file("../win32/performous.cmake.rc" "${RESOURCE_FILES}")

	if(MINGW)
		# According to MinGW tools, we need to compile the rc file, and then link it into projects:
		# windres foo.rc foores.o
		# gcc -o foo.exe foo.o foores.o
		if(NOT CMAKE_RC_COMPILER)
			find_program(CMAKE_RC_COMPILER "${CPACK_MINGW_SYSTEM_PREFIX}/bin/windres")
		endif()
		if(NOT CMAKE_RC_COMPILER)
			message(STATUS "Cannot find windres. Will not create a versioned exe.")
			set(RESOURCE_FILES)
		else()
			set(CMAKE_RC_COMPILE_OBJECT "<CMAKE_RC_COMPILER> <FLAGS> -O coff <DEFINES> -i <SOURCE> -o <OBJECT>")
		endif()
	endif()
else()
	set(RESOURCE_FILES) #nothing
endif()

set(SOURCES ${SOURCE_FILES} ${HEADER_FILES} ${RESOURCE_FILES})

# Build main executable
add_executable(performous ${SUBSYSTEM_WIN32} ${SOURCES})
# Libraries

find_package(Boost 1.55 CONFIG QUIET COMPONENTS program_options iostreams system locale)
if(NOT Boost_FOUND)
  find_package(Boost 1.55 REQUIRED COMPONENTS program_options iostreams system locale)
endif()

set(PERFORMOUS_BOOST_LINK_LIBS Boost::program_options Boost::iostreams Boost::locale)
if(TARGET Boost::boost)
	list(APPEND PERFORMOUS_BOOST_LINK_LIBS Boost::boost)
elseif(TARGET Boost::headers)
	list(APPEND PERFORMOUS_BOOST_LINK_LIBS Boost::headers)
endif()

if(TARGET Boost::system)
	list(APPEND PERFORMOUS_BOOST_LINK_LIBS Boost::system)
else()
	message(STATUS "Boost::system target not found; using header-only Boost.System")
	target_compile_definitions(performous PRIVATE BOOST_ERROR_CODE_HEADER_ONLY)
endif()

target_link_libraries(performous PRIVATE ${PERFORMOUS_BOOST_LINK_LIBS})

find_package(ICU 65 REQUIRED uc data i18n io)
target_link_libraries(performous PRIVATE ICU::uc ICU::data ICU::i18n ICU::io)

find_package(PkgConfig REQUIRED)
pkg_check_modules(deps REQUIRED IMPORTED_TARGET glib-2.0 gio-2.0 gobject-2.0)

# LibEpoxy < 1.2 crashes with binary drivers (nvidia & fglrx) when creating shaders
# (see https://github.com/anholt/libepoxy/issues/23 for the exact problem)
pkg_check_modules(LIBEPOXY REQUIRED IMPORTED_TARGET epoxy>=1.2)
target_link_libraries(performous PRIVATE PkgConfig::LIBEPOXY)
if(LIBEPOXY_CFLAGS_OTHER)
	target_compile_options(performous PRIVATE ${LIBEPOXY_CFLAGS_OTHER})
endif()

set(SELF_BUILT_GIT_BASE "https://github.com/performous" CACHE STRING "base path of the git trees used for self built dependencies")
set(SELF_BUILT_AUBIO "AUTO" CACHE STRING "rule to allow self build of Aubio dependency library [NEVER|AUTO*|ALWAYS]")
set(SELF_BUILT_JSON "AUTO" CACHE STRING "rule to allow self build of Json dependency library [NEVER|AUTO*|ALWAYS]")
# This is AUTO cause CED is not available on ubuntu
set(SELF_BUILT_CED "AUTO" CACHE STRING "rule to allow self build of Ced dependency library [NEVER|AUTO*|ALWAYS]")

set(Aubio_REQUIRED_VERSION "0.4.9")

# Find all the libs that don't require extra parameters

if (MINGW)
	target_link_libraries(performous PRIVATE mingw32)
endif()

set(LIBXMLPP_FOUND FALSE)
foreach(libxmlpp_pc_name libxml++-5.0 libxml++-3.0 libxml++-2.6)
	pkg_check_modules(LIBXMLPP QUIET IMPORTED_TARGET ${libxmlpp_pc_name})
	if(LIBXMLPP_FOUND)
		message(STATUS "LibXML++ found via pkg-config: ${libxmlpp_pc_name}")
		set("LibXML++_VERSION_2_6" 0)
		set("LibXML++_VERSION_3_0" 0)
		set("LibXML++_VERSION_5_0" 0)
		if(libxmlpp_pc_name STREQUAL "libxml++-5.0")
			set("LibXML++_VERSION_5_0" 1)
		elseif(libxmlpp_pc_name STREQUAL "libxml++-3.0")
			set("LibXML++_VERSION_3_0" 1)
		else()
			set("LibXML++_VERSION_2_6" 1)
		endif()
		target_link_libraries(performous PRIVATE PkgConfig::LIBXMLPP)
		break()
	endif()
endforeach()

if(NOT LIBXMLPP_FOUND)
	message(FATAL_ERROR "LibXML++ not found via pkg-config (tried libxml++-5.0, libxml++-3.0, libxml++-2.6)")
endif()

find_path(GLM_INCLUDE_DIR NAMES glm/glm.hpp REQUIRED)
message(STATUS "GLM found via header search: ${GLM_INCLUDE_DIR}")
target_include_directories(performous SYSTEM PRIVATE ${GLM_INCLUDE_DIR})

pkg_check_modules(WEBP REQUIRED IMPORTED_TARGET libwebp)
message(STATUS "WebP found via pkg-config: ${WEBP_VERSION}")
target_link_libraries(performous PRIVATE PkgConfig::WEBP)
if(WEBP_CFLAGS_OTHER)
	target_compile_options(performous PRIVATE ${WEBP_CFLAGS_OTHER})
endif()

pkg_check_modules(PORTAUDIO REQUIRED IMPORTED_TARGET portaudio-2.0)
message(STATUS "PortAudio found via pkg-config: ${PORTAUDIO_VERSION}")
target_link_libraries(performous PRIVATE PkgConfig::PORTAUDIO)
if(PORTAUDIO_CFLAGS_OTHER)
	target_compile_options(performous PRIVATE ${PORTAUDIO_CFLAGS_OTHER})
endif()

pkg_check_modules(PANGOCAIRO REQUIRED IMPORTED_TARGET pangocairo)
message(STATUS "PangoCairo found via pkg-config: ${PANGOCAIRO_VERSION}")
target_link_libraries(performous PRIVATE PkgConfig::PANGOCAIRO)
if(PANGOCAIRO_CFLAGS_OTHER)
	target_compile_options(performous PRIVATE ${PANGOCAIRO_CFLAGS_OTHER})
endif()

pkg_check_modules(LIBRSVG REQUIRED IMPORTED_TARGET librsvg-2.0)
message(STATUS "LibRSVG found via pkg-config: ${LIBRSVG_VERSION}")
target_link_libraries(performous PRIVATE PkgConfig::LIBRSVG)
if(LIBRSVG_CFLAGS_OTHER)
	target_compile_options(performous PRIVATE ${LIBRSVG_CFLAGS_OTHER})
endif()

pkg_check_modules(FONTCONFIG REQUIRED IMPORTED_TARGET fontconfig)
message(STATUS "Fontconfig found via pkg-config: ${FONTCONFIG_VERSION}")
target_link_libraries(performous PRIVATE PkgConfig::FONTCONFIG)
if(FONTCONFIG_CFLAGS_OTHER)
	target_compile_options(performous PRIVATE ${FONTCONFIG_CFLAGS_OTHER})
endif()

pkg_check_modules(AVUTIL REQUIRED IMPORTED_TARGET libavutil)
pkg_check_modules(AVCODEC REQUIRED IMPORTED_TARGET libavcodec)
pkg_check_modules(AVFORMAT REQUIRED IMPORTED_TARGET libavformat)
pkg_check_modules(SWRESAMPLE REQUIRED IMPORTED_TARGET libswresample)
pkg_check_modules(SWSCALE REQUIRED IMPORTED_TARGET libswscale)
target_link_libraries(performous PRIVATE PkgConfig::AVUTIL PkgConfig::AVCODEC PkgConfig::AVFORMAT PkgConfig::SWRESAMPLE PkgConfig::SWSCALE)

unset(AVUtil_INCLUDE)
foreach(_dir IN LISTS AVUTIL_INCLUDE_DIRS)
	foreach(_suffix libavutil ffmpeg "")
		if(_suffix STREQUAL "")
			set(_candidate "${_dir}/avutil.h")
			set(_include_name "avutil.h")
		else()
			set(_candidate "${_dir}/${_suffix}/avutil.h")
			set(_include_name "${_suffix}/avutil.h")
		endif()
		if(EXISTS "${_candidate}")
			set(AVUtil_INCLUDE "${_include_name}")
			break()
		endif()
	endforeach()
	if(AVUtil_INCLUDE)
		break()
	endif()
endforeach()
if(NOT AVUtil_INCLUDE)
	message(FATAL_ERROR "Unable to locate avutil.h in pkg-config include dirs")
endif()

unset(AVCodec_INCLUDE)
foreach(_dir IN LISTS AVCODEC_INCLUDE_DIRS)
	foreach(_suffix libavcodec ffmpeg "")
		if(_suffix STREQUAL "")
			set(_candidate "${_dir}/avcodec.h")
			set(_include_name "avcodec.h")
		else()
			set(_candidate "${_dir}/${_suffix}/avcodec.h")
			set(_include_name "${_suffix}/avcodec.h")
		endif()
		if(EXISTS "${_candidate}")
			set(AVCodec_INCLUDE "${_include_name}")
			break()
		endif()
	endforeach()
	if(AVCodec_INCLUDE)
		break()
	endif()
endforeach()
if(NOT AVCodec_INCLUDE)
	message(FATAL_ERROR "Unable to locate avcodec.h in pkg-config include dirs")
endif()

unset(AVFormat_INCLUDE)
foreach(_dir IN LISTS AVFORMAT_INCLUDE_DIRS)
	foreach(_suffix libavformat ffmpeg "")
		if(_suffix STREQUAL "")
			set(_candidate "${_dir}/avformat.h")
			set(_include_name "avformat.h")
		else()
			set(_candidate "${_dir}/${_suffix}/avformat.h")
			set(_include_name "${_suffix}/avformat.h")
		endif()
		if(EXISTS "${_candidate}")
			set(AVFormat_INCLUDE "${_include_name}")
			break()
		endif()
	endforeach()
	if(AVFormat_INCLUDE)
		break()
	endif()
endforeach()
if(NOT AVFormat_INCLUDE)
	message(FATAL_ERROR "Unable to locate avformat.h in pkg-config include dirs")
endif()

unset(SWResample_INCLUDE)
foreach(_dir IN LISTS SWRESAMPLE_INCLUDE_DIRS)
	foreach(_suffix libswresample ffmpeg "")
		if(_suffix STREQUAL "")
			set(_candidate "${_dir}/swresample.h")
			set(_include_name "swresample.h")
		else()
			set(_candidate "${_dir}/${_suffix}/swresample.h")
			set(_include_name "${_suffix}/swresample.h")
		endif()
		if(EXISTS "${_candidate}")
			set(SWResample_INCLUDE "${_include_name}")
			break()
		endif()
	endforeach()
	if(SWResample_INCLUDE)
		break()
	endif()
endforeach()
if(NOT SWResample_INCLUDE)
	message(FATAL_ERROR "Unable to locate swresample.h in pkg-config include dirs")
endif()

unset(SWScale_INCLUDE)
foreach(_dir IN LISTS SWSCALE_INCLUDE_DIRS)
	foreach(_suffix libswscale ffmpeg "")
		if(_suffix STREQUAL "")
			set(_candidate "${_dir}/swscale.h")
			set(_include_name "swscale.h")
		else()
			set(_candidate "${_dir}/${_suffix}/swscale.h")
			set(_include_name "${_suffix}/swscale.h")
		endif()
		if(EXISTS "${_candidate}")
			set(SWScale_INCLUDE "${_include_name}")
			break()
		endif()
	endforeach()
	if(SWScale_INCLUDE)
		break()
	endif()
endforeach()
if(NOT SWScale_INCLUDE)
	message(FATAL_ERROR "Unable to locate swscale.h in pkg-config include dirs")
endif()

pkg_check_modules(FFTW3 REQUIRED IMPORTED_TARGET fftw3)
target_link_libraries(performous PRIVATE PkgConfig::FFTW3)

# Aubio uses single-precision FFTW. Ensure we have an explicit imported target
# so MSVC can resolve transitive static-library dependencies reliably.
pkg_check_modules(FFTW3F QUIET IMPORTED_TARGET fftw3f)

foreach(lib SDL2 ZLIB JPEG PNG Json Ced Aubio)
	find_package(${lib} ${${lib}_REQUIRED_VERSION} REQUIRED)
	message(STATUS "${lib} includes: ${${lib}_INCLUDE_DIRS}")
	target_include_directories(performous SYSTEM PRIVATE ${${lib}_INCLUDE_DIRS})
	target_link_libraries(performous PRIVATE ${${lib}_LIBRARIES})
	if(${lib}_DEFINITIONS)
		target_compile_options(performous PRIVATE ${${lib}_DEFINITIONS})
	endif()
endforeach(lib)

# On Windows with MSVC, aubio is built as a static library.  The fftw3f (single-precision)
# symbols it references must be resolved at the performous.exe link step.  CMake's
# INTERFACE_LINK_DIRECTORIES do not reliably propagate through the static-lib → exe
# boundary on MSVC, so we pull PkgConfig::FFTW3F in directly here.
if(WIN32 AND TARGET PkgConfig::FFTW3F)
	target_link_libraries(performous PRIVATE PkgConfig::FFTW3F)
endif()

# CppRESTSDK and their godforsaken U macro.
target_compile_definitions(performous PRIVATE _TURN_OFF_PLATFORM_STRING)

set(SPDLOG_TARGET spdlog::spdlog)
if(NOT TARGET ${SPDLOG_TARGET})
	set(SPDLOG_TARGET spdlog::spdlog_header_only)
endif()
if(NOT TARGET ${SPDLOG_TARGET})
	message(FATAL_ERROR "spdlog target not available. Expected spdlog::spdlog_header_only or spdlog::spdlog")
endif()

target_link_libraries(performous PRIVATE ${SPDLOG_TARGET})

# Activating MIDI hardware (e-drums with USB/MIDI connection)
set(ENABLE_MIDI AUTO CACHE STRING "Use midi hardware (e-drums with USB/MIDI connection)")
set_property(CACHE ENABLE_MIDI PROPERTY STRINGS AUTO ON OFF)
if("AUTO" STREQUAL "${ENABLE_MIDI}")
	# Midi support not requested explicitly, best effort try to find it
	pkg_check_modules(PORTMIDI QUIET IMPORTED_TARGET portmidi)
	if(PORTMIDI_FOUND)
		message(STATUS "MIDI I/O support: Enabled (automatically found)")
	else()
		message(STATUS "MIDI I/O support: Disabled (libportmidi not found)")
	endif()
elseif(ENABLE_MIDI)
	# Midi support explicitly requested, make it mandatory
	pkg_check_modules(PORTMIDI REQUIRED IMPORTED_TARGET portmidi)
	message(STATUS "MIDI I/O support: Enabled (explicitly enabled)")
else()
	# Midi support explicitly disabled
	message(STATUS "MIDI I/O support: Disabled (explicitly disabled)")
endif()

if(PORTMIDI_FOUND)
	target_link_libraries(performous PRIVATE PkgConfig::PORTMIDI)
	if(PORTMIDI_CFLAGS_OTHER)
		target_compile_options(performous PRIVATE ${PORTMIDI_CFLAGS_OTHER})
	endif()
	target_compile_definitions(performous PRIVATE USE_PORTMIDI)
endif()

# Activating webcam
set(ENABLE_WEBCAM AUTO CACHE STRING "Use webcam")
set_property(CACHE ENABLE_WEBCAM PROPERTY STRINGS AUTO ON OFF)
if("AUTO" STREQUAL "${ENABLE_WEBCAM}")
	# webcam support not requested explicitly, best effort try to find it
	find_package(OpenCV COMPONENTS core videoio)
	if(OPENCV_VIDEOIO_FOUND)
		message(STATUS "Webcam support: Enabled (automatically found)")
	else()
		message(STATUS "Webcam support: Disabled (OpenCV (libcv/libhighgui) not found)")
	endif()
elseif(ENABLE_WEBCAM)
	# webcam support explicitly requested, make it mandatory
	find_package(OpenCV REQUIRED core videoio)
	message(STATUS "Webcam support: Enabled (explicitly enabled)")
else()
	# webcam support explicitly disabled
	message(STATUS "Webcam support: Disabled (explicitly disabled)")
endif()

if(OPENCV_VIDEOIO_FOUND)
	target_include_directories(performous SYSTEM PRIVATE ${OpenCV_INCLUDE_DIRS})
	target_link_libraries(performous PRIVATE ${OpenCV_LIBS})
	target_compile_definitions(performous PRIVATE USE_OPENCV)
endif()

# Activating webserver
set(ENABLE_WEBSERVER AUTO CACHE STRING "Use webserver")
set_property(CACHE ENABLE_WEBSERVER PROPERTY STRINGS AUTO ON OFF)
set(PERFORMOUS_WEBSERVER_ENABLED OFF)
if("AUTO" STREQUAL "${ENABLE_WEBSERVER}")
	# webserver not requested explicitly, best effort try to find it
	find_package(cpprestsdk CONFIG QUIET)
	if(cpprestsdk_FOUND)
		message(STATUS "Webserver support: Enabled (automatically found)")
		set(PERFORMOUS_WEBSERVER_ENABLED ON)
	else()
		message(STATUS "Webserver support: Disabled (cpprestsdk not found)")
	endif()
elseif(ENABLE_WEBSERVER)
	# webserver explicitly requested, make it mandatory
	find_package(cpprestsdk CONFIG REQUIRED)
	message(STATUS "Webserver support: Enabled (explicitly enabled)")
	set(PERFORMOUS_WEBSERVER_ENABLED ON)
endif()

# if cpprestsdk is found, add it to the dependencies
if(cpprestsdk_FOUND)
	find_package(Boost 1.55 REQUIRED COMPONENTS chrono thread)
	find_package(OpenSSL REQUIRED)
	target_link_libraries(performous PRIVATE cpprestsdk::cpprest)
	target_link_libraries(performous PRIVATE Boost::boost Boost::chrono OpenSSL::SSL OpenSSL::Crypto)
	target_compile_definitions(performous PRIVATE USE_WEBSERVER)
endif()

if(WIN32)
	target_compile_definitions(performous PRIVATE EPOXY_SHARED)
	set(BIN_INSTALL .)  # Straight to Program Files/Performous with no bin subfolder.
	if(PERFORMOUS_WEBSERVER_ENABLED)
	  target_link_libraries(performous PRIVATE wsock32 ws2_32)
	endif()
elseif(APPLE)
	set(BIN_INSTALL MacOS)
else()
	set(BIN_INSTALL bin)
endif()

if(APPLE)
	list(APPEND LIBS "-framework Accelerate -framework CoreFoundation")
endif()

find_package(Threads)
target_link_libraries(performous PRIVATE ced aubio ${LIBS} PkgConfig::deps Threads::Threads)

if (NOT APPLE)
	install(TARGETS performous DESTINATION ${BIN_INSTALL})
endif()

if (APPLE AND ${CMAKE_GENERATOR} STREQUAL "Xcode")
	set(PATH "$ENV{PATH}")
	EXECUTE_PROCESS(
		COMMAND /usr/bin/defaults read -g AppleLanguages
		OUTPUT_VARIABLE PERFORMOUS_LANG
		OUTPUT_STRIP_TRAILING_WHITESPACE
	)
	string(REGEX REPLACE
	"[ \"\(\)\t\r\n]"
	""
	PERFORMOUS_LANG
	${PERFORMOUS_LANG}
	)
	string(REGEX REPLACE
	"-([A-Z][A-Z]),"
	"_\\1; "
	PERFORMOUS_LANG
	${PERFORMOUS_LANG}
	)
	set(PERFORMOUS_LANG ${PERFORMOUS_LANG})
	list(GET PERFORMOUS_LANG 0 PERFORMOUS_LANG)
	set_target_properties(performous PROPERTIES
	XCODE_SCHEME_EXECUTABLE "${CMAKE_INSTALL_FULL_BINDIR}/performous"
	XCODE_SCHEME_ARGUMENTS "--log debug"
	XCODE_SCHEME_ENVIRONMENT "FONTCONFIG_PATH=\"${CMAKE_INSTALL_SYSCONFDIR}/fonts\";
	GDK_PIXBUF_MODULE_FILE=\"\";
	LANG=\"${PERFORMOUS_LANG}.UTF-8\""
	)
endif()

set_target_properties(performous PROPERTIES INSTALL_RPATH_USE_LINK_PATH TRUE)  # Store library paths in executable
set_target_properties(performous PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})  # Produce executable in build/, not build/game/

# Capitalized Performous.exe on Windows (this is considered more beautiful).
if(WIN32)
	set_target_properties(performous PROPERTIES OUTPUT_NAME "Performous")
endif()

if(WIN32 AND MSVC)
#	target_compile_options(performous PUBLIC /WX)
else()
	target_compile_options(performous PUBLIC -Werror)
endif()

# Generate config.hh
configure_file("${CMAKE_CURRENT_SOURCE_DIR}/config.cmake.hh" "${CMAKE_CURRENT_BINARY_DIR}/config.hh" @ONLY)
target_include_directories(performous PRIVATE "${CMAKE_CURRENT_BINARY_DIR}" "${CMAKE_CURRENT_SOURCE_DIR}")

if(WIN32 AND MSVC)
	install(CODE [[
		file(GET_RUNTIME_DEPENDENCIES
			RESOLVED_DEPENDENCIES_VAR deps_resolved
			UNRESOLVED_DEPENDENCIES_VAR deps_unresolved
			EXECUTABLES $<TARGET_FILE:performous>
			PRE_EXCLUDE_REGEXES "api-ms-*" "ext-ms-*"
			POST_EXCLUDE_REGEXES ".*system32/.*\\.dll"
			)
		message(STATUS "Resolving runtime dependencies for $<TARGET_FILE:performous>")
		foreach(dep ${deps_resolved})
			file(INSTALL ${dep} DESTINATION ${CMAKE_INSTALL_PREFIX})
		endforeach()
		foreach(dep ${deps_unresolved})
			message(WARNING "Runtime dependency ${dep} could not be resolved.")
		endforeach()
		]])
elseif(MINGW)
	install(
		CODE [[
		## Hack: CPack doesn't know about the original source folder.
		if(DEFINED ENV{ORIGINAL_TEMP})
			set (TMP_LOCATION $ENV{ORIGINAL_TEMP})
		elseif(DEFINED ENV{TEMP})
			set (TMP_LOCATION $ENV{TEMP})
		else()
			message(WARNING "Temp folder not found. CPack won't be able to create a proper installer.")
		endif()
		file (READ "${TMP_LOCATION}/source.txt" CPACK_TOP_SOURCE_DIR)
		file (READ "${TMP_LOCATION}/mingwroot.txt" CPACK_MINGW_SYSTEM_PREFIX)
		execute_process(
			COMMAND "${CPACK_MINGW_SYSTEM_PREFIX}/../usr/bin/bash.exe" -l -c
			'${CPACK_TOP_SOURCE_DIR}/win32/mingw64/copydlldeps.sh --indir ${CMAKE_INSTALL_PREFIX} --destdir ${CMAKE_INSTALL_PREFIX} --recursivesrcdir ${CPACK_MINGW_SYSTEM_PREFIX} --copy --objdump ${CPACK_MINGW_SYSTEM_PREFIX}/bin/objdump.exe'
			WORKING_DIRECTORY "${CPACK_MINGW_SYSTEM_PREFIX}"
			COMMAND_ECHO STDOUT
			OUTPUT_STRIP_TRAILING_WHITESPACE
			ECHO_OUTPUT_VARIABLE
			OUTPUT_VARIABLE COMMAND_OUTPUT
			ERROR_STRIP_TRAILING_WHITESPACE
			ECHO_ERROR_VARIABLE
			ERROR_VARIABLE COMMAND_OUTPUT
		)
	file(INSTALL
		"${CPACK_MINGW_SYSTEM_PREFIX}/etc/fonts/fonts.conf"
		"${CPACK_MINGW_SYSTEM_PREFIX}/etc/fonts/conf.d"
		DESTINATION "${CMAKE_INSTALL_PREFIX}"
		)
		## Hack: add performous' fonts dir to the config.
		file(READ "${CMAKE_INSTALL_PREFIX}/fonts.conf" FILE_CONTENTS)
		string(REPLACE "<dir>WINDOWSFONTDIR</dir>" "<dir prefix='relative'>./fonts</dir>\n\t<dir>WINDOWSFONTDIR</dir>" FILE_CONTENTS "${FILE_CONTENTS}")
		file(WRITE "${CMAKE_INSTALL_PREFIX}/fonts.conf" "${FILE_CONTENTS}")
		]]
	)
endif()
