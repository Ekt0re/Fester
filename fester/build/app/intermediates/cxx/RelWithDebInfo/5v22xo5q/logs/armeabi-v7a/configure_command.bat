@echo off
"D:\\Progetti\\Android\\cmake\\3.22.1\\bin\\cmake.exe" ^
  "-HD:\\flutter\\packages\\flutter_tools\\gradle\\src\\main\\groovy" ^
  "-DCMAKE_SYSTEM_NAME=Android" ^
  "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON" ^
  "-DCMAKE_SYSTEM_VERSION=21" ^
  "-DANDROID_PLATFORM=android-21" ^
  "-DANDROID_ABI=armeabi-v7a" ^
  "-DCMAKE_ANDROID_ARCH_ABI=armeabi-v7a" ^
  "-DANDROID_NDK=D:\\Progetti\\Android\\ndk\\27.0.12077973" ^
  "-DCMAKE_ANDROID_NDK=D:\\Progetti\\Android\\ndk\\27.0.12077973" ^
  "-DCMAKE_TOOLCHAIN_FILE=D:\\Progetti\\Android\\ndk\\27.0.12077973\\build\\cmake\\android.toolchain.cmake" ^
  "-DCMAKE_MAKE_PROGRAM=D:\\Progetti\\Android\\cmake\\3.22.1\\bin\\ninja.exe" ^
  "-DCMAKE_LIBRARY_OUTPUT_DIRECTORY=D:\\Progetti\\Fester 3.0\\fester\\build\\app\\intermediates\\cxx\\RelWithDebInfo\\5v22xo5q\\obj\\armeabi-v7a" ^
  "-DCMAKE_RUNTIME_OUTPUT_DIRECTORY=D:\\Progetti\\Fester 3.0\\fester\\build\\app\\intermediates\\cxx\\RelWithDebInfo\\5v22xo5q\\obj\\armeabi-v7a" ^
  "-DCMAKE_BUILD_TYPE=RelWithDebInfo" ^
  "-BD:\\Progetti\\Fester 3.0\\fester\\android\\app\\.cxx\\RelWithDebInfo\\5v22xo5q\\armeabi-v7a" ^
  -GNinja ^
  -Wno-dev ^
  --no-warn-unused-cli
