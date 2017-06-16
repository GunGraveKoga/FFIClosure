TEMPLATE = app
CONFIG += console
CONFIG -= app_bundle
CONFIG -= qt

TARGET = FFIClosure

INCLUDEPATH += "$$(MSYSTEM_PREFIX)/include"
INCLUDEPATH += "$$(MSYSTEM_PREFIX)/$$(MSYSTEM_CHOST)/include"
INCLUDEPATH += "$$(MSYSTEM_PREFIX)/lib/libffi-3.2.1/include"

LIBS += -lffi

HEADERS += \
    objc_types_conversion.h \
    objc_signature.h \
    FFIClosure.h \
    objc_associate.h \
    objc_ffi_trampoline.h \
    objc_ffi_invocation.h

SOURCES += main.m \
    objc_types_conversion.m \
    objc_signature.m \
    FFIClosure.m \
    objc_associate.m \
    objc_ffi_trampoline.m \
    objc_ffi_invocation.m

DISTFILES +=
