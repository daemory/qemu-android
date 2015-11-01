# When building this project, we actually generate several components which
# are the following:
#
#  - the emulator-ui program (which is target-agnostic)
#  - the target-specific qemu-android-$ARCH programs (headless emulation engines)
#  - the "standalone" emulator programs (embed both UI and engine in a single
#    binary and process), i.e. "emulator" for ARM and "emulator-x86" for x86.
#
# This file defines static host libraries that will be used by at least two
# of these components.
#

##############################################################################
##############################################################################
###
###  gen-hw-config-defs: Generate hardware configuration definitions header
###
###  The 'gen-hw-config.py' script is used to generate the hw-config-defs.h
###  header from the an .ini file like android/avd/hardware-properties.ini
###
###  Due to the way the Android build system works, we need to regenerate
###  it for each module (the output will go into a module-specific directory).
###
###  This defines a function that can be used inside a module definition
###
###  $(call gen-hw-config-defs)
###

# First, define a rule to generate a dummy "emulator_hw_config_defs" module
# which purpose is simply to host the generated header in its output directory.
intermediates := $(call intermediates-dir-for,$(HOST_BITS),emulator_hw_config_defs)

QEMU_HARDWARE_PROPERTIES_INI := $(LOCAL_PATH)/android/avd/hardware-properties.ini
QEMU_HW_CONFIG_DEFS_H := $(intermediates)/android/avd/hw-config-defs.h
$(QEMU_HW_CONFIG_DEFS_H): PRIVATE_PATH := $(LOCAL_PATH)
$(QEMU_HW_CONFIG_DEFS_H): PRIVATE_CUSTOM_TOOL = $(PRIVATE_PATH)/android/tools/gen-hw-config.py $< $@
$(QEMU_HW_CONFIG_DEFS_H): $(QEMU_HARDWARE_PROPERTIES_INI) $(LOCAL_PATH)/android/tools/gen-hw-config.py
	$(hide) rm -f $@
	$(transform-generated-source)

QEMU_HW_CONFIG_DEFS_INCLUDES := $(intermediates)

# Second, define a function that needs to be called inside each module that contains
# a source file that includes the generated header file.
gen-hw-config-defs = \
  $(eval LOCAL_GENERATED_SOURCES += $(QEMU_HW_CONFIG_DEFS_H))\
  $(eval LOCAL_C_INCLUDES += $(QEMU_HW_CONFIG_DEFS_INCLUDES))

EMULATOR_USE_SDL2 := $(strip $(filter true,$(EMULATOR_USE_SDL2)))
EMULATOR_USE_QT := $(strip $(filter true,$(EMULATOR_USE_QT)))

##############################################################################
##############################################################################
###
###  emulator-common: LIBRARY OF COMMON FUNCTIONS
###
###  THESE ARE POTENTIALLY USED BY ALL COMPONENTS
###

common_LOCAL_CFLAGS =
common_LOCAL_SRC_FILES =

EMULATOR_COMMON_CFLAGS := -Werror=implicit-function-declaration

# Needed by everything about the host
# $(OBJS_DIR)/build contains config-host.h
# $(LOCAL_PATH)/include contains common headers.
EMULATOR_COMMON_CFLAGS += \
    -I$(OBJS_DIR)/build \
    -I$(LOCAL_PATH)/include

# Need to include "qapi-types.h" and other auto-generated files from
# android-configure.sh
EMULATOR_COMMON_CFLAGS += -I$(OBJS_DIR)/build/qemu1-qapi-auto-generated


ANDROID_SDK_TOOLS_REVISION := $(strip $(ANDROID_SDK_TOOLS_REVISION))
ifdef ANDROID_SDK_TOOLS_REVISION
    EMULATOR_COMMON_CFLAGS += -DANDROID_SDK_TOOLS_REVISION=$(ANDROID_SDK_TOOLS_REVISION)
endif

# Enable large-file support (i.e. make off_t a 64-bit value)
ifeq ($(HOST_OS),linux)
EMULATOR_COMMON_CFLAGS += -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE
endif

