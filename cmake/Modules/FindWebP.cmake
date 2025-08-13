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
    if(NOT WebP_INCLUDE_DIRS AND WebP_INCLUDE_DIR)
        set(WebP_INCLUDE_DIRS ${WebP_INCLUDE_DIR})
    endif()
    
    # Convert target names to actual library paths if needed
    if(WebP_LIBRARIES AND WebP_LIBRARIES MATCHES "^webp")
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
    
    # Verify we actually have usable results
    if(WebP_INCLUDE_DIRS AND WebP_LIBRARIES)
        # Set WEBP_* variables for compatibility
        set(WEBP_FOUND ${WebP_FOUND})
        set(WEBP_VERSION ${WebP_VERSION})
        set(WEBP_INCLUDE_DIRS ${WebP_INCLUDE_DIRS})
        set(WEBP_LIBRARIES ${WebP_LIBRARIES})
        
        message(STATUS "Found WebP ${WebP_VERSION} (using native CMake config)")
        return()
    else()
        # Native config didn't provide usable results, fall back to custom finder
        message(STATUS "WebP native CMake config found but incomplete, falling back to custom finder")
        unset(WebP_FOUND)
    endif()
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

# Find the main WebP library with multiple possible names and versions
# In Docker/Ubuntu 22.04, CMAKE_LIBRARY_ARCHITECTURE might not be set properly
if(NOT CMAKE_LIBRARY_ARCHITECTURE)
    # Detect architecture for library paths
    execute_process(
        COMMAND dpkg-architecture -qDEB_HOST_MULTIARCH
        OUTPUT_VARIABLE DETECTED_ARCH
        ERROR_QUIET
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if(DETECTED_ARCH)
        set(CMAKE_LIBRARY_ARCHITECTURE ${DETECTED_ARCH})
    endif()
endif()

find_library(WebP_LIBRARY
  NAMES webp libwebp webp7 libwebp7 webp6 libwebp6
  HINTS ${WebP_PKGCONF_LIBRARY_DIRS}
  PATHS 
    /usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}
    /usr/lib/x86_64-linux-gnu
    /usr/lib/aarch64-linux-gnu 
    /usr/lib/arm-linux-gnueabihf
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

# Verify we can find at least basic WebP functionality
if(WebP_INCLUDE_DIR AND EXISTS "${WebP_INCLUDE_DIR}/webp/decode.h")
  set(WebP_BASIC_FOUND TRUE)
elseif(WebP_INCLUDE_DIR AND EXISTS "${WebP_INCLUDE_DIR}/decode.h")
  set(WebP_BASIC_FOUND TRUE)
else()
  set(WebP_BASIC_FOUND FALSE)
endif()

# Find optional WebP libraries with flexible naming (these may not exist in older versions)
find_library(WebP_DEMUX_LIBRARY
  NAMES webpdemux libwebpdemux webpdemux2 libwebpdemux2 webpdemux1 libwebpdemux1
  HINTS ${WebP_PKGCONF_LIBRARY_DIRS}
  PATHS 
    /usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}
    /usr/lib/x86_64-linux-gnu
    /usr/lib/aarch64-linux-gnu 
    /usr/lib/arm-linux-gnueabihf
    /usr/lib64
    /usr/lib
    /usr/local/lib
    /opt/local/lib
)

find_library(WebP_MUX_LIBRARY
  NAMES webpmux libwebpmux webpmux3 libwebpmux3 webpmux2 libwebpmux2 webpmux1 libwebpmux1
  HINTS ${WebP_PKGCONF_LIBRARY_DIRS}
  PATHS 
    /usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}
    /usr/lib/x86_64-linux-gnu
    /usr/lib/aarch64-linux-gnu 
    /usr/lib/arm-linux-gnueabihf
    /usr/lib64
    /usr/lib
    /usr/local/lib
    /opt/local/lib
)

# Also try to find decoder-only library (common on some systems, may have version numbers)
find_library(WebP_DECODER_LIBRARY
  NAMES webpdecoder libwebpdecoder webpdecoder3 libwebpdecoder3 webpdecoder2 libwebpdecoder2 webpdecoder1 libwebpdecoder1
  HINTS ${WebP_PKGCONF_LIBRARY_DIRS}
  PATHS 
    /usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}
    /usr/lib/x86_64-linux-gnu
    /usr/lib/aarch64-linux-gnu 
    /usr/lib/arm-linux-gnueabihf
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
  
  # If we still don't have a version, try to infer from library names
  if(NOT WebP_VERSION AND WebP_LIBRARY)
    get_filename_component(WebP_LIB_NAME "${WebP_LIBRARY}" NAME_WE)
    if(WebP_LIB_NAME MATCHES "libwebp([0-9]+)")
      set(WebP_VERSION_MAJOR ${CMAKE_MATCH_1})
      # Make a reasonable guess for common versions
      if(WebP_VERSION_MAJOR EQUAL "6")
        set(WebP_VERSION "0.6.1")  # Common version for libwebp6
      elseif(WebP_VERSION_MAJOR EQUAL "7")
        set(WebP_VERSION "1.0.0")  # Common version for libwebp7
      endif()
    endif()
  endif()
endif()

# Check version compatibility if we have it
if(WebP_VERSION)
  # Check if this is a very old version that might have limited functionality
  if(WebP_VERSION VERSION_LESS "0.4.0")
    message(WARNING "WebP version ${WebP_VERSION} is very old. Some features may not be available.")
  endif()
endif()

# Validate that we have at least the main library and headers
# For older versions, we may only have basic functionality
if(WebP_LIBRARY AND WebP_BASIC_FOUND)
  set(WebP_CORE_FOUND TRUE)
else()
  set(WebP_CORE_FOUND FALSE)
endif()

# Set up the library list for libfind_process
set(WebP_PROCESS_INCLUDES WebP_INCLUDE_DIR)
set(WebP_PROCESS_LIBS WebP_LIBRARY)

# Debug output for troubleshooting (only when not quiet)
if(NOT DEFINED WebP_FIND_QUIETLY)
    message(STATUS "WebP Debug: CMAKE_LIBRARY_ARCHITECTURE = '${CMAKE_LIBRARY_ARCHITECTURE}'")
    message(STATUS "WebP Debug: WebP_LIBRARY = '${WebP_LIBRARY}'")
    message(STATUS "WebP Debug: WebP_INCLUDE_DIR = '${WebP_INCLUDE_DIR}'")
    message(STATUS "WebP Debug: WebP_PKGCONF_FOUND = '${WebP_PKGCONF_FOUND}'")
    message(STATUS "WebP Debug: WebP_PKGCONF_LIBRARY_DIRS = '${WebP_PKGCONF_LIBRARY_DIRS}'")
    message(STATUS "WebP Debug: WebP_PKGCONF_INCLUDE_DIRS = '${WebP_PKGCONF_INCLUDE_DIRS}'")
    message(STATUS "WebP Debug: WebP_BASIC_FOUND = '${WebP_BASIC_FOUND}'")
    message(STATUS "WebP Debug: WebP_CORE_FOUND = '${WebP_CORE_FOUND}'")
    
    # Show which paths were searched for libraries
    get_property(LIB_SEARCH_PATHS GLOBAL PROPERTY FIND_LIBRARY_USE_LIB64_PATHS)
    message(STATUS "WebP Debug: FIND_LIBRARY_USE_LIB64_PATHS = '${LIB_SEARCH_PATHS}'")
    
    # Show search paths being used
    message(STATUS "WebP Debug: Library search paths:")
    foreach(path "/usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}" "/usr/lib/x86_64-linux-gnu" "/usr/lib64" "/usr/lib")
        if(EXISTS "${path}")
            message(STATUS "  ${path} - EXISTS")
        else()
            message(STATUS "  ${path} - NOT FOUND")
        endif()
    endforeach()
    
    # Show which WebP libraries exist
    message(STATUS "WebP Debug: Checking for WebP library files:")
    foreach(libname webp libwebp webp7 libwebp7 webp6 libwebp6)
        foreach(path "/usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}" "/usr/lib/x86_64-linux-gnu" "/usr/lib")
            if(EXISTS "${path}/lib${libname}.so")
                message(STATUS "  Found: ${path}/lib${libname}.so")
            endif()
        endforeach()
    endforeach()
endif()

# Add optional libraries if found (these may not exist in older versions)
if(WebP_DEMUX_LIBRARY)
  list(APPEND WebP_PROCESS_LIBS WebP_DEMUX_LIBRARY)
  if(NOT DEFINED WebP_FIND_QUIETLY)
    message(STATUS "WebP: Found demux library")
  endif()
endif()

if(WebP_MUX_LIBRARY)
  list(APPEND WebP_PROCESS_LIBS WebP_MUX_LIBRARY)
  if(NOT DEFINED WebP_FIND_QUIETLY)
    message(STATUS "WebP: Found mux library")
  endif()
endif()

if(WebP_DECODER_LIBRARY)
  list(APPEND WebP_PROCESS_LIBS WebP_DECODER_LIBRARY)
  if(NOT DEFINED WebP_FIND_QUIETLY)
    message(STATUS "WebP: Found decoder library")
  endif()
endif()

# Warn about missing optional libraries for older versions
if(NOT WebP_DEMUX_LIBRARY AND NOT DEFINED WebP_FIND_QUIETLY)
  message(STATUS "WebP: Demux library not found (may not be available in older versions)")
endif()
if(NOT WebP_MUX_LIBRARY AND NOT DEFINED WebP_FIND_QUIETLY)
  message(STATUS "WebP: Mux library not found (may not be available in older versions)")
endif()

libfind_process(WebP)
