# Changelog

All notable changes to ScreenCap will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Open source project structure
- Comprehensive English documentation
- Contributing guidelines
- MIT License

### Changed
- Restructured project for open source distribution
- Updated README with complete English documentation
- Improved project architecture documentation

### Removed
- Internal development documentation files
- Spanish-only documentation
- Notarization-specific documentation

## [1.0.0] - 2024-01-XX

### Added
- Screenshot capture functionality (fullscreen, selection, window)
- Customizable file naming with prefix and timestamp options
- Multiple image format support (PNG, JPG, JPEG)
- Floating preview window with drag-and-drop support
- Global keyboard shortcuts (customizable)
- Settings interface with two-tab layout (General and Shortcuts)
- Launch at login functionality
- Menu bar integration
- Error monitoring with Sentry integration
- Auto-close timer for preview window
- Custom save directory selection
- Notification system for capture feedback

### Features
- **Capture Types**:
  - Full screen capture
  - Selection area capture
  - Individual window capture

- **File Management**:
  - Custom file prefix
  - Timestamp inclusion option
  - Multiple format support
  - Custom save directory

- **User Interface**:
  - Clean SwiftUI settings interface
  - Floating preview with drag support
  - Menu bar integration
  - System notification integration

- **Keyboard Shortcuts**:
  - Customizable global shortcuts
  - Default shortcuts for all capture types
  - Settings and quit shortcuts

- **System Integration**:
  - Launch at login support
  - Screen recording permissions handling
  - Notification permissions management

### Technical Details
- Built with Swift and AppKit
- SwiftUI for modern interface components
- KeyboardShortcuts library for global shortcuts
- Sentry integration for error monitoring
- Support for macOS 12.0+

---

## Version History Notes

### Version Numbering
This project follows [Semantic Versioning](https://semver.org/):
- **MAJOR**: Incompatible API changes
- **MINOR**: New functionality (backwards compatible)
- **PATCH**: Bug fixes (backwards compatible)

### Release Types
- **Added**: New features
- **Changed**: Changes in existing functionality
- **Deprecated**: Soon-to-be removed features
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Security improvements

### Future Releases
Upcoming features and improvements will be documented here as they are planned and implemented.