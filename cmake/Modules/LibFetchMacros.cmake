cmake_minimum_required(VERSION 3.15)
include(FetchContent)

# Simple function to abstract fetching a dependency from Git.
# It produces similar output as what libfind_pkg_detect would return:
# - ${PREFIX}_VERSION
# - ${PREFIX}_INCLUDE_DIRS
# - ${PREFIX}_FOUND
# The following attribute are required:
# - PREFIX
# - REPOSITORY <address>: the git repository address
# - REFERENCE <reference>: a git reference for this repository (tag, branch, or hash)
# The following attributes are optional:
# - FIND_PATH <header path>: the path of a file that should be located.
# Eg: libfetch_git_pkg(Json NAME json REPOSITORY https://github.com/performous/json.git REFERENCE master FIND_PATH json/json.hpp)
function (libfetch_git_pkg PREFIX)
	# parse arguments
	set(argname pkgargs)
	foreach(i ${ARGN})
		if ("${i}" STREQUAL "REPOSITORY")
			set(argname pkgrepository)
		elseif ("${i}" STREQUAL "FIND_PATH")
			set(argname pkgfindpath)
		elseif ("${i}" STREQUAL "REFERENCE")
			set(argname pkgreference)
		else ()
			set(${argname} ${${argname}} ${i})
		endif()
	endforeach()

	string(TOLOWER ${PREFIX}-src pkgname)

	if (NOT pkgrepository OR NOT pkgreference)
		message(FATAL_ERROR "libfetch_git_pkg requires attributes REPOSITORY and REFERENCE.")
	endif()
	if (pkgargs)
		message(FATAL_ERROR "libfetch_git_pkg requires no extra parameter.")
	endif()

	message(STATUS "Fetching and making available ${pkgname}...")


	set(${PREFIX}_VERSION ${pkgreference} PARENT_SCOPE)

	FetchContent_Declare(${pkgname}
		GIT_REPOSITORY ${pkgrepository}
		GIT_SHALLOW    TRUE
		GIT_TAG        ${pkgreference}
		SOURCE_DIR     ${pkgname}-src
	)

	FetchContent_GetProperties(${pkgname})
	if (NOT ${pkgname}_POPULATED)
		FetchContent_Populate(${pkgname})
	endif()

	# Aubio fork currently hard-requires MODULE mode FFTW lookup.
	# Patch before add_subdirectory so subproject configure does not fail.
	if (PREFIX STREQUAL "Aubio")
		set(_aubio_cmake "${${pkgname}_SOURCE_DIR}/CMakeLists.txt")
		if (EXISTS "${_aubio_cmake}")
			file(READ "${_aubio_cmake}" _aubio_contents)
			set(_aubio_patch [=[find_package(PkgConfig REQUIRED)
pkg_check_modules(FFTW3 REQUIRED fftw3f)
set(FFTW3F_LIBRARY "${FFTW3_LIBRARIES}")
set(FFTW3_INCLUDE_DIR "${FFTW3_INCLUDE_DIRS}")]=])
			string(REPLACE "find_package(FFTW3 COMPONENTS single REQUIRED MODULE)" "${_aubio_patch}" _aubio_patched "${_aubio_contents}")
			if (NOT _aubio_patched STREQUAL _aubio_contents)
				file(WRITE "${_aubio_cmake}" "${_aubio_patched}")
				message(STATUS "Patched aubio FFTW discovery in ${_aubio_cmake}")
			endif()
		endif()
	endif()

	add_subdirectory("${${pkgname}_SOURCE_DIR}" "${${pkgname}_BINARY_DIR}" EXCLUDE_FROM_ALL)

	if (pkgfindpath)
		find_path(${PREFIX}_INCLUDE_DIR NAMES ${pkgfindpath} HINTS ${${pkgname}_SOURCE_DIR} ${${pkgname}_SOURCE_DIR}/include)
		set(${PREFIX}_INCLUDE_DIRS ${${PREFIX}_INCLUDE_DIR} PARENT_SCOPE)
	else()
		set(${PREFIX}_INCLUDE_DIRS ${${pkgname}_SOURCE_DIR}/include/ PARENT_SCOPE)
	endif()
	set(${PREFIX}_FOUND TRUE PARENT_SCOPE)
endfunction ()