ifeq (true,$(BUILD_DEBUG_EMULATOR))
    EMULATOR_COMMON_CFLAGS += -DENABLE_DLOG=1
else
    EMULATOR_COMMON_CFLAGS += -DENABLE_DLOG=0
endif

ifeq ($(HOST_OS),darwin)
    CXX_STD_LIB := -lc++
else
    CXX_STD_LIB := -lstdc++
endif

###########################################################
# Zlib sources
#
EMULATOR_COMMON_CFLAGS += -I$(ZLIB_INCLUDES)

###########################################################
# GLib sources
#
GLIB_DIR := distrib/mini-glib
include $(LOCAL_PATH)/$(GLIB_DIR)/sources.make
EMULATOR_COMMON_CFLAGS += -I$(GLIB_INCLUDE_DIR)

common_LOCAL_SRC_FILES += $(GLIB_SOURCES)

EMULATOR_COMMON_CFLAGS += $(LIBCURL_CFLAGS)

##############################################################################
# breakpad  definitions
#
BREAKPAD_TOP_DIR := $(BREAKPAD_PREBUILTS_DIR)/$(HOST_OS)-$(HOST_ARCH)

BREAKPAD_INCLUDES := $(BREAKPAD_TOP_DIR)/include/breakpad
BREAKPAD_LDLIBS := $(BREAKPAD_TOP_DIR)/lib/libbreakpad_client.a

ifeq ($(HOST_OS),windows)
  BREAKPAD_LDLIBS += -lstdc++
endif

