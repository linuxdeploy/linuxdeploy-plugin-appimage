# linuxdeploy-plugin-appimage

Creates AppImages from AppDirs. For use with [linuxdeploy](https://github.com/TheAssassin/linuxdeploy).


## Usage

As this software is concepted as a plugin for linuxdeploy, it is recommended to use it as such.


### Usage with linuxdeploy

When calling linuxdeploy, just add `--output appimage` to enable the plugin. After completing the bundling process and running e.g., input plugins, linuxdeploy will then call the AppImage plugin to create an AppImage from the AppDir.

*For more information, see the [official AppImage packaging guide](https://docs.appimage.org/packaging-guide/native-binaries.html).*



### Standalone usage

Like all linuxdeploy plugins, linuxdeploy-plugin-appimage is a standalone tool and can be used without linuxdeploy.

Please see the `--help` test for more information.


### Updating the AppImage plugin

The official linuxdeploy AppImage ships with a fairly recent version of the plugin. You can at any time still download the AppImage from the [release page](https://github.com/linuxdeploy/linuxdeploy-plugin-appimage/releases/), and put it into the same directory as linuxdeploy. Then, linuxdeploy will use the AppImage instead of the bundled version.

*For more information on how linuxdeploy's plugin system works, please refer to [the documentation](https://docs.appimage.org/packaging-guide/linuxdeploy-user-guide.html#plugin-system).*

### Optional variables

linuxdeploy-plugin-appimage can be configured using environment variables.

- `UPDATE_INFORMATION="..."`: embed [update information](https://github.com/AppImage/AppImageSpec/blob/master/draft.md#update-information) in the AppImage, and generate corresponding `.zsync` file
- `SIGN=1`: set this variable to any value to enable signing of the AppImage
- `SIGN_KEY=key_id`: GPG Key ID to use for signing. This environment variable is only used if `SIGN` is set.
- `VERBOSE=1`: set this variable to any value to enable verbose output
- `OUTPUT=filename`: change filename of resulting AppImage
