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

# Deploy dependencies
quick-sharun \
	/usr/bin/wine*    \
	/usr/lib/wine     \
	/usr/bin/msidb    \
	/usr/bin/msiexec  \
	/usr/bin/notepad  \
	/usr/bin/regedit  \
	/usr/binregsvr32  \
	/usr/bin/widl     \
	/usr/bin/wmc      \
	/usr/bin/wrc      \
	/usr/bin/function_grep.pl

# alright here the pain starts
ln -sr ./AppDir/lib/wine/x86_64-unix/*.so* ./AppDir/bin

# this gets broken by sharun somehow
kek=.$(tr -dc 'A-Za-z0-9_=-' < /dev/urandom | head -c 10)
rm -f ./AppDir/lib/wine/x86_64-unix/wine
cp /usr/lib/wine/x86_64-unix/wine ./AppDir/lib/wine/x86_64-unix/wine
patchelf --set-interpreter /tmp/"$kek" ./AppDir/lib/wine/x86_64-unix/wine
patchelf --set-interpreter /tmp/"$kek" ./AppDir/shared/bin/wineserver

cat <<EOF > ./AppDir/bin/random-linker.src.hook
#!/bin/sh
cp -f "\$APPDIR"/shared/lib/ld-linux*.so* /tmp/"$kek"
export LD_LIBRARY_PATH="\$APPDIR/lib:\$APPDIR/lib/wine/x86_64-unix"
EOF
chmod +x ./AppDir/bin/*.hook

# Turn AppDir into AppImage
quick-sharun --make-appimage