###########################################################
# Android utility functions
#
common_LOCAL_SRC_FILES += \
	android/android-constants.c \
	android/async-console.c \
	android/async-utils.c \
	android/curl-support.c \
	android/framebuffer.c \
	android/avd/hw-config.c \
	android/avd/info.c \
	android/avd/scanner.c \
	android/avd/util.c \
	android/base/async/AsyncReader.cpp \
	android/base/async/AsyncWriter.cpp \
	android/base/async/Looper.cpp \
	android/base/async/ThreadLooper.cpp \
	android/base/containers/PodVector.cpp \
	android/base/containers/PointerSet.cpp \
	android/base/containers/HashUtils.cpp \
	android/base/containers/StringVector.cpp \
	android/base/files/IniFile.cpp \
	android/base/files/PathUtils.cpp \
	android/base/files/StdioStream.cpp \
	android/base/files/Stream.cpp \
	android/base/misc/HttpUtils.cpp \
	android/base/misc/StringUtils.cpp \
	android/base/misc/Utf8Utils.cpp \
	android/base/sockets/SocketDrainer.cpp \
	android/base/sockets/SocketUtils.cpp \
	android/base/sockets/SocketWaiter.cpp \
	android/base/synchronization/MessageChannel.cpp \
	android/base/Log.cpp \
	android/base/memory/LazyInstance.cpp \
	android/base/String.cpp \
	android/base/StringFormat.cpp \
	android/base/StringView.cpp \
	android/base/system/System.cpp \
	android/base/threads/ThreadStore.cpp \
	android/base/Uri.cpp \
	android/base/Version.cpp \
	android/emulation/android_pipe.c \
	android/emulation/android_pipe_pingpong.c \
	android/emulation/android_pipe_throttle.c \
	android/emulation/android_pipe_zero.c \
	android/emulation/android_qemud.cpp \
	android/emulation/qemud/android_qemud_sink.cpp \
	android/emulation/qemud/android_qemud_serial.cpp \
	android/emulation/qemud/android_qemud_client.cpp \
	android/emulation/qemud/android_qemud_service.cpp \
	android/emulation/qemud/android_qemud_multiplexer.cpp \
	android/emulation/bufprint_config_dirs.cpp \
	android/emulation/ConfigDirs.cpp \
	android/emulation/control/LineConsumer.cpp \
	android/emulation/CpuAccelerator.cpp \
	android/emulation/serial_line.cpp \
	android/filesystems/ext4_utils.cpp \
	android/filesystems/fstab_parser.cpp \
	android/filesystems/partition_types.cpp \
	android/filesystems/ramdisk_extractor.cpp \
	android/kernel/kernel_utils.cpp \
	android/metrics/metrics_reporter.c \
	android/metrics/metrics_reporter_ga.c \
	android/metrics/metrics_reporter_toolbar.c \
	android/metrics/StudioHelper.cpp \
	android-qemu1-glue/android_qemud.cpp \
	android-qemu1-glue/base/async/Looper.cpp \
	android-qemu1-glue/base/files/QemuFileStream.cpp \
	android-qemu1-glue/utils/stream.cpp \
	android/opengl/EmuglBackendList.cpp \
	android/opengl/EmuglBackendScanner.cpp \
	android/opengl/emugl_config.cpp \
	android/opengl/GpuFrameBridge.cpp \
	android/proxy/proxy_common.c \
	android/proxy/proxy_http.c \
	android/proxy/proxy_http_connector.c \
	android/proxy/proxy_http_rewriter.c \
	android/update-check/UpdateChecker.cpp \
	android/update-check/VersionExtractor.cpp \
	android/utils/aconfig-file.c \
	android/utils/assert.c \
	android/utils/bufprint.c \
	android/utils/bufprint_system.cpp \
	android/utils/cbuffer.c \
	android/utils/debug.c \
	android/utils/dll.c \
	android/utils/dirscanner.cpp \
	android/utils/eintr_wrapper.c \
	android/utils/filelock.c \
	android/utils/file_data.c \
	android/utils/format.cpp \
	android/utils/host_bitness.cpp \
	android/utils/http_utils.cpp \
	android/utils/iolooper.cpp \
	android/utils/ini.cpp \
	android/utils/intmap.c \
	android/utils/ipaddr.cpp \
	android/utils/lineinput.c \
	android/utils/looper.cpp \
	android/utils/mapfile.c \
	android/utils/misc.c \
	android/utils/panic.c \
	android/utils/path.c \
	android/utils/property_file.c \
	android/utils/reflist.c \
	android/utils/refset.c \
	android/utils/socket_drainer.cpp \
	android/utils/sockets.c \
	android/utils/stralloc.c \
	android/utils/stream.cpp \
	android/utils/string.cpp \
	android/utils/system.c \
	android/utils/system_wrapper.cpp \
	android/utils/tempfile.c \
	android/utils/uncompress.cpp \
	android/utils/uri.cpp \
	android/utils/utf8_utils.cpp \
	android/utils/vector.c \
	android/utils/x86_cpuid.c \

ifeq (windows,$(HOST_OS))
common_LOCAL_SRC_FILES += \
    android/base/synchronization/ConditionVariable_win32.cpp \
    android/base/threads/Thread_win32.cpp \
    android/base/system/Win32UnicodeString.cpp \
    android/base/system/Win32Utils.cpp \
    android/utils/win32_cmdline_quote.cpp \

else
common_LOCAL_SRC_FILES += \
    android/base/threads/Thread_pthread.cpp \

endif



common_LOCAL_CFLAGS += $(EMULATOR_COMMON_CFLAGS)

common_LOCAL_CFLAGS += $(LIBXML2_CFLAGS)
common_LOCAL_CFLAGS += -I$(LIBEXT4_UTILS_INCLUDES)

include $(LOCAL_PATH)/android/wear-agent/sources.mk

## one for 32-bit
$(call start-emulator-library, emulator-common)
LOCAL_CFLAGS += $(common_LOCAL_CFLAGS) -I$(LIBCURL_INCLUDES)
LOCAL_CFLAGS += -I$(LIBXML2_INCLUDES)
LOCAL_CFLAGS += -I$(BREAKPAD_INCLUDES)
LOCAL_SRC_FILES += $(common_LOCAL_SRC_FILES)
ifeq (32,$(EMULATOR_PROGRAM_BITNESS))
    LOCAL_IGNORE_BITNESS := true
