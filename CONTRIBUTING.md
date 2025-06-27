# Contributing to Limit

Thank you for your interest in contributing to Limit! This document provides guidelines and information for contributors.

## 🤝 How to Contribute

### Reporting Issues

Before creating an issue, please:

1. **Search existing issues** to avoid duplicates
2. **Use the issue template** and provide all requested information
3. **Include steps to reproduce** the problem
4. **Add screenshots** if applicable
5. **Specify your device and iOS version**

### Feature Requests

We welcome feature requests! Please:

1. **Describe the feature** clearly and concisely
2. **Explain the use case** and why it would be valuable
3. **Consider the impact** on existing functionality
4. **Be patient** - we review all requests carefully

### Code Contributions

#### Getting Started

1. **Fork the repository**
2. **Create a feature branch** from `main`
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes** following our coding standards
4. **Test thoroughly** on different devices/simulators
5. **Commit with clear messages**
6. **Submit a pull request**

#### Coding Standards

- **SwiftUI Best Practices**:
  - Use `@Observable` for state management
  - Keep views simple and focused
  - Prefer composition over inheritance
  - Use proper error handling

- **Code Style**:
  - Follow Swift naming conventions
  - Use meaningful variable and function names
  - Add comments for complex logic
  - Keep functions small and focused

- **File Organization**:
  - Place new views in appropriate directories
  - Group related functionality together
  - Use clear file names

#### Testing

Before submitting a pull request:

- [ ] **Build successfully** on latest Xcode
- [ ] **Test on iOS simulator** (iPhone and iPad)
- [ ] **Test on physical device** if possible
- [ ] **Verify no memory leaks** or performance issues
- [ ] **Check accessibility** features work

#### Pull Request Guidelines

1. **Clear title** describing the change
2. **Detailed description** of what was changed and why
3. **Screenshots** for UI changes
4. **Test instructions** for reviewers
5. **Link related issues** if applicable

### Documentation

Help improve our documentation:

- **README updates** for new features
- **Code comments** for complex logic
- **API documentation** for new endpoints
- **User guides** for new functionality

## 🛠️ Development Setup

### Prerequisites

- Xcode 15.0 or later
- iOS 17.0 or later
- macOS 14.0 or later
- Git

### Local Development

1. **Clone your fork**:
   ```bash
   git clone https://github.com/yourusername/limit.git
   cd limit
   ```

2. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/zdenekindra/limit.git
   ```

3. **Open in Xcode**:
   ```bash
   open Limit.xcodeproj
   ```

4. **Configure project**:
   - Update Bundle ID if needed
   - Set Development Team for device testing

### Building and Testing

```bash
# Clean build
xcodebuild clean -project Limit.xcodeproj -scheme Limit

# Build for simulator
xcodebuild build -project Limit.xcodeproj -scheme Limit -destination 'platform=iOS Simulator,name=iPhone 15'

# Run tests (when available)
xcodebuild test -project Limit.xcodeproj -scheme Limit
```

## 📋 Issue Labels

We use the following labels to organize issues:

- **bug**: Something isn't working
- **enhancement**: New feature or request
- **documentation**: Improvements or additions to documentation
- **good first issue**: Good for newcomers
- **help wanted**: Extra attention is needed
- **question**: Further information is requested

## 🎯 Areas for Contribution

### High Priority

- **Bug fixes** and stability improvements
- **Performance optimizations**
- **Accessibility improvements**
- **Error handling** enhancements

### Medium Priority

- **UI/UX improvements**
- **New features** (discuss first)
- **Code refactoring**
- **Documentation updates**

### Low Priority

- **Cosmetic changes**
- **Code style improvements**
- **Minor optimizations**

## 📞 Getting Help

- **GitHub Issues**: For bugs and feature requests
- **GitHub Discussions**: For questions and general discussion
- **Code Reviews**: For feedback on pull requests

## 📄 License

By contributing to Limit, you agree that your contributions will be licensed under the MIT License.

## 🙏 Recognition

Contributors will be recognized in:

- **README.md** contributors section
- **Release notes** for significant contributions
- **GitHub contributors** page

---

Thank you for contributing to Limit! 🚀 