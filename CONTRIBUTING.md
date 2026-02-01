# Contributing to Alarma!

Thank you for your interest in contributing to Alarma! We welcome contributions from the community.

## 🤝 How to Contribute

### Reporting Bugs

If you find a bug, please create an issue with:

- Clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Your environment (OS, Docker version, etc.)
- Relevant logs or error messages

### Suggesting Features

Feature requests are welcome! Please:

- Check if the feature has already been requested
- Clearly describe the use case
- Explain how it would benefit users
- Consider implementation complexity

### Pull Requests

We love pull requests! Here's how to contribute code:

1. **Fork the repository**
   ```bash
   git clone https://github.com/walleralexander/alarma.git
   cd alarma
   ```

2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**
   - Follow existing code style
   - Update documentation if needed
   - Test your changes thoroughly

4. **Commit your changes**
   ```bash
   git commit -m "Add feature: description"
   ```

5. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Open a Pull Request**
   - Describe what your PR does
   - Reference any related issues
   - Explain how you tested it

## 📋 Guidelines

### Code Style

- **Docker Compose**: Use consistent indentation (2 spaces)
- **Shell Scripts**: Follow ShellCheck recommendations
- **PowerShell**: Use approved verbs and PascalCase for functions
- **YAML**: Use 2-space indentation, no tabs
- **Markdown**: Follow markdownlint rules

### Documentation

- Update README.md if you change functionality
- Add comments to complex configurations
- Keep examples simple and clear
- Support multiple languages when possible (EN, DE, FR)

### Testing

Before submitting a PR:

- [ ] Test with a clean Docker environment
- [ ] Verify all docker-compose services start
- [ ] Check that example configs work
- [ ] Run markdown linter on documentation
- [ ] Test on both Linux and Windows (if applicable)

### Commit Messages

- Use clear, descriptive commit messages
- Start with a verb (Add, Fix, Update, Remove)
- Reference issue numbers when applicable
- Examples:
  - `Add support for Telegram notifications`
  - `Fix WhatsApp gateway connection issue #123`
  - `Update installation documentation`

## 🏗️ Development Setup

### Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- Git
- Text editor with YAML/Markdown support

### Local Development

1. Clone your fork
2. Create `.env` from `.env.example`
3. Update configuration files with test values
4. Run `docker-compose up -d`
5. Test your changes

### Useful Commands

```bash
# View logs
docker-compose logs -f

# Restart a service
docker-compose restart apprise-api

# Rebuild after changes
docker-compose up -d --build

# Stop all services
docker-compose down
```

## 🔒 Security

- **Never commit secrets** (.env, API keys, passwords)
- Use `.env.example` for templates only
- Report security vulnerabilities privately via GitHub Security Advisories

## 📝 Documentation

When adding features, please update:

- Main README.md (all language versions)
- Relevant documentation files
- Example configurations
- CHANGELOG.md

## 🌍 Translations

We support multiple languages:

- English (README.en.md)
- German (README.md)
- French (README.fr.md)

If you update documentation, please update all language versions or note which need translation.

## ❓ Questions

- Check existing issues and discussions
- Read the documentation thoroughly
- Ask in GitHub Discussions for general questions
- Open an issue for specific problems

## 🎯 Priority Areas

We're especially interested in contributions for:

- Additional notification channels (Telegram, Discord, Slack)
- Kubernetes/Helm chart deployment
- Automated testing
- Security improvements
- Documentation improvements
- Translation to other languages

## 📜 License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for making Alarma! better! 🎉
