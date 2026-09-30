set(CMOCK_CURRENT_LIST_DIR ${CMAKE_CURRENT_LIST_DIR})
#------------------------------------------------------------------------------#
# Returns artifact version.
#
# The name of function must consist of folder name (cmock) and postfix
# (_GetArtifactVersion). Otherwise the buildprocess will fail.
#
# Unlike a compiler/tool artifact (gcc-arm-none-eabi, probe-rs, ...), CMock
# ships no executable to query "--version" from - it is a Ruby generator
# (lib/cmock.rb) plus plain C source (src/cmock.c) compiled straight into the
# test project. The version is therefore not re-discovered here; it is only
# returned from the cache variable that cmock_ArtifactInit() populated. This
# means cmock_ArtifactInit() MUST be called before cmock_GetArtifactVersion().
#
# RET_VERSION [out]: Version of artifact in format X.Y.Z
#------------------------------------------------------------------------------#
function(cmock_GetArtifactVersion RET_VERSION)

    if(NOT DEFINED CMOCK_ARTIFACT_VERSION)
        message(FATAL_ERROR "cmock_GetArtifactVersion called before cmock_ArtifactInit() - CMOCK_ARTIFACT_VERSION is not set.")
    endif()

    set(${RET_VERSION} "${CMOCK_ARTIFACT_VERSION}" PARENT_SCOPE)

endfunction()


#------------------------------------------------------------------------------#
# Initialize artifact for build.
#
# The name of function must consist of folder name (cmock) and postfix
# (_ArtifactInit). Otherwise the buildprocess will fail.
#
# Binary part contains the CMock source tree packaged by Cmock_Importer.sh
# (OS independent, released as Bin/<version> without platform suffix).
#
# This does NOT define a "cmock" library target and does NOT generate any
# mocks - the consumers (UnitTesting.cmake for host, IntegrationTesting.cmake
# for MCU) build src/cmock.c themselves and invoke the generator with their
# own configuration. It only exposes:
#   - CMOCK_ROOT             (CACHE PATH)     - root of the CMock source tree
#                                               (src/cmock.c, lib/cmock.rb, ...)
#   - CMOCK_SCRIPT           (CACHE FILEPATH) - mock generator lib/cmock.rb
#   - CMOCK_ARTIFACT_VERSION (CACHE STRING)   - version read from the VERSION
#                                               marker, or from cmock.h if the
#                                               marker is missing
#
# The generator requires a Ruby interpreter - use the "ruby" artifact
# (RUBY_EXECUTABLE), e.g.:
#
#   add_custom_command(OUTPUT ${MOCK_DIR}/mock_${NAME}.c ${MOCK_DIR}/mock_${NAME}.h
#       COMMAND ${RUBY_EXECUTABLE} ${CMOCK_SCRIPT} -o${CMOCK_CONFIG_FILE} ${HEADER}
#       DEPENDS ${HEADER} ${CMOCK_CONFIG_FILE})
#
# The Unity framework itself is taken from the "unity" artifact (UNITY_ROOT),
# not from CMock's vendor/unity copy.
#
# ARTIFACT_BIN_PATH_ARG [in]: Path to the binary (here: source) part of artifact
#------------------------------------------------------------------------------#
function(cmock_ArtifactInit ARTIFACT_BIN_PATH_ARG)

    file(GLOB_RECURSE CMOCK_SOURCES "${ARTIFACT_BIN_PATH_ARG}/*/cmock.c")

    # Only the framework itself - skips copies in examples/, test/ or vendored
    # packages.
    list(FILTER CMOCK_SOURCES INCLUDE REGEX "/src/cmock\\.c$")
    list(FILTER CMOCK_SOURCES EXCLUDE REGEX "/vendor/")

    if(NOT CMOCK_SOURCES)

        message(FATAL_ERROR "File src/cmock.c not found in: ${ARTIFACT_BIN_PATH_ARG}")

    endif()

    list(GET CMOCK_SOURCES 0 CMOCK_SOURCE)

    get_filename_component(CMOCK_SRC_DIR "${CMOCK_SOURCE}" DIRECTORY)
    get_filename_component(RESOLVED_ROOT_DIR "${CMOCK_SRC_DIR}" DIRECTORY)

    if(NOT EXISTS "${RESOLVED_ROOT_DIR}/lib/cmock.rb")

        message(FATAL_ERROR "Mock generator lib/cmock.rb not found in: ${RESOLVED_ROOT_DIR}")

    endif()

    message(STATUS "CMock source found in: ${RESOLVED_ROOT_DIR}")

    if(EXISTS "${RESOLVED_ROOT_DIR}/VERSION")

        # VERSION marker added by Cmock_Importer.sh
        file(READ "${RESOLVED_ROOT_DIR}/VERSION" READ_VERSION)
        string(STRIP "${READ_VERSION}" READ_VERSION)

    else()

        # Fallback for source trees not packaged by Cmock_Importer.sh
        file(STRINGS "${CMOCK_SRC_DIR}/cmock.h" VERSION_LINES
             REGEX "#define[ \t]+CMOCK_VERSION_(MAJOR|MINOR|BUILD)[ \t]")

        set(READ_VERSION "")

        foreach(VERSION_PART IN ITEMS MAJOR MINOR BUILD)
            string(REGEX MATCH "CMOCK_VERSION_${VERSION_PART}[ \t]+([0-9]+)" _ "${VERSION_LINES}")
            list(APPEND READ_VERSION "${CMAKE_MATCH_1}")
        endforeach()

        string(REPLACE ";" "." READ_VERSION "${READ_VERSION}")

    endif()

    if(NOT READ_VERSION MATCHES "^[0-9]+\\.[0-9]+\\.[0-9]+$")

        message(FATAL_ERROR "CMock version could not be resolved in ${RESOLVED_ROOT_DIR}: '${READ_VERSION}'")

    endif()

    set(CMOCK_ROOT "${RESOLVED_ROOT_DIR}" CACHE PATH "Root of the resolved CMock source tree" FORCE)
    set(CMOCK_SCRIPT "${RESOLVED_ROOT_DIR}/lib/cmock.rb" CACHE FILEPATH "CMock mock generator script" FORCE)
    set(CMOCK_ARTIFACT_VERSION "${READ_VERSION}" CACHE STRING "Resolved CMock artifact version" FORCE)

    message(STATUS "CMock version: ${CMOCK_ARTIFACT_VERSION}")

endfunction()
