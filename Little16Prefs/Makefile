ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = Little16Prefs

Little16Prefs_FILES = L16RootListController.m
Little16Prefs_FRAMEWORKS = UIKit
Little16Prefs_PRIVATE_FRAMEWORKS = Preferences
Little16Prefs_INSTALL_PATH = /Library/PreferenceBundles
Little16Prefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
