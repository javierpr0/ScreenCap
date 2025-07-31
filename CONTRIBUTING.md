# Contributing to ScreenCap

Thank you for your interest in contributing to ScreenCap! This document provides guidelines and information for contributors.

## 🚀 Getting Started

### Prerequisites

- macOS 12.0 or later
- Xcode 14.0 or later
- Swift 5.7 or later
- Git

### Development Setup

1. **Fork and Clone**
   ```bash
   git clone https://github.com/javierpr0/ScreenCap.git
   cd screencap
   ```

2. **Build the Project**
   ```bash
   make build
   ```

3. **Run the Application**
   ```bash
   make run
   ```

## 📋 Development Guidelines

### Code Style

- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Add documentation comments for public APIs
- Keep functions focused and concise
- Use SwiftUI best practices for UI components

### Project Structure

- **ScreenCapApp.swift**: Main application entry point
- **ScreenshotManager.swift**: Core screenshot functionality
- **SettingsView.swift**: Configuration interface
- **FloatingPreviewWindow.swift**: Preview window implementation
- **ImageDragView.swift**: Drag and drop functionality

### Testing

- Test your changes thoroughly on different macOS versions
- Verify keyboard shortcuts work correctly
- Test screenshot capture in various scenarios
- Ensure settings persist correctly

## 🐛 Bug Reports

When reporting bugs, please include:

- macOS version
- ScreenCap version
- Steps to reproduce
- Expected vs actual behavior
- Screenshots if applicable
- Console logs if relevant

## ✨ Feature Requests

For new features:

- Check existing issues first
- Describe the use case
- Explain why it would be valuable
- Consider implementation complexity
- Be open to discussion and feedback

## 🔄 Pull Request Process

### Before Submitting

1. **Create an Issue**: Discuss major changes first
2. **Fork the Repository**: Work on your own copy
3. **Create a Branch**: Use descriptive branch names
   ```bash
   git checkout -b feature/add-new-format
   git checkout -b fix/preview-window-bug
   ```

### Commit Guidelines

Use conventional commit format:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

**Examples:**
```
feat(capture): add HEIF format support
fix(preview): resolve window positioning issue
docs(readme): update installation instructions
```

### Pull Request Checklist

- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated if needed
- [ ] No breaking changes (or clearly documented)
- [ ] Tested on multiple macOS versions
- [ ] Commit messages follow convention

## 🏗️ Architecture Notes

### Key Design Principles

1. **Simplicity**: Keep the UI clean and intuitive
2. **Performance**: Minimize resource usage
3. **Reliability**: Handle edge cases gracefully
4. **Accessibility**: Support macOS accessibility features

### Important Considerations

- **Permissions**: Handle screen recording permissions properly
- **Memory Management**: Avoid memory leaks with image handling
- **Threading**: Use appropriate queues for UI vs background work
- **Error Handling**: Provide meaningful error messages

## 🔧 Common Development Tasks

### Adding New Screenshot Formats

1. Update `ScreenshotManager.swift`
2. Add format to settings UI
3. Update file extension handling
4. Test with various image sizes

### Modifying Keyboard Shortcuts

1. Update `KeyboardShortcutNames.swift`
2. Modify settings interface
3. Test for conflicts with system shortcuts
4. Update documentation

### UI Changes

1. Follow SwiftUI best practices
2. Test on different screen sizes
3. Ensure dark mode compatibility
4. Verify accessibility support

## 📚 Resources

- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [macOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/macos)
- [AppKit Documentation](https://developer.apple.com/documentation/appkit)

## 🤝 Community

- Be respectful and inclusive
- Help others learn and grow
- Share knowledge and best practices
- Provide constructive feedback

## ❓ Questions?

If you have questions about contributing:

1. Check existing issues and discussions
2. Create a new issue with the "question" label
3. Be specific about what you need help with

Thank you for contributing to ScreenCap! 🎉