endif
$(call gen-hw-config-defs)
$(call end-emulator-library)

##############################################################################
##############################################################################
###
###  emulator-libui: LIBRARY OF UI-RELATED FUNCTIONS
###
###  THESE ARE USED BY 'emulator-ui' AND THE STANDALONE PROGRAMS
###

common_LOCAL_CFLAGS =
common_LOCAL_SRC_FILES =
common_LOCAL_QT_MOC_SRC_FILES =
common_LOCAL_QT_RESOURCES =
common_LOCAL_CFLAGS += $(EMULATOR_COMMON_CFLAGS)

EMULATOR_LIBUI_CFLAGS :=
EMULATOR_LIBUI_LDLIBS :=
EMULATOR_LIBUI_LDFLAGS :=
EMULATOR_LIBUI_STATIC_LIBRARIES :=

###########################################################
# Libpng configuration
#
include $(LOCAL_PATH)/distrib/libpng.mk
EMULATOR_LIBUI_CFLAGS += $(LIBPNG_CFLAGS)
EMULATOR_LIBUI_STATIC_LIBRARIES += emulator-libpng
common_LOCAL_SRC_FILES += android/loadpng.c

###########################################################
# Libjpeg configuration
#
include $(LOCAL_PATH)/distrib/jpeg-6b/libjpeg.mk
EMULATOR_LIBUI_CFLAGS += $(LIBJPEG_CFLAGS)
EMULATOR_LIBUI_STATIC_LIBRARIES += emulator-libjpeg

##############################################################################
# SDL-related definitions
#

ifdef EMULATOR_USE_SDL2
    include $(LOCAL_PATH)/distrib/libsdl2.mk

    EMULATOR_LIBUI_CFLAGS += $(SDL2_CFLAGS) $(foreach inc,$(SDL2_INCLUDES),-I$(inc))
    EMULATOR_LIBUI_LDLIBS += $(SDL2_LDLIBS)
    EMULATOR_LIBUI_STATIC_LIBRARIES += $(SDL2_STATIC_LIBRARIES)

    ifeq ($(HOST_OS),windows)
        # Special exception for Windows: -lmingw32 must appear before libSDLmain
        # on the link command-line, because it depends on _WinMain@16 which is
        # exported by the latter.
        EMULATOR_LIBUI_LDFLAGS += -lmingw32
        EMULATOR_LIBUI_CFLAGS += -Dmain=SDL_main
    else
        # The following is needed by SDL_LoadObject
        EMULATOR_LIBUI_LDLIBS += -ldl
    endif
endif  # EMULATOR_USE_SDL2

###########################################################################
# Qt-related definitions
#
ifdef EMULATOR_USE_QT
    QT_TOP_DIR := $(QT_PREBUILTS_DIR)/$(HOST_OS)-$(HOST_ARCH)
    QT_TOP64_DIR := $(QT_PREBUILTS_DIR)/$(HOST_OS)-x86_64
    QT_MOC_TOOL := $(QT_TOP64_DIR)/bin/moc
    QT_RCC_TOOL := $(QT_TOP64_DIR)/bin/rcc
    # Special-case: the 'uic' tool depends on Qt5Core: always ensure that the
    # version that is being used is from the prebuilts directory. Otherwise
    # the executable may fail to start due to dynamic linking problems.
    QT_UIC_TOOL_LDPATH := $(QT_TOP64_DIR)/lib
    QT_UIC_TOOL := $(QT_TOP64_DIR)/bin/uic

    EMULATOR_QT_LIBS := Qt5Widgets Qt5Gui Qt5Core
    EMULATOR_QT_LDLIBS := $(foreach lib,$(EMULATOR_QT_LIBS),-l$(lib))
    ifeq ($(HOST_OS),windows)
        # On Windows, linking to mingw32 is required. The library is provided
        # by the toolchain, and depends on a main() function provided by qtmain
        # which itself depends on qMain(). These must appear in LDFLAGS and
        # not LDLIBS since qMain() is provided by object/libraries that
        # appear after these in the link command-line.
        EMULATOR_QT_LDFLAGS += \
                -L$(QT_TOP_DIR)/bin \
                -lmingw32 \
                $(QT_TOP_DIR)/lib/libqtmain.a
    else
        EMULATOR_QT_LDFLAGS := -L$(QT_TOP_DIR)/lib
    endif
    QT_INCLUDE := $(QT_PREBUILTS_DIR)/common/include
    EMULATOR_LIBUI_CFLAGS += \
            -I$(QT_INCLUDE) \
            -I$(QT_INCLUDE)/QtCore \
            -I$(QT_INCLUDE)/QtGui \
            -I$(QT_INCLUDE)/QtWidgets
    EMULATOR_LIBUI_LDFLAGS += $(EMULATOR_QT_LDFLAGS)
    EMULATOR_LIBUI_LDLIBS += $(EMULATOR_QT_LDLIBS)

    EMULATOR_LIBUI_CFLAGS += $(LIBXML2_CFLAGS)
