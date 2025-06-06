# Contributing to MacbookSetup

First off, thank you for considering contributing to MacbookSetup! It's people like you that make this tool useful for the community. This document provides guidelines and steps for contributing.

## Ways to Contribute

There are many ways to contribute to this project:

- Reporting bugs and issues
- Suggesting new features or enhancements
- Improving documentation
- Submitting code improvements or fixes
- Testing on different macOS versions

Every contribution, no matter how small, is valuable and appreciated!

## Submitting Issues

If you encounter a problem with the setup script or have a feature request, please submit an issue. Here's how to create a helpful issue:

1. **Check existing issues** first to avoid duplicates
2. **Use a clear, descriptive title**
3. **Provide detailed information** including:
   - Your macOS version
   - Steps to reproduce the issue
   - Expected vs. actual behavior
   - Error messages or logs
   - Screenshots if relevant

For feature requests, explain the use case and benefits clearly.

## Pull Request Process

Want to contribute code? Great! Here's how to submit a pull request:

1. **Fork the repository** to your GitHub account
2. **Create a new branch** from `main` with a descriptive name:
   ```
   git checkout -b feature/your-feature-name
   ```
   or
   ```
   git checkout -b fix/issue-you-are-fixing
   ```
3. **Make your changes**, following our code style guidelines
4. **Test your changes** thoroughly (see Testing Guidelines below)
5. **Commit your changes** with clear, descriptive commit messages:
   ```
   git commit -m "Add feature: description of what you added"
   ```
6. **Push to your branch**:
   ```
   git push origin feature/your-feature-name
   ```
7. **Open a pull request** against the `main` branch
8. **Describe your changes** in the PR description, linking to any related issues

Your PR will be reviewed as soon as possible. We might request changes or ask questions to improve your contribution.

## Code Style Guidelines

For shell scripts:

- Use 2-space indentation
- Add comments for complex logic
- Use meaningful variable and function names
- Follow [Google's Shell Style Guide](https://google.github.io/styleguide/shellguide.html) where applicable
- Make scripts compatible with both Bash and Zsh where possible
- Use `#!/bin/bash` as the shebang line for scripts

For documentation:

- Use Markdown for all documentation files
- Keep line length reasonable (ideally under 100 characters)
- Use proper headings and formatting for readability

## Testing Guidelines

Before submitting your PR, please ensure:

1. **Your changes work on a clean macOS installation** if possible
2. **The setup script runs without errors**
3. **The script is idempotent** (can be run multiple times without issues)
4. **All tools install and configure correctly**
5. **Add tests** for new functionality if applicable

For testing locally:

```bash
# Make sure your script is executable
chmod +x setup.sh

# Run in verbose mode for testing
./setup.sh
```



## Questions?

If you have any questions about contributing, feel free to open an issue labeled "question" and we'll be happy to help!

---

Thank you for taking the time to contribute! Your efforts help make this project better for everyone.
