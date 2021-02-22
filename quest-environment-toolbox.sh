#!/bin/sh

set -e

log_info() { echo "\033[0;34m$@\033[0m" 1>&2; }
log_plain() { echo "$@" 1>&2; }
log_err() { echo "\033[0;31m! $@\033[0m" 1>&2; }

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

TMP_PREFIX="/tmp/quest-environment-toolbox"

verify_adb() {
    log_info "verifying device presence..."

    # Check for ADB.
    if ! command -v adb &> /dev/null
    then
        log_err "'adb' must be installed"
        exit 1
    fi

    if ! adb get-state 1>/dev/null 2>&1
    then
        log_err "no android devices connected"
        exit 1
    fi
}

ASTCENC="astcenc-neon astcenc-avx2 astcenc-sse4.1 astcenc-sse2"

# Returns 1 if astcenc isn't available.
has_astcenc() {
    for i in $ASTCENC; do
        if command -v $i &> /dev/null
        then
            return 0
        fi
    done
    
    return 1
}

astcenc() {
    for i in $ASTCENC; do
        if command -v $i &> /dev/null
        then
            echo $i
            return
        fi
    done
}

ensure_directory() {
    
    if [ -z "$1" ]
    then
        log_err "ensure_directory needs one argument"
        exit 1
    fi

    test -d "$1" || mkdir -p "$1"
}

