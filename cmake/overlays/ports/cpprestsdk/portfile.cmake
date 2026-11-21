vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO Microsoft/cpprestsdk
    REF 411a109150b270f23c8c97fa4ec9a0a4a98cdecf
    SHA512 4f604763f05d53e50dec5deaba283fa4f82d5e7a94c7c8142bf422f4c0bc24bcef00666ddbdd820f64c14e552997d6657b6aca79a29e69db43799961b44b2a1a
    HEAD_REF master
    PATCHES 
        fix-narrowing.patch
        fix-asio-error.patch
        fix-incomplete-json-value.patch
        remove-stdext-checked-array-iterator-1836.patch # https://github.com/microsoft/cpprestsdk/pull/1836
        remove-openprot-1844.diff # https://github.com/microsoft/cpprestsdk/pull/1844
)

vcpkg_check_features(
    OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    INVERTED_FEATURES
      brotli CPPREST_EXCLUDE_BROTLI
      compression CPPREST_EXCLUDE_COMPRESSION
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/Release"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DBUILD_TESTS=OFF
        -DBUILD_SAMPLES=OFF
        -DCPPREST_EXCLUDE_WEBSOCKETS=ON
        -DCPPREST_EXPORT_DIR=share/cpprestsdk
        -DWERROR=OFF
        -DPKG_CONFIG_EXECUTABLE=FALSE
    OPTIONS_DEBUG
        -DCPPREST_INSTALL_HEADERS=OFF
)

vcpkg_cmake_install()

vcpkg_copy_pdbs()

vcpkg_cmake_config_fixup(CONFIG_PATH "lib/share/${PORT}")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/lib/share" "${CURRENT_PACKAGES_DIR}/lib/share")

file(INSTALL "${SOURCE_PATH}/license.txt" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