endif  # EMULATOR_USE_QT

# the skin support sources
#
include $(LOCAL_PATH)/android/skin/sources.mk
common_LOCAL_SRC_FILES += $(ANDROID_SKIN_SOURCES)

common_LOCAL_SRC_FILES += \
             android/gpu_frame.cpp \
             android/emulator-window.c \
             android/resource.c \
             android/user-config.c \

# enable MMX code for our skin scaler
ifeq ($(HOST_ARCH),x86)
common_LOCAL_CFLAGS += -DUSE_MMX=1 -mmmx
endif

common_LOCAL_CFLAGS += $(EMULATOR_LIBUI_CFLAGS)

ifeq ($(HOST_OS),windows)
# For capCreateCaptureWindow used in camera-capture-windows.c
EMULATOR_LIBUI_LDLIBS += -lvfw32
endif

## one for 32-bit
$(call start-emulator-library, emulator-libui)
LOCAL_CFLAGS += $(common_LOCAL_CFLAGS) $(ANDROID_SKIN_CFLAGS)
LOCAL_SRC_FILES += $(common_LOCAL_SRC_FILES)
LOCAL_QT_MOC_SRC_FILES := $(ANDROID_SKIN_QT_MOC_SRC_FILES)
LOCAL_QT_RESOURCES := $(ANDROID_SKIN_QT_RESOURCES)
LOCAL_QT_UI_SRC_FILES := $(ANDROID_SKIN_QT_UI_SRC_FILES)
$(call gen-hw-config-defs)
$(call end-emulator-library)

##############################################################################
##############################################################################
###
###  emulator-libqemu: TARGET-INDEPENDENT QEMU FUNCTIONS
###
###  THESE ARE USED BY EVERYTHING EXCEPT 'emulator-ui'
###

common_LOCAL_CFLAGS =
common_LOCAL_SRC_FILES =


EMULATOR_LIBQEMU_CFLAGS :=

common_LOCAL_CFLAGS += $(EMULATOR_COMMON_CFLAGS)

AUDIO_SOURCES := noaudio.c wavaudio.c wavcapture.c mixeng.c
AUDIO_CFLAGS  := -I$(LOCAL_PATH)/audio -DHAS_AUDIO
AUDIO_LDLIBS  :=

common_LOCAL_CFLAGS += -Wall $(GCC_W_NO_MISSING_FIELD_INITIALIZERS)

ifeq ($(HOST_OS),darwin)
  CONFIG_COREAUDIO ?= yes
  AUDIO_CFLAGS += -DHOST_BSD=1
endif

ifeq ($(HOST_OS),windows)
  CONFIG_WINAUDIO ?= yes
endif

ifeq ($(HOST_OS),linux)
  CONFIG_OSS  ?= yes
  CONFIG_ALSA ?= yes
  CONFIG_PULSEAUDIO ?= yes
  CONFIG_ESD  ?= yes
endif