clear_directory() {
    ensure_directory "$1"
    rm -rf "$1"/*
}

verify_apktool() {
    # Check for ADB.
    if ! command -v apktool &> /dev/null
    then
        log_err "'apktool' must be installed"
        exit 1
    fi
}

# Echoes a list containing space-separated package names.
get_installed_environment_list() {
    log_info "fetching list of environments on device..."
    echo $(adb shell pm list packages | grep 'com.oculus.environment' | awk -F':' '{print $2}')
}

get_cached_environment_list() {
    ensure_apk_cache_path
    
    ls -p "$APK_CACHE_PATH" | grep -v / | sed 's/.apk//g'
}

# Downloaded APKs are stored here.
APK_CACHE_PATH=$DIR/apk_original

ensure_apk_cache_path() {
    ensure_directory "$APK_CACHE_PATH"
}

#log_info $ENVIRONMENT_PACKAGE_LIST

cmd_usage() {
    log_plain "usage: $0 <command>"
    log_plain
    log_plain "COMMANDS"
    log_plain "pull [package]              Copies the specified apk to '$APK_CACHE_PATH', or all of them if no argument given"
    log_plain "list-installed              Lists all installed environment package names"
    log_plain "list                        Lists cached APKs in '$APK_CACHE_PATH'"
    log_plain "unpack [package]            Unpacks the given package (without the apk extension) into '$APK_CACHE_PATH', or all of the cached packages if no package argument is given."
    log_plain "pack <package> <gltf> [ogg] Packs the given scene and audio file (optional) into a new apk derived from 'package'. The entire directory gltf is contained in will be included as well. If the package is 'all', then the scene will be packed into every parent environment, creating one apk per default environment."
    log_plain "remove <package>            Removes the given environment package (without an apk extension)"
    log_plain "install <apk>               Installs the given environment apk. This is a shortcut to adb."
    
    exit 1
}

# Given a package name in $1, returns 1 if the package is an original signed package, 0 otherwise.
environment_is_original() {
    PACKAGE_SIGNATURE=$(adb shell dumpsys package $1 | grep "signatures=PackageSignatures")

    if [[ "$PACKAGE_SIGNATURE" == *"af9694ae"* ]]; then
        return 1
    fi

    return 0
}

cmd_pull_package() {
    if environment_is_original $1
    then
        log_info "skipping modified environment '$1'"
    fi
    
    echo "$1"
    
    adb pull "$(adb shell pm path $1 | awk -F':' '{print $2}')" > /dev/null;
    mv base.apk "$APK_CACHE_PATH/$1.apk";
}

# Pulls all installed environments.
cmd_pull_all() {
    log_info "copying environment apks to '$APK_CACHE_PATH/'"
    
    for i in $(get_installed_environment_list); do
        cmd_pull_package "$i"
    done

    log_info "done." 
}

cmd_pull() {
    verify_adb
    ensure_apk_cache_path

    if [ -z "$1" ]
    then
        cmd_pull_all
    else
        cmd_pull_package "$1"
    fi

}

cmd_list_installed() {
    verify_adb
    
    for i in $(get_installed_environment_list); do
        echo $i
    done
}

cmd_list() {
    log_info "packages in '$APK_CACHE_PATH':"
    
    for i in $(get_cached_environment_list); do
        echo $i
    done
}

cmd_unpack() {
    verify_apktool

    # If a package isn't provided, unpack all of them.
    if [ -z "$1" ]
    then
        log_info "unpacking all cached apks..."
        
        for i in $(get_cached_environment_list); do
            cmd_unpack $i
        done

        exit 0
    fi

    log_info "preparing to unpack $1..."

    # Pull if necessary.
    [ -d "$APK_CACHE_PATH/$1.apk" ] || cmd_pull "$1"
    
    APK_FILENAME="$APK_CACHE_PATH/$1.apk"
    
    UNPACK_DIR=${APK_FILENAME%.*}
    
    if [ ! -f "$APK_FILENAME" ]; then
        log_err "need apk file '$APK_FILENAME'; did you mean to 'pull' it first?"
        exit 1
    fi

    log_info "unpacking '$APK_FILENAME'..."

    clear_directory $UNPACK_DIR

    apktool d "$APK_FILENAME" -f -o "$UNPACK_DIR"
    
    log_info "unpacked to '$UNPACK_DIR'"
}

extract_audio_filename() {
    TMP_DIR="$TMP_PREFIX/audio"
    
    clear_directory "$TMP_DIR"
    
    pushd "$TMP_DIR" > /dev/null

    unzip "$APK_CACHE_PATH/$1/assets/scene.zip" > /dev/null

    echo "$(pwd)/_BACKGROUND_LOOP.ogg"

    popd > /dev/null
}

OVRSCENE_FILE="$TMP_PREFIX"/_WORLD_MODEL.gltf.ovrscene

compress_ktx() {
    GLTF_TMP_DIR="$1"
    EXTENSION="$2"
    MIME_TYPE="$3"

    GLTF_FILENAME="$GLTF_TMP_DIR/models.gltf"

    for i in $(ls "$GLTF_TMP_DIR/"*$EXTENSION 2> /dev/null); do
        [ -f "$i" ] || break
        log_info "converting '$i' to ktx..."
        $(astcenc) -cl $i $(echo "$i" | sed "s/$EXTENSION//g").ktx 8x8 -medium > /dev/null
        rm $i
    done

    sed -i '' "s|$MIME_TYPE|image/ktx|g" "$GLTF_FILENAME"
    sed -i '' "s|$EXTENSION|.ktx|g" "$GLTF_FILENAME"
}

# Compresses the given GLTF file into $OVRSCENE_FILE
compress_model() {
    SCENE_GLTF="$1"
    
    GLTF_SRC_DIR=$(dirname "$SCENE_GLTF")

    GLTF_TMP_DIR="$TMP_PREFIX/_WORLD_MODEL.gltf"
    clear_directory $GLTF_TMP_DIR

    cp -r "$GLTF_SRC_DIR"/* "$GLTF_TMP_DIR"

    log_info "copying files..."

    mv "$GLTF_TMP_DIR"/$(basename "$SCENE_GLTF") "$GLTF_TMP_DIR"/models.gltf

    if [ $(astcenc) ]
    then
        log_info "compressing textures to ktx..."
        compress_ktx "$GLTF_TMP_DIR" .jpg image/jpeg
        compress_ktx "$GLTF_TMP_DIR" .jpeg image/jpeg
        compress_ktx "$GLTF_TMP_DIR" .png image/png
    fi
    #TODO: ktx conversion

    log_info "compressing model..."
    
    pushd "$TMP_PREFIX"/_WORLD_MODEL.gltf > /dev/null
    
    zip -r ../_WORLD_MODEL.gltf.zip .
    
    mv ../_WORLD_MODEL.gltf.zip $OVRSCENE_FILE
    
    popd > /dev/null
}

compress_scene() {
    SCENE_GLTF="$1"
    BACKGROUND_LOOP="$2"
    
    pushd "$TMP_PREFIX" > /dev/null
    
    OVRSCENE_TMP_DIR="$TMP_PREFIX/scene"
    clear_directory $OVRSCENE_TMP_DIR

    mv _WORLD_MODEL.gltf.ovrscene "$OVRSCENE_TMP_DIR"

    log_info "copying audio..."
    cp "$BACKGROUND_LOOP" "$OVRSCENE_TMP_DIR"

    log_info "compressing scene..."
    
    rm -f scene.zip
    
    pushd scene > /dev/null
    
    zip -r ../scene.zip .

    popd > /dev/null
    popd > /dev/null

    #echo "$TMP_PREFIX/scene.zip"
}

pack_all() {
    log_info "packing all environments, this will take a while..."
    
    for i in $(get_cached_environment_list); do
        pack_single $i "$1" "$2"
    done
}

pack_single() {
    PACKAGE_PARENT="$1"
    SCENE_GLTF="$2"
    BACKGROUND_LOOP="$3"

    # Unpack if necessary.
    [ -d "$APK_CACHE_PATH/$PACKAGE_PARENT" ] || cmd_unpack "$1"
    
    if [ -z "$BACKGROUND_LOOP" ]
    then
        BACKGROUND_LOOP=$(extract_audio_filename "$PACKAGE_PARENT")
        log_info "audio track not provided, using default from '$PACKAGE_PARENT'"
    fi

    APK_TMP_DIR="$TMP_PREFIX/apk"
    clear_directory "$APK_TMP_DIR"

    APK_PARENT="$APK_CACHE_PATH/$PACKAGE_PARENT/"

    log_info "copying parent environment package..."

    cp -r "$APK_PARENT" "$APK_TMP_DIR"
    
    compress_scene "$SCENE_GLTF" "$BACKGROUND_LOOP"

    log_info "copying $TMP_PREFIX/scene.zip to $APK_TMP_DIR/assets/scene.zip"
    
    cp "$TMP_PREFIX/scene.zip" "$APK_TMP_DIR/assets/"
    
    log_info "repacking modified apk..."

    PACKED_APK_UNALIGNED="$TMP_PREFIX/environment.apk.unaligned"
    
    apktool b "$APK_TMP_DIR" -o "$PACKED_APK_UNALIGNED"
    
    PACKED_APK="$PACKAGE_PARENT-custom.apk"

    DEBUG_KEYSTORE=~/debug.keystore

    rm -f "$PACKED_APK"
    
    jarsigner -storepass android -keystore "$DEBUG_KEYSTORE" "$PACKED_APK_UNALIGNED" androiddebugkey
    "$ANDROID_SDK_BUILD_TOOLS"/zipalign 4 "$PACKED_APK_UNALIGNED" "$PACKED_APK"

    log_info "done packing into apk '$PACKED_APK'"
}

cmd_pack() {
    verify_apktool

    PACKAGE_PARENT="$1"
    SCENE_GLTF="$2"
    BACKGROUND_LOOP="$3"

    if [ -z "$PACKAGE_PARENT" ]
    then
        log_err "parent environment package name required"

        cmd_usage
    fi
    
    if [ -z "$SCENE_GLTF" ]
    then
        log_err "scene gltf filename required"

        cmd_usage
    fi

    compress_model "$SCENE_GLTF"
    
    if [ "$PACKAGE_PARENT" = "all" ]
    then
        pack_all "$SCENE_GLTF" "$BACKGROUND_LOOP"
        log_info "finished creating new apks."
    else
        pack_single "$PACKAGE_PARENT" "$SCENE_GLTF" "$BACKGROUND_LOOP"
    fi

    #apktool d "$APK_FILENAME" -f -o "$UNPACK_DIR"

    #log_info "unpacked to '$UNPACK_DIR'"
}

cmd_install() {
    verify_adb
    
    APK_FILE="$1"

    if [ -z "$APK_FILE" ]
    then
        log_err "apk filename to install is required"
    fi

    log_info "installing '$APK_FILE'"
    
    EXIT_CODE=0
    
    adb install "$APK_FILE" || EXIT_CODE=$?

    if [ $EXIT_CODE -ne 0 ]
    then
        log_err "error during apk installation (is there an existing environment with the same package name?)"
        exit 1
    fi

    log_info "done."
}

cmd_remove() {
    verify_adb
    
    PACKAGE="$1"

    if [ -z "$PACKAGE" ]
    then
        log_err "name of environment package to remove is required"
    fi

    log_info "uninstalling '$PACKAGE'"

    EXIT_CODE=0

    adb uninstall "$PACKAGE" || EXIT_CODE=$?

    if [ $EXIT_CODE -ne 0 ]
    then
        log_err "failed to uninstall '$PACKAGE'"
        exit 1
    fi

    log_info "done."
}

# Run the correct command.
case "$1" in
    "pull")
        cmd_pull "${@:2}"
        ;;
    "list-installed")
        cmd_list_installed "${@:2}"
        ;;
    "list")
        cmd_list "${@:2}"
        ;;
    "unpack")
        cmd_unpack "${@:2}"
        ;;
    "pack")
        cmd_pack "${@:2}"
        ;;
    "uninstall"|"remove")
        cmd_remove "${@:2}"
        ;;
    "install")
        cmd_install "${@:2}"
        ;;
    *)
        cmd_usage
        ;;
esac
