clang -framework AppKit -framework Carbon -o KeyboardSwitcher AppDelegate.m main.m

mkdir -p KeyboardSwitcher.app
rm -rf KeyboardSwitcher.app
mkdir -p KeyboardSwitcher.app/Contents/MacOS
cp KeyboardSwitcher KeyboardSwitcher.app/Contents/MacOS/
cp Info.plist KeyboardSwitcher.app/Contents/