
# Oculus Environment Toolbox

**USE AT YOUR OWN RISK. THIS SCRIPT MIGHT DELETE DATA OR PERFORM OTHER IRREPARABLE HARM.**

Tools to extract, modify, and install custom Oculus Quest environments.

# Installation

* Install `adb`
* Install `apktool`
* Set `ANDROID_SDK_BUILD_TOOLS` to the build tools directory containing `zipalign`.

Example:

```
ANDROID_SDK_BUILD_TOOLS=/opt/homebrew/Caskroom/android-sdk/4333796/build-tools/30.0.1
pack
```

# Usage

```sh
$ # Must be run first. This pulls and saves all the default environments.
$ oculus-environment-toolbox pull
...
$ # Unpacks the saved environments with apktool.
$ oculus-environment-toolbox unpack
...
$ # To pack the scene, replacing the `com.oculus.environment.prod.rifthome` environment:
$ oculus-environment-toolbox pack com.oculus.environment.prod.rifthome export/scene.gltf
...
$ # Uninstall the default environment.
$ oculus-environment-toolbox remove com.oculus.environment.prod.rifthome 
...
$ # Install the modified environment.
$ oculus-environment-toolbox install com.oculus.environment.prod.rifthome-custom.apk
...
$ Done!
```
