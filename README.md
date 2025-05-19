# MacbookSetup

[![Build Status](https://api.cirrus-ci.com/github/yourusername/MacbookSetup.svg)](https://cirrus-ci.com/github/yourusername/MacbookSetup)

A streamlined, automated setup script for macOS development environments. Get your Mac ready for development in minutes, not hours.

## 🚀 Purpose

Setting up a new Mac for development is time-consuming and error-prone. This project aims to solve that by providing:

- A single command to install all necessary development tools
- Consistent configuration across different machines
- Reproducible development environments
- Easy onboarding for new team members or after OS reinstalls

## 📦 What's Included

This setup automates the installation and configuration of:

### Core Tools
- **Homebrew**: Package manager for macOS
- **Git**: Version control system
- **Direnv**: Environment variable management per directory

### Development Environments
- **Ruby** (via rbenv): Ruby version manager with latest stable Ruby
- **Python** (via pyenv): Python version manager with latest stable Python

### Terminal and Editor Tools
- **iTerm2**: Enhanced terminal emulator
- **Warp**: Modern terminal with AI features
- **Zinit**: Z shell plugin manager
- **Other tools**: See the Brewfile for the complete list

### Configuration
- Shell environment configuration (.zshrc)
- Tool initialization and setup
- Path configuration

## 🔧 Usage

### Quick Start

```bash
# Clone the repository
git clone https://github.com/yourusername/MacbookSetup.git
cd MacbookSetup

# Make the script executable
chmod +x setup.sh

# Run the setup
./setup.sh
```

### What It Does

1. Checks if Homebrew is installed; installs it if needed
2. Installs all packages from the Brewfile
3. Configures your shell with necessary tool integrations
4. Installs the latest stable Ruby and Python versions
5. Sets up development environments ready to use

### Customization

To customize your setup, modify the `Brewfile` before running the script. Add or remove packages as needed:

```ruby
# Add a formula (CLI tool)
brew "your-package-name"

# Add a cask (GUI application)
cask "your-app-name"
```

## 📋 Requirements

- macOS Catalina (10.15) or newer
- Administrative privileges on your Mac
- Internet connection
- For Apple Silicon Macs (M1/M2/M3): Rosetta 2 is recommended (`softwareupdate --install-rosetta`)

## 🧪 Continuous Integration

This project uses Cirrus CI to validate the setup script on real macOS environments:

- Every commit is tested on macOS ARM (Apple Silicon) virtual machines
- The setup script is executed in a clean environment
- Installation of tools and configuration is verified

You can view CI build history on the [Cirrus CI dashboard](https://cirrus-ci.com/github/yourusername/MacbookSetup).

## 📄 License

This project is licensed under the MIT License - see below for details:

```
MIT License

Copyright (c) 2025 Your Name

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

