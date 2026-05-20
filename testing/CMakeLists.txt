cmake_minimum_required(VERSION 3.24)
include(GoogleTest)

set(SOURCE_FILES
	"analyzertest.cc"
	"colortest.cc"
	"configitemtest.cc"
	"cycletest.cc"
	"fixednotegraphscalertest.cc"
	"microphones_test.cc"
	"notegraphscalerfactorytest.cc"
	"ringbuffertest.cc"
	"utiltest.cc"
	"imagetypetest.cc"

	"main.cc"
	"printer.cc"
)
set(GAME_SOURCES
	"../game/analyzer.cc"
	"../game/color.cc"
	"../game/configitem.cc"
	"../game/dynamicnotegraphscaler.cc"
	"../game/execname.cc"
	"../game/fixednotegraphscaler.cc"
	"../game/fs.cc"
	"../game/image.cc"
	"../game/log.cc"
	"../game/microphones.cc"
	"../game/musicalscale.cc"
	"../game/notes.cc"
	"../game/notegraphscalerfactory.cc"
	"../game/platform.cc"
	"../game/tone.cc"
	"../game/util.cc"
)

set(GTEST_REQUIRED "")

if(BUILD_TESTS STREQUAL "ON")
	set(GTEST_REQUIRED "REQUIRED")
endif()

find_package(GTest ${GTEST_REQUIRED})

if(GTest_FOUND)
	message(STATUS "Testing enabled: Building test host")

	set(SOURCES ${SOURCE_FILES} ${HEADER_FILES} ${GAME_SOURCES})
	
	add_executable(performous_test ${SOURCES})

	find_package(Boost 1.55 REQUIRED COMPONENTS program_options iostreams system locale)

	set(PERFORMOUS_TEST_BOOST_LINK_LIBS Boost::iostreams Boost::program_options Boost::locale)
	if(TARGET Boost::boost)
		list(APPEND PERFORMOUS_TEST_BOOST_LINK_LIBS Boost::boost)
	elseif(TARGET Boost::headers)
		list(APPEND PERFORMOUS_TEST_BOOST_LINK_LIBS Boost::headers)
	endif()

	if(TARGET Boost::system)
		list(APPEND PERFORMOUS_TEST_BOOST_LINK_LIBS Boost::system)
	else()
		message(STATUS "Boost::system target not found; using header-only Boost.System for tests")
		target_compile_definitions(performous_test PRIVATE BOOST_ERROR_CODE_HEADER_ONLY)
	endif()

	target_link_libraries(performous_test PRIVATE ${PERFORMOUS_TEST_BOOST_LINK_LIBS})

	# CppRESTSDK and their godforsaken U macro.
	target_compile_definitions(performous_test PRIVATE -D_TURN_OFF_PLATFORM_STRING)

	find_package(ICU 65 REQUIRED uc data i18n io)
	target_link_libraries(performous_test PRIVATE ICU::uc ICU::data ICU::i18n ICU::io)


	set(SPDLOG_TARGET spdlog::spdlog)
	if(NOT TARGET ${SPDLOG_TARGET})
		set(SPDLOG_TARGET spdlog::spdlog_header_only)
	endif()
	if(NOT TARGET ${SPDLOG_TARGET})
		message(FATAL_ERROR "spdlog target not available. Expected spdlog::spdlog_header_only or spdlog::spdlog")
	endif()
	find_package(PkgConfig REQUIRED)

	target_link_libraries(performous_test PRIVATE GTest::gtest GTest::gtest_main GTest::gmock)

	target_link_libraries(performous_test PRIVATE ${SPDLOG_TARGET})

	target_include_directories(performous_test PRIVATE ".." "../game" "${Performous_BINARY_DIR}/game")

	if(WIN32 AND MSVC)
#		target_compile_options(performous_test PUBLIC /WX)
	else()
		target_compile_options(performous_test PUBLIC -Werror)
	endif()
	
	find_package(SDL2 REQUIRED)
	if (TARGET SDL2::SDL2)
		target_link_libraries(performous_test PRIVATE SDL2::SDL2)
	else()
		list(REMOVE_ITEM SDL2_LIBRARIES SDL2::SDL2main)
		target_link_libraries(performous_test PRIVATE ${SDL2_LIBRARIES})
	endif()
	target_include_directories(performous_test PRIVATE ${SDL2_INCLUDE_DIRS}) # Newer SDL versions have proper CMake targets making this unnecessary, but we can't take it for granted.

	if(APPLE)
	target_link_libraries(performous_test PRIVATE "-framework CoreFoundation")
	endif()

	gtest_discover_tests(performous_test PROPERTIES TEST_DISCOVERY_TIMEOUT 30)

	pkg_check_modules(WEBP REQUIRED IMPORTED_TARGET libwebp)
	message(STATUS "WebP found via pkg-config: ${WEBP_VERSION}")
	target_link_libraries(performous_test PRIVATE PkgConfig::WEBP)
	if(WEBP_CFLAGS_OTHER)
		target_compile_options(performous_test PRIVATE ${WEBP_CFLAGS_OTHER})
	endif()

	pkg_check_modules(PANGOCAIRO REQUIRED IMPORTED_TARGET pangocairo)
	message(STATUS "PangoCairo found via pkg-config: ${PANGOCAIRO_VERSION}")
	target_link_libraries(performous_test PRIVATE PkgConfig::PANGOCAIRO)
	if(PANGOCAIRO_CFLAGS_OTHER)
		target_compile_options(performous_test PRIVATE ${PANGOCAIRO_CFLAGS_OTHER})
	endif()

	pkg_check_modules(LIBRSVG REQUIRED IMPORTED_TARGET librsvg-2.0)
	message(STATUS "LibRSVG found via pkg-config: ${LIBRSVG_VERSION}")
	target_link_libraries(performous_test PRIVATE PkgConfig::LIBRSVG)
	if(LIBRSVG_CFLAGS_OTHER)
		target_compile_options(performous_test PRIVATE ${LIBRSVG_CFLAGS_OTHER})
	endif()

	# Image formats
	foreach(lib ZLIB JPEG PNG)
		find_package(${lib} ${${lib}_REQUIRED_VERSION} REQUIRED)
		message(STATUS "${lib} includes: ${${lib}_INCLUDE_DIRS}")
		target_include_directories(performous_test SYSTEM PRIVATE ${${lib}_INCLUDE_DIRS})
		target_link_libraries(performous_test PRIVATE ${${lib}_LIBRARIES})
	endforeach(lib)


else()
	message(STATUS "Testing disabled: Package gtest missing")
endif()