ifeq ($(HOST_OS),freebsd)
  CONFIG_OSS ?= yes
endif

ifeq ($(CONFIG_COREAUDIO),yes)
  AUDIO_SOURCES += coreaudio.c
  AUDIO_CFLAGS  += -DCONFIG_COREAUDIO
  AUDIO_LDLIBS  += -Wl,-framework,CoreAudio
endif

ifeq ($(CONFIG_WINAUDIO),yes)
  AUDIO_SOURCES += winaudio.c
  AUDIO_CFLAGS  += -DCONFIG_WINAUDIO
endif

ifeq ($(CONFIG_PULSEAUDIO),yes)
  AUDIO_SOURCES += paaudio.c audio_pt_int.c
  AUDIO_SOURCES += wrappers/pulse-audio.c
  AUDIO_CFLAGS  += -DCONFIG_PULSEAUDIO
endif

ifeq ($(CONFIG_ALSA),yes)
  AUDIO_SOURCES += alsaaudio.c audio_pt_int.c
  AUDIO_SOURCES += wrappers/alsa.c
  AUDIO_CFLAGS  += -DCONFIG_ALSA
endif

ifeq ($(CONFIG_ESD),yes)
  AUDIO_SOURCES += esdaudio.c
  AUDIO_SOURCES += wrappers/esound.c
  AUDIO_CFLAGS  += -DCONFIG_ESD
endif

ifeq ($(CONFIG_OSS),yes)
  AUDIO_SOURCES += ossaudio.c
  AUDIO_CFLAGS  += -DCONFIG_OSS
endif

AUDIO_SOURCES := $(call sort,$(AUDIO_SOURCES:%=audio/%))

common_LOCAL_CFLAGS += -Wno-sign-compare \
                -fno-strict-aliasing -W -Wall -Wno-unused-parameter \

# this is very important, otherwise the generated binaries may
# not link properly on our build servers
ifeq ($(HOST_OS),linux)
common_LOCAL_CFLAGS += -fno-stack-protector
endif

common_LOCAL_SRC_FILES += $(AUDIO_SOURCES)
common_LOCAL_SRC_FILES += \
    android/audio-test.c

# other flags
ifneq ($(HOST_OS),windows)
    AUDIO_LDLIBS += -ldl
else
endif


EMULATOR_LIBQEMU_CFLAGS += $(AUDIO_CFLAGS)
EMULATOR_LIBQEMU_LDLIBS += $(AUDIO_LDLIBS)

common_LOCAL_CFLAGS += $(GCC_W_NO_MISSING_FIELD_INITIALIZERS)

# misc. sources
#
CORE_MISC_SOURCES = \
    aio-android.c \
    async.c \
    iohandler.c \
    ioport.c \
    migration-dummy-android.c \
    qemu-char.c \
    qemu-log.c \
    savevm.c \
    android/boot-properties.c \
    android-qemu1-glue/emulation/charpipe.c \
    android/core-init-utils.c   \
    android/ext4_resize.cpp   \
    android/gps.c \
    android/hw-kmsg.c \
    android/hw-lcd.c \
    android/hw-events.c \
    android/hw-control.c \
    android/hw-fingerprint.c \
    android/hw-sensors.c \
    android/hw-qemud.cpp \
    android/looper-qemu.cpp \
    android/hw-pipe-net.c \
    android-qemu1-glue/emulation/serial_line.cpp \
    android-qemu1-glue/base/async/Looper.cpp \
    android-qemu1-glue/emulation/CharSerialLine.cpp \
    android/qemu-setup.c \
    android-qemu1-glue/qemu-setup.cpp \
    android/qemu-tcpdump.c \
    android/shaper.c \
    android/snapshot.c \
    android/async-socket-connector.c \
    android/async-socket.c \
    android/sdk-controller-socket.c \
    android/sensors-port.c \
    android/utils/timezone.c \
    android/camera/camera-format-converters.c \
    android/camera/camera-service.c \
    android/adb-server.c \
    android/adb-qemud.c \
    android/snaphost-android.c \
    android/multitouch-screen.c \
    android/multitouch-port.c \
    android/utils/jpeg-compress.c \
    net/net-android.c \
    qobject/qerror.c \
    qom/container.c \
    qom/object.c \
    qom/qom-qobject.c \
    ui/console.c \
    ui/d3des.c \
    ui/input.c \
    ui/vnc-android.c \
    util/aes.c \
    util/cutils.c \
    util/error.c \
    util/hexdump.c \
    util/iov.c \
    util/module.c \
    util/notify.c \
    util/osdep.c \
    util/path.c \
    util/qemu-config.c \
    util/qemu-error.c \
    util/qemu-option.c \
    util/qemu-sockets-android.c \
    util/unicode.c \
    util/yield-android.c \

