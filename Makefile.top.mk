LOCAL_PATH := $(call my-dir)

# This defines EMULATOR_BUILD_32BITS to indicate that 32-bit binaries
# must be generated by the build system. For now, only for Windows because
# the Win64 do not work yet properly (e.g. can't emulate 32-bit ARM), and
# Linux (because the 32-bit binaries are deprecated, but not obsolete).
EMULATOR_BUILD_32BITS := $(strip $(filter windows linux,$(BUILD_TARGET_OS)))

# This defines EMULATOR_BUILD_64BITS to indicate that 64-bit binaries
# must be generated by the build system. For now, only do it for
# Windows, Linux and Darwin.
EMULATOR_BUILD_64BITS := $(strip $(filter linux darwin windows,$(BUILD_TARGET_OS)))

# EMULATOR_PROGRAM_BITNESS is the bitness of the 'emulator' launcher program.
# It will be 32 if we allow 32-bit binaries to be built, 64 otherwise.
ifneq (,$(EMULATOR_BUILD_32BITS))
    EMULATOR_PROGRAM_BITNESS := 32
else
    EMULATOR_PROGRAM_BITNESS := 64
endif

# A function that includes a file only if 32-bit binaries are necessary,
# or if LOCAL_IGNORE_BITNESS is defined for the current module.
# $1: Build file to include.
include-if-bitness-32 = \
    $(if $(strip $(LOCAL_IGNORE_BITNESS)$(filter true,$(LOCAL_HOST_BUILD))$(EMULATOR_BUILD_32BITS)),\
        $(eval include $1))

# A function that includes a file only of EMULATOR_BUILD_64BITS is not empty.
# or if LOCAL_IGNORE_BITNESS is defined for the current module.
# $1: Build file to include.
include-if-bitness-64 = \
    $(if $(strip $(LOCAL_IGNORE_BITNESS)$(filter true,$(LOCAL_HOST_BUILD))$(EMULATOR_BUILD_64BITS)),\
        $(eval include $1))

BUILD_TARGET_CFLAGS := -g -falign-functions=0
ifeq ($(BUILD_DEBUG_EMULATOR),true)
    BUILD_TARGET_CFLAGS += -O0
else
    BUILD_TARGET_CFLAGS += -O2
endif

# Generate position-independent binaries. Don't add -fPIC when targetting
# Windows, because newer toolchain complain loudly about it, since all
# Windows code is position-independent.
ifneq (windows,$(BUILD_TARGET_OS))
  BUILD_TARGET_CFLAGS += -fPIC
endif

# Ensure that <inttypes.h> always defines all interesting macros.
BUILD_TARGET_CFLAGS += -D__STDC_LIMIT_MACROS=1 -D__STDC_FORMAT_MACROS=1

BUILD_TARGET_CFLAGS32 :=
BUILD_TARGET_CFLAGS64 :=

BUILD_TARGET_LDLIBS :=
BUILD_TARGET_LDLIBS32 :=
BUILD_TARGET_LDLIBS64 :=

BUILD_TARGET_LDFLAGS :=
BUILD_TARGET_LDFLAGS32 :=
BUILD_TARGET_LDFLAGS64 :=

# Enable large-file support (i.e. make off_t a 64-bit value).
# Fun fact: The mingw32 toolchain still uses 32-bit off_t values by default
# even when generating Win64 binaries, so modify MY_CFLAGS instead of
# MY_CFLAGS32.
BUILD_TARGET_CFLAGS += -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE

ifeq ($(BUILD_TARGET_OS),freebsd)
  BUILD_TARGET_CFLAGS += -I /usr/local/include
endif

ifeq ($(BUILD_TARGET_OS),windows)
  # we need Win32 features that are available since Windows 2000 Professional/Server (NT 5.0)
  BUILD_TARGET_CFLAGS += -DWINVER=0x501
  MY_LDFLAGS += -Xlinker --build-id
  # LARGEADDRESSAWARE gives more address space to 32-bit process
  BUILD_TARGET_LDFLAGS32 += -Xlinker --large-address-aware
endif

ifeq ($(BUILD_TARGET_OS),darwin)
    BUILD_TARGET_CFLAGS += -D_DARWIN_C_SOURCE=1
    # Clang complains about this flag being not useful anymore.
    BUILD_TARGET_CFLAGS := $(filter-out -falign-functions=0,$(BUILD_TARGET_CFLAGS))
endif

# NOTE: The following definitions are only used by the standalone build.
BUILD_TARGET_EXEEXT :=
BUILD_TARGET_DLLEXT := .so
ifeq ($(BUILD_TARGET_OS),windows)
  BUILD_TARGET_EXEEXT := .exe
  BUILD_TARGET_DLLEXT := .dll
endif
ifeq ($(BUILD_TARGET_OS),darwin)
  BUILD_TARGET_DLLEXT := .dylib
endif

# Some CFLAGS below use -Wno-missing-field-initializers but this is not
# supported on GCC 3.x which is still present under Cygwin.
# Find out by probing GCC for support of this flag. Note that the test
# itself only works on GCC 4.x anyway.
GCC_W_NO_MISSING_FIELD_INITIALIZERS := -Wno-missing-field-initializers
ifeq ($(BUILD_TARGET_OS),windows)
    ifeq (,$(shell gcc -Q --help=warnings 2>/dev/null | grep missing-field-initializers))
        $(info emulator: Ignoring unsupported GCC flag $(GCC_W_NO_MISSING_FIELD_INITIALIZERS))
        GCC_W_NO_MISSING_FIELD_INITIALIZERS :=
    endif
