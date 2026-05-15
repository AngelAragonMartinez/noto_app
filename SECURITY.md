# Security

Noto keeps data on disk only. It does not send notes anywhere or run analytics.

The vault and attachments use AES-256-GCM. Keys live in the OS keyring via `flutter_secure_storage`. Exports you save are plaintext files by design—treat them like any sensitive file.

If you find a crypto or privacy issue, please open a **private** security advisory on GitHub instead of a public issue.
