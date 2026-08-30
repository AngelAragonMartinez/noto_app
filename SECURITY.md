# Security

Noto keeps data on disk only. It does not send notes anywhere, and it makes no
network requests or analytics calls of any kind.

## What is encrypted

The vault, per-note attachments, and images embedded in note bodies all use
**AES-256-GCM**, with a fresh nonce per operation. Keys are generated with a
cryptographically secure random source and live in the OS keyring via
`flutter_secure_storage` — never on disk in plaintext.

Exports you save are plaintext files by design. Treat them like any sensitive
document.

## Where the data is

| Platform | Notes folder |
|---|---|
| Windows | `%APPDATA%\Noto contributors\Noto\notes_app\` |
| Linux | `~/.local/share/noto/notes_app/` |

`vault.enc`, `attachments/` and `inline_images/` inside it are
encrypted. `exports/` is not — it is where the Save-as dialog opens by
default, and exports are plaintext by design.

Uninstalling Noto does not touch this folder. Removing your notes is a
deliberate, manual, irreversible step.

## What is not protected

- **Opening an attachment** writes a decrypted copy to the system temp
  directory so the OS can hand it to its default application. Noto deletes
  those copies when it exits, and sweeps any a crash left behind on the next
  launch — but while an attachment is open, a plaintext copy exists.
- Noto does not defend against an attacker who already has code execution as
  your user account. At that point the keyring is reachable and so is the
  vault.

## Reporting

If you find a crypto or privacy issue, please open a
[private security advisory](https://github.com/AngelAragonMartinez/noto_app/security/advisories/new)
rather than a public issue.
