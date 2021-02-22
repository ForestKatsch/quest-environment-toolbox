
# Quest Environment Toolbox

**USE AT YOUR OWN RISK.
THIS SCRIPT MIGHT DELETE DATA OR PERFORM OTHER IRREPARABLE HARM.
IT IS NOT ENDORSED BY OR OTHERWISE AFFILIATED WITH FACEBOOK/OCULUS.
DO NOT USE THIS UNLESS YOU ARE FULLY AWARE OF HOW DANGEROUS SHELL SCRIPTS CAN BE, AND ARE PREPARED TO TAKE THAT RISK ONTO YOURSELF.**

**I wrote this in a few hours late at night. Do not use this unless you know exactly what you're doing and have read the entire script.**

**Seriously, don't trust this script.**

Tools to extract, modify, repack, and install custom Oculus Quest environments.

# Installation

* Install `adb`
* Install `apktool`
* Set `ANDROID_SDK_BUILD_TOOLS` to the build tools directory containing `zipalign`.
* (Optional) install `astcenc` from https://github.com/ARM-software/astc-encoder/releases and add it to your path. Quest Environment Toolbox will automatically discover this and (hackily) rewrite jpg/png files to KTX.

Example:

```
export ANDROID_SDK_BUILD_TOOLS=/opt/homebrew/Caskroom/android-sdk/4333796/build-tools/30.0.1
```

# Usage

```sh
$ # Automatically pulls and unpacks existing environments with apktool. (Quest must be plugged in.)
$ quest-environment-toolbox unpack
...
$ # This doesn't need the Quest to be plugged in.
$ # To pack the scene, replacing the `com.oculus.environment.prod.rifthome` environment:
$ quest-environment-toolbox pack com.oculus.environment.prod.rifthome export/scene.gltf
...
$ # Uninstall the default environment. (Very important!)
$ quest-environment-toolbox remove com.oculus.environment.prod.rifthome 
...
$ # Install the modified environment.
$ quest-environment-toolbox install com.oculus.environment.prod.rifthome-custom.apk
...
$ Done!
```

If the Quest is plugged in, you do not need to `unpack` first.
(Note that packing with the special package name 'all' requires `unpack` to be run first; otherwise, only cached environments will be built.)

# License

Copyright 2021 Forest Katsch

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