ifeq ($(HOST_ARCH),x86)
    CORE_MISC_SOURCES += disas/i386.c
endif
ifeq ($(HOST_ARCH),x86_64)
    CORE_MISC_SOURCES += disas/i386.c
endif
ifeq ($(HOST_ARCH),ppc)
    CORE_MISC_SOURCES += disas/ppc.c \
                         util/cache-utils.c
endif

ifeq ($(HOST_OS),linux)
    CORE_MISC_SOURCES += util/compatfd.c \
                         util/qemu-thread-posix.c \
                         android/camera/camera-capture-linux.c
endif

ifeq ($(HOST_OS),windows)
  CORE_MISC_SOURCES   += tap-win32.c \
                         android/camera/camera-capture-windows.c \
                         util/qemu-thread-win32.c

else
  CORE_MISC_SOURCES   += posix-aio-compat.c
endif

ifeq ($(HOST_OS),darwin)
  CORE_MISC_SOURCES   += android/camera/camera-capture-mac.m \
                         util/compatfd.c \
                         util/qemu-thread-posix.c
endif

common_LOCAL_SRC_FILES += $(CORE_MISC_SOURCES)

# Required
common_LOCAL_CFLAGS += -D_XOPEN_SOURCE=600 -D_BSD_SOURCE=1 -I$(LOCAL_PATH)/distrib/jpeg-6b

SLIRP_SOURCES := \
    bootp.c \
    cksum.c \
    debug.c \
    if.c \
    ip_icmp.c \
    ip_input.c \
    ip_output.c \
    mbuf.c \
    misc.c \
    sbuf.c \
    slirp.c \
    socket.c \
    tcp_input.c \
    tcp_output.c \
    tcp_subr.c \
    tcp_timer.c \
    tftp.c \
    udp.c

common_LOCAL_SRC_FILES += $(SLIRP_SOURCES:%=slirp-android/%)
EMULATOR_LIBQEMU_CFLAGS += -I$(LOCAL_PATH)/slirp-android

# include telephony stuff
#
common_LOCAL_SRC_FILES += \
    android/telephony/debug.c \
    android/telephony/gsm.c \
    android/telephony/modem.c \
    android/telephony/modem_driver.c \
    android/telephony/remote_call.c \
    android/telephony/sim_card.c \
    android/telephony/sms.c \
    android/telephony/sysdeps.c \
    android-qemu1-glue/telephony/modem_init.cpp

# sources inherited from upstream, but not fully
# integrated into android emulator
#
common_LOCAL_SRC_FILES += \
    qobject/json-lexer.c \
    qobject/json-parser.c \
    qobject/json-streamer.c \
    qobject/qjson.c \
    qobject/qbool.c \
    qobject/qdict.c \
    qobject/qfloat.c \
    qobject/qint.c \
    qobject/qlist.c \
    qobject/qstring.c \

ifeq ($(QEMU_TARGET_XML_SOURCES),)
    QEMU_TARGET_XML_SOURCES := arm-core arm-neon arm-vfp arm-vfp3
    QEMU_TARGET_XML_SOURCES := $(QEMU_TARGET_XML_SOURCES:%=$(LOCAL_PATH)/gdb-xml/%.xml)
