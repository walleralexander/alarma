# Changelog

All notable changes to Alarma! will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-31

### Added
- Initial public release
- Multi-channel notification gateway supporting:
  - SMS via Android smartphone
  - WhatsApp via Android smartphone
  - Signal Messenger
  - Microsoft Teams
  - Email (SMTP)
  - Push notifications (ntfy)
- Docker Compose deployment setup
- Apprise API integration for unified routing
- Tag-based routing system (critical, warning, info)
- PowerShell integration module
- PRTG Network Monitor integration
- System monitoring scripts
- Backup and restore scripts (PowerShell and Bash)
- Multi-language documentation (German, English, French)
- High availability setup guide
- Security best practices documentation
- Secrets management guide
- Example configurations for all services

### Documentation
- Comprehensive README in 3 languages
- Installation and setup guides
- PowerShell scripts documentation
- Docker configuration examples
- Troubleshooting guides
- Architecture diagrams

### Security
- AI-generated code disclaimer
- Environment variable templates
- .gitignore for sensitive data
- Security policy documentation

---

## [Unreleased]

### Planned Features
- Telegram notification support
- Discord webhook support
- Slack integration
- Kubernetes/Helm deployment
- Automated testing suite
- Web UI for configuration
- Notification history and logging
- Rate limiting per channel
- Notification scheduling

---

**Legend:**
- `Added` - New features
- `Changed` - Changes in existing functionality
- `Deprecated` - Soon-to-be removed features
- `Removed` - Removed features
- `Fixed` - Bug fixes
- `Security` - Security improvements
