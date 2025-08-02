# - Try to find WebP
# Once done, this will define
#
#  WebP_FOUND - system has WebP
#  WebP_INCLUDE_DIRS - the WebP include directories
#  WebP_LIBRARIES - link these to use WebP
#  WebP_VERSION - version of WebP found

# First try to use the native CMake config if available
find_package(WebP CONFIG QUIET)

if(WebP_FOUND)
    # Native CMake config found, but it may have issues on some systems
    # Fix the variables if they're not properly set
    if(NOT WebP_INCLUDE_DIRS)
        set(WebP_INCLUDE_DIRS ${WebP_INCLUDE_DIR})
    endif()
    
    # Convert target names to actual library paths if needed
    if(WebP_LIBRARIES MATCHES "^webp")
        # Libraries are target names, convert to actual paths
        find_library(WebP_LIBRARY_PATH NAMES webp)
        find_library(WebP_DEMUX_LIBRARY_PATH NAMES webpdemux)
        find_library(WebP_MUX_LIBRARY_PATH NAMES webpmux)
        find_library(WebP_DECODER_LIBRARY_PATH NAMES webpdecoder)
        
        set(WebP_LIBRARIES "")
        foreach(lib WebP_LIBRARY_PATH WebP_DEMUX_LIBRARY_PATH WebP_MUX_LIBRARY_PATH WebP_DECODER_LIBRARY_PATH)
            if(${lib})
                list(APPEND WebP_LIBRARIES ${${lib}})
            endif()
        endforeach()
    endif()
    
    # Set WEBP_* variables for compatibility
    set(WEBP_FOUND ${WebP_FOUND})
    set(WEBP_VERSION ${WebP_VERSION})
    set(WEBP_INCLUDE_DIRS ${WebP_INCLUDE_DIRS})
    set(WEBP_LIBRARIES ${WebP_LIBRARIES})
    
    message(STATUS "Found WebP ${WebP_VERSION} (using native CMake config)")
    return()
endif()

# Fall back to custom finder using LibFindMacros
include(LibFindMacros)

# Use pkg-config to get hints about paths (try multiple package names)
libfind_pkg_check_modules(WebP_PKGCONF libwebp)

# If main pkg-config fails, try individual components
if(NOT WebP_PKGCONF_FOUND)
  libfind_pkg_check_modules(WebP_PKGCONF_ALT libwebp libwebpdemux libwebpmux)
  if(WebP_PKGCONF_ALT_FOUND)
    set(WebP_PKGCONF_LIBRARY_DIRS ${WebP_PKGCONF_ALT_LIBRARY_DIRS})
    set(WebP_PKGCONF_INCLUDE_DIRS ${WebP_PKGCONF_ALT_INCLUDE_DIRS})
    set(WebP_PKGCONF_VERSION ${WebP_PKGCONF_ALT_VERSION})
  endif()
endif()

# Find the main WebP library with multiple possible names
find_library(WebP_LIBRARY
  NAMES webp libwebp
  HINTS ${WebP_PKGCONF_LIBRARY_DIRS}
  PATHS 
    /usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}
    /usr/lib64
    /usr/lib
    /usr/local/lib
    /opt/local/lib
)

# Find WebP include directory with multiple search strategies
find_path(WebP_INCLUDE_DIR
  NAMES webp/encode.h webp/decode.h webp/types.h
  HINTS ${WebP_PKGCONF_INCLUDE_DIRS}
  PATHS
    /usr/include
    /usr/local/include
    /opt/local/include
)

# Alternative search if headers are directly in include dir
if(NOT WebP_INCLUDE_DIR)
  find_path(WebP_INCLUDE_DIR
    NAMES encode.h decode.h
    HINTS ${WebP_PKGCONF_INCLUDE_DIRS}
    PATHS
      /usr/include/webp
      /usr/local/include/webp
      /opt/local/include/webp
  )
  if(WebP_INCLUDE_DIR)
    # Adjust path to parent directory
    get_filename_component(WebP_INCLUDE_DIR "${WebP_INCLUDE_DIR}" DIRECTORY)
  endif()
endif()

# Find optional WebP libraries with flexible naming
find_library(WebP_DEMUX_LIBRARY
  NAMES webpdemux libwebpdemux
  HINTS ${WebP_PKGCONF_LIBRARY_DIRS}
  PATHS 
    /usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}
    /usr/lib64
    /usr/lib
    /usr/local/lib
    /opt/local/lib
)

find_library(WebP_MUX_LIBRARY
  NAMES webpmux libwebpmux
  HINTS ${WebP_PKGCONF_LIBRARY_DIRS}
  PATHS 
    /usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}
    /usr/lib64
    /usr/lib
    /usr/local/lib
    /opt/local/lib
)

# Also try to find decoder-only library (common on some systems)
find_library(WebP_DECODER_LIBRARY
  NAMES webpdecoder libwebpdecoder
  HINTS ${WebP_PKGCONF_LIBRARY_DIRS}
  PATHS 
    /usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}
    /usr/lib64
    /usr/lib
    /usr/local/lib
    /opt/local/lib
)

# Enhanced version detection with multiple fallbacks
if(WebP_PKGCONF_VERSION)
  set(WebP_VERSION ${WebP_PKGCONF_VERSION})
else()
  # Try individual package configs for version
  execute_process(
    COMMAND pkg-config --modversion libwebp
    OUTPUT_VARIABLE WebP_VERSION
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  
  if(NOT WebP_VERSION)
    # Fallback: try to get version from command line tool
    find_program(WEBP_CWEBP_EXECUTABLE NAMES cwebp)
    if(WEBP_CWEBP_EXECUTABLE)
      execute_process(
        COMMAND ${WEBP_CWEBP_EXECUTABLE} -version
        OUTPUT_VARIABLE WEBP_VERSION_OUTPUT
        ERROR_QUIET
        OUTPUT_STRIP_TRAILING_WHITESPACE
      )
      if(WEBP_VERSION_OUTPUT MATCHES "([0-9]+\\.[0-9]+\\.[0-9]+)")
        set(WebP_VERSION ${CMAKE_MATCH_1})
      endif()
    endif()
  endif()
  
  if(NOT WebP_VERSION)
    # Try to parse version from header file if available
    if(WebP_INCLUDE_DIR AND EXISTS "${WebP_INCLUDE_DIR}/webp/encode.h")
      file(READ "${WebP_INCLUDE_DIR}/webp/encode.h" WEBP_ENCODE_H)
      # Look for version in comments or defines
      if(WEBP_ENCODE_H MATCHES "version ([0-9]+\\.[0-9]+\\.[0-9]+)")
        set(WebP_VERSION ${CMAKE_MATCH_1})
      endif()
    endif()
  endif()
endif()

# Validate that we have at least the main library and headers
set(WebP_REQUIRED_VARS WebP_LIBRARY WebP_INCLUDE_DIR)

# Set up the library list for libfind_process
set(WebP_PROCESS_INCLUDES WebP_INCLUDE_DIR)
set(WebP_PROCESS_LIBS WebP_LIBRARY)

# Add optional libraries if found
if(WebP_DEMUX_LIBRARY)
  list(APPEND WebP_PROCESS_LIBS WebP_DEMUX_LIBRARY)
endif()

if(WebP_MUX_LIBRARY)
  list(APPEND WebP_PROCESS_LIBS WebP_MUX_LIBRARY)
endif()

if(WebP_DECODER_LIBRARY)
  list(APPEND WebP_PROCESS_LIBS WebP_DECODER_LIBRARY)
endif()

libfind_process(WebP)