endif

common_LOCAL_CFLAGS += $(EMULATOR_LIBQEMU_CFLAGS)


$(call start-emulator-library, emulator-libqemu)
# gdbstub-xml.c contains C-compilable arrays corresponding to the content
# of $(LOCAL_PATH)/gdb-xml/, and is generated with the 'feature_to_c.sh' script.
#
intermediates = $(call local-intermediates-dir)
QEMU_GDBSTUB_XML_C = $(intermediates)/gdbstub-xml.c
$(QEMU_GDBSTUB_XML_C): PRIVATE_PATH := $(LOCAL_PATH)
$(QEMU_GDBSTUB_XML_C): PRIVATE_SOURCES := $(TARGET_XML_SOURCES)
$(QEMU_GDBSTUB_XML_C): PRIVATE_CUSTOM_TOOL = $(PRIVATE_PATH)/feature_to_c.sh $@ $(QEMU_TARGET_XML_SOURCES)
$(QEMU_GDBSTUB_XML_C): $(QEMU_TARGET_XML_SOURCES) $(LOCAL_PATH)/feature_to_c.sh
	$(hide) rm -f $@
	$(transform-generated-source)
LOCAL_GENERATED_SOURCES += $(QEMU_GDBSTUB_XML_C)
LOCAL_CFLAGS += $(common_LOCAL_CFLAGS) -I$(intermediates)
LOCAL_SRC_FILES += $(common_LOCAL_SRC_FILES)
$(call gen-hw-config-defs)
$(call end-emulator-library)


# Block sources, we must compile them with each executable because they
# are only referenced by the rest of the code using constructor functions.
# If their object files are put in a static library, these are never compiled
# into the final linked executable that uses them.
#
# Normally, one would solve thus using LOCAL_WHOLE_STATIC_LIBRARIES, but
# the Darwin linker doesn't support -Wl,--whole-archive or equivalent :-(
#
BLOCK_SOURCES := \
    block.c \
    blockdev.c \
    block/qcow2.c \
    block/qcow2-refcount.c \
    block/qcow2-snapshot.c \
    block/qcow2-cluster.c \
    block/raw.c

ifeq ($(HOST_OS),windows)
    BLOCK_SOURCES += block/raw-win32.c
else
    BLOCK_SOURCES += block/raw-posix.c
endif

BLOCK_CFLAGS += $(EMULATOR_COMMON_CFLAGS)
BLOCK_CFLAGS += -DCONFIG_BDRV_WHITELIST=\"\"

##############################################################################
##############################################################################
###
###  gen-hx-header: Generate headers from .hx file with "hxtool" script.
###
###  The 'hxtool' script is used to generate header files from an input
###  file with the .hx suffix. I.e. foo.hx --> foo.h
###
###  Due to the way the Android build system works, we need to regenerate
###  it for each module (the output will go into a module-specific directory).
###
###  This defines a function that can be used inside a module definition
###
###  $(call gen-hx-header,<input>,<output>,<source-files>)
###
###  Where: <input> is the input file, with a .hx suffix (e.g. foo.hx)
###         <output> is the output file, with a .h or .def suffix
###         <source-files> is a list of source files that include the header
###


gen-hx-header = $(eval $(call gen-hx-header-ev,$1,$2,$3))

define gen-hx-header-ev
intermediates := $$(call local-intermediates-dir)

QEMU_HEADER_H := $$(intermediates)/$$2
$$(QEMU_HEADER_H): PRIVATE_PATH := $$(LOCAL_PATH)
$$(QEMU_HEADER_H): PRIVATE_CUSTOM_TOOL = $$(PRIVATE_PATH)/hxtool -h < $$< > $$@
$$(QEMU_HEADER_H): $$(LOCAL_PATH)/$$1 $$(LOCAL_PATH)/hxtool
	$$(transform-generated-source)

LOCAL_GENERATED_SOURCES += $$(QEMU_HEADER_H)
LOCAL_C_INCLUDES += $$(intermediates)
endef
