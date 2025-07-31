# Releases and Distribution for ScreenCap

This document explains how ScreenCap's automated release system works and how users can download the application without needing to compile the source code.

## 📦 For End Users

### Quick Download

1. **Go to [GitHub Releases](https://github.com/javierpr0/ScreenCap/releases)**
2. **Download the latest version:**
   - **`ScreenCap.dmg`** (recommended) - Disk image with installer
   - **`ScreenCap.zip`** - Compressed file with the application

### Installation from DMG

1. Open the `ScreenCap.dmg` file
2. Drag `ScreenCap.app` to the `Applications` folder
3. Eject the DMG
4. Go to `Applications` and run ScreenCap

### Installation from ZIP

1. Extract the `ScreenCap.zip` file
2. Move `ScreenCap.app` to your `Applications` folder
3. Run the application from `Applications`

### First Run

⚠️ **Important**: Since the application is not signed by Apple Developer Program:

1. **Right-click** on `ScreenCap.app`
2. **Select "Open"** (don't double-click)
3. **Confirm** that you want to open the application
4. **Grant permissions** when requested:
   - Go to `System Settings > Privacy & Security > Screen Recording`
   - Enable ScreenCap in the list

## 🔧 For Developers and Maintainers

### How the Release System Works

The project uses **GitHub Actions** to completely automate the release process:

```
Developer creates tag → GitHub Actions → Automatic release
     ↓                        ↓              ↓
 git tag v1.1.0         Compiles app      Publishes assets
 git push origin        Generates DMG     Creates release notes
                        Generates ZIP     Notifies users
```

### Creating a New Release

#### Method 1: Automated Script (Recommended)

```bash
# Run the helper script
./create-release.sh 1.1.0

# The script:
# 1. Validates version format
# 2. Verifies tag doesn't exist
# 3. Checks CHANGELOG.md
# 4. Creates and pushes tag
# 5. GitHub Actions does the rest
```

#### Method 2: Manual

```bash
# 1. Update CHANGELOG.md with changes
# 2. Create and push tag
git tag -a v1.1.0 -m "Release v1.1.0"
git push origin v1.1.0

# 3. GitHub Actions will detect the tag and create the release
```

### Workflow Structure

The `.github/workflows/release.yml` file defines the process:

1. **Trigger**: Activates when a tag with format `v*.*.*` is pushed
2. **Build**: Compiles the application on macOS with Xcode
3. **Package**: Creates DMG and ZIP using existing scripts
4. **Release**: Publishes on GitHub with assets and release notes

### Versioning

The project follows **Semantic Versioning** (semver):

- **MAJOR** (1.0.0 → 2.0.0): Incompatible changes
- **MINOR** (1.0.0 → 1.1.0): New compatible features
- **PATCH** (1.0.0 → 1.0.1): Bug fixes

### Generated Assets

Each release automatically includes:

- **`ScreenCap.dmg`** - Disk image for easy installation
- **`ScreenCap.zip`** - Compressed file with the application
- **`INSTALLATION_INSTRUCTIONS.txt`** - Detailed instructions
- **Release Notes** - Automatically generated from CHANGELOG.md

## 🔍 Monitoring and Debugging

### View Release Progress

1. Go to [GitHub Actions](https://github.com/javierpr0/ScreenCap/actions)
2. Look for the most recent "Release" workflow
3. Check logs to see progress or errors

### Common Issues

#### Workflow fails during compilation
- Verify code compiles locally: `make build`
- Check dependencies in `Package.swift`
- Ensure there are no syntax errors

#### DMG is not generated correctly
- Verify `hdiutil` is available on the runner
- Check file permissions
- Ensure `distribute.sh` script works locally

#### Release notes are empty
- Make sure `CHANGELOG.md` has an entry for the version
- Verify format: `## [1.1.0] - 2024-01-15`

## 📊 Statistics and Metrics

### Download Information

You can view download statistics at:
- GitHub Releases page (download counter per asset)
- GitHub Insights (repository traffic)

### Typical Sizes

- **ScreenCap.dmg**: ~15-20 MB
- **ScreenCap.zip**: ~10-15 MB
- **Build time**: ~5-10 minutes

## 🚀 Future Improvements

### Possible Optimizations

1. **Code Signing**: Sign with Apple developer certificate
2. **Notarization**: Notarize application to avoid security warnings
3. **Auto-update**: Implement automatic updates in the application
4. **Multiple Architectures**: Support for Apple Silicon and Intel
5. **Homebrew**: Create formula for installation via Homebrew

### Code Signing and Notarization

To eliminate security warnings, you would need:

1. **Apple Developer Account** ($99/year)
2. **Developer certificate**
3. **Modify workflow** to sign and notarize
4. **Configure secrets** in GitHub for certificates

```yaml
# Example additional steps for signing
- name: Import Code-Signing Certificates
  uses: Apple-Actions/import-codesign-certs@v1
  with:
    p12-file-base64: ${{ secrets.CERTIFICATES_P12 }}
    p12-password: ${{ secrets.CERTIFICATES_P12_PASSWORD }}

- name: Sign Application
  run: |
    codesign --force --deep --sign "Developer ID Application: Your Name" .build/ScreenCap.app

- name: Notarize Application
  run: |
    xcrun notarytool submit .build/ScreenCap.app --keychain-profile "notarytool-profile" --wait
```

## 📞 Support

If you have issues with the release system:

1. Check this document
2. Search existing [Issues](https://github.com/javierpr0/ScreenCap/issues)
3. Create a new issue with specific details
4. Include workflow logs if relevant