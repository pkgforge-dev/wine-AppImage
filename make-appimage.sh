#!/bin/sh

set -eu

ARCH=$(uname -m)
VERSION=$(pacman -Q wine | awk '{print $2; exit}') # example command to get version of application here
export ARCH VERSION
export OUTPATH=./dist
export ADD_HOOKS="self-updater.bg.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export ICON=https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-icon-theme/bcf6aa9582f676e1c93d0022319e6055cd1f2de2/Papirus/64x64/apps/wine.svg
export DESKTOP=/usr/share/applications/wine.desktop
export APPNAME=wine
export ANYLINUX_LIB=1
export DEPLOY_SDL=1
export DEPLOY_PIPEWIRE=1
export DEPLOY_VULKAN=1
export DEPLOY_OPENGL=1

# Deploy dependencies
quick-sharun \
	/usr/bin/wine*            \
	/usr/lib/wine             \
	/usr/bin/msidb            \
	/usr/bin/msiexec          \
	/usr/bin/notepad          \
	/usr/bin/regedit          \
	/usr/bin/regsvr32         \
	/usr/bin/widl             \
	/usr/bin/wmc              \
	/usr/bin/wrc              \
	/usr/bin/function_grep.pl \
	/usr/lib/libfreetype.so*  \
	/usr/lib/libharfbuzz*     \
    /usr/lib/libgraphite*     \
	/usr/lib/libavcodec.so*	  \
	/usr/bin/zenity

# Install latest winetricks
wget --retry-connrefused --tries=30 https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks -O ./AppDir/bin/winetricks
chmod +x ./AppDir/bin/winetricks

# alright here the pain starts
ln -sr ./AppDir/lib/wine/x86_64-unix/*.so* ./AppDir/bin

# this gets broken by sharun somehow
kek=.$(tr -dc 'A-Za-z0-9_=-' < /dev/urandom | head -c 10)
rm -f ./AppDir/lib/wine/x86_64-unix/wine
cp /usr/lib/wine/x86_64-unix/wine ./AppDir/lib/wine/x86_64-unix/wine
patchelf --set-interpreter /tmp/"$kek" ./AppDir/lib/wine/x86_64-unix/wine
patchelf --add-needed anylinux.so ./AppDir/shared/lib/wine/x86_64-unix/wine

cat <<EOF > ./AppDir/bin/random-linker.src.hook
#!/bin/sh
cp -f "\$APPDIR"/shared/lib/ld-linux*.so* /tmp/"$kek"
EOF
chmod +x ./AppDir/bin/*.hook

# Set the lib path to also use wine libs
echo 'LD_LIBRARY_PATH=${APPDIR}/lib:${APPDIR}/lib/pulseaudio:${APPDIR}/lib/alsa-lib:${APPDIR}/lib/wine/x86_64-unix' >> ./AppDir/.env

# lib/wine/x86_64-unix/wine will try to execute a relative ../../bin/wineserver
# which resolves to shared/bin/wineserver and it is wrong
# so we have to make AppDir/shared/lib the symlink and AppDir/lib the real directory
# that way ../../bin/wineserver resolves to the sharun hardlink
if [ -L ./AppDir/lib ]; then
	rm -f ./AppDir/lib
	mv ./AppDir/shared/lib ./AppDir
	ln -sr ./AppDir/lib ./AppDir/shared
fi

# remove wine static libs
find ./AppDir/lib/ -type f -name '*.a'
find ./AppDir/lib/ -type f -name '*.a' -delete

# strip windows libs, inspired by alpine linux: 
# https://gitlab.alpinelinux.org/alpine/aports/-/blob/master/community/wine/APKBUILD
if [ "$ARCH" = 'x86_64' ]; then
	x86_64-w64-mingw32-strip -R .comment --strip-unneeded ./AppDir/lib/wine/x86_64-windows/*.dll
	i686-w64-mingw32-strip   -R .comment --strip-unneeded ./AppDir/lib/wine/i386-windows/*.dll
fi

# Turn AppDir into AppImage
quick-sharun --make-appimage