endif

ifeq ($(BUILD_TARGET_OS),windows)
  # Ensure that printf() et al use GNU printf format specifiers as required
  # by QEMU. This is important when using the newer Mingw64 cross-toolchain.
  # See http://sourceforge.net/apps/trac/mingw-w64/wiki/gnu%20printf
  BUILD_TARGET_CFLAGS += -D__USE_MINGW_ANSI_STDIO=1
endif

# Enable warning, except those related to missing field initializers
# (the QEMU coding style loves using these).
#
BUILD_TARGET_CFLAGS += -Wall $(GCC_W_NO_MISSING_FIELD_INITIALIZERS)

# Needed to build block.c on Linux/x86_64.
BUILD_TARGET_CFLAGS += -D_GNU_SOURCE=1

# A useful function that can be used to start the declaration of a host
# module. Avoids repeating the same stuff again and again.
# Usage:
#
#  $(call start-emulator-library, <module-name>)
#
#  ... declarations
#
#  $(call end-emulator-library)
#
start-emulator-library = \
    $(eval include $(CLEAR_VARS)) \
    $(eval LOCAL_MODULE := $1) \
    $(eval LOCAL_MODULE_CLASS := STATIC_LIBRARIES) \
    $(eval LOCAL_BUILD_FILE := $(BUILD_HOST_STATIC_LIBRARY))

# Used with start-emulator-library
end-emulator-library = \
    $(eval $(end-emulator-module-ev)) \

define-emulator-prebuilt-library = \
    $(call start-emulator-library,$1) \
    $(eval LOCAL_BUILD_FILE := $(PREBUILT_STATIC_LIBRARY)) \
    $(eval LOCAL_SRC_FILES := $2) \
    $(eval $(end-emulator-module-ev)) \

# A variant of start-emulator-library to start the definition of a host
# program instead. Use with end-emulator-program
start-emulator-program = \
    $(call start-emulator-library,$1) \
    $(eval LOCAL_MODULE_CLASS := EXECUTABLES) \
    $(eval LOCAL_BUILD_FILE := $(BUILD_HOST_EXECUTABLE))

# A varient of end-emulator-library for host programs instead
end-emulator-program = \
    $(eval LOCAL_LDLIBS += $(QEMU_SYSTEM_LDLIBS)) \
    $(eval $(end-emulator-module-ev)) \

define end-emulator-module-ev
LOCAL_BITS := $$(BUILD_TARGET_BITS)
include $$(LOCAL_BUILD_FILE)
endef

# The common libraries
#
QEMU_SYSTEM_LDLIBS := -lm
ifeq ($(BUILD_TARGET_OS),windows)
  QEMU_SYSTEM_LDLIBS += -mwindows -mconsole
endif

ifeq ($(BUILD_TARGET_OS),freebsd)
    QEMU_SYSTEM_LDLIBS += -L/usr/local/lib -lpthread -lX11 -lutil
endif

ifeq ($(BUILD_TARGET_OS),linux)
  QEMU_SYSTEM_LDLIBS += -lutil -lrt
endif

ifeq ($(BUILD_TARGET_OS),windows)
  # amd64-mingw32msvc- toolchain still name it ws2_32.  May change it once amd64-mingw32msvc-
  # is stabilized
  QEMU_SYSTEM_LDLIBS += -lwinmm -lws2_32 -liphlpapi
else
  QEMU_SYSTEM_LDLIBS += -lpthread
endif

ifeq ($(BUILD_TARGET_OS),darwin)
  QEMU_SYSTEM_FRAMEWORKS := \
      AudioUnit \
      AVFoundation \
      Cocoa \
      CoreAudio \
      CoreMedia \
      CoreVideo \
      ForceFeedback \
      IOKit \
      QTKit \

  QEMU_SYSTEM_LDLIBS += $(QEMU_SYSTEM_FRAMEWORKS:%=-Wl,-framework,%)
endif

ifeq ($(BUILD_TARGET_OS),darwin)
    CXX_STD_LIB := -lc++
else
    CXX_STD_LIB := -lstdc++
endif

# Call this function to force a module to link statically to the C++ standard
# library on platforms that support it (i.e. Linux and Windows).
local-link-static-c++lib = $(eval $(ev-local-link-static-c++lib))
define ev-local-link-static-c++lib
ifeq (darwin,$(BUILD_TARGET_OS))
LOCAL_LDLIBS += $(CXX_STD_LIB)
else  # BUILD_TARGET_OS != darwin
LOCAL_LD := $$(call local-host-tool,CXX)
LOCAL_LDLIBS += -static-libstdc++
endif  # BUILD_TARGET_OS != darwin
endef

ifdef EMULATOR_BUILD_32BITS
BUILD_TARGET_BITS := 32
BUILD_TARGET_ARCH := x86
BUILD_TARGET_SUFFIX :=
include $(LOCAL_PATH)/Makefile.common.mk
endif

ifdef EMULATOR_BUILD_64BITS
BUILD_TARGET_BITS := 64
BUILD_TARGET_ARCH := x86_64
BUILD_TARGET_SUFFIX := 64

include $(LOCAL_PATH)/Makefile.common.mk
endif

##
##   PREBUILT_DLL_SYMBOLS
##
ifeq (true,$(EMULATOR_GENERATE_SYMBOLS))
$(foreach prebuilt_symbol,$(EMULATOR_PREBUILT_SYMBOLS),$(eval $(call install-symbol,\
    $(prebuilt_symbol))))
endif
## VOILA!!
