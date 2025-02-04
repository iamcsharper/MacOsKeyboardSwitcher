# ⌨️ MacOsKeyboardSwitcher

**Switch keyboard layouts with style!** 🚀  
A lightweight macOS utility that lets you cycle between input sources using **⌘ Command + Shift** hotkey. Perfect for multilingual users! 🌍

<img src="https://img.shields.io/badge/platform-macOS-lightgrey?style=flat&logo=apple" alt="Platform"> 
<img src="https://img.shields.io/badge/requires-10.15%2B-blue?style=flat&logo=apple" alt="macOS Version"> 
<img src="https://img.shields.io/badge/license-MIT-green?style=flat" alt="License">

## ✨ Features

- 🔥 **Instant switching** with ⌘ Cmd + Shift hotkey
- 🎯 Supports all installed keyboard layouts
- 🌈 Seamless background operation
- 🧘 Minimal resource usage (0% CPU when idle)
- 🔐 Privacy focused - no internet access required

## 🚀 Build from sources

- `git clone https://github.com/iamcsharper/MacOsKeyboardSwitcher`
- cd MacOsKeyboardSwitcher
- sh ./build.sh
- Manually copy KeyboardSwitcher.app to your `Applications` folder
- 🔑 Permission Issues
Re-check Accessibility permissions
Add the app in Security & Privacy settings
 
## 📝 Debugging

```bash
# View real-time logs
log stream --predicate 'process == "KeyboardSwitcher"'
```

## 🤝 Contributing
PRs welcome! 👾
Please follow standard GitHub flow:

1. Fork repo
2. Create feature branch
3. Commit changes
4. Push to branch
5. Open PR

📜 License
MIT © Ilya Yurchenko