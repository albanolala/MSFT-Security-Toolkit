# MSFT-Security-Toolkit

A collection of PowerShell scripts for Microsoft Security — Entra ID, Microsoft Defender XDR, and Microsoft Security Copilot.

Scripts are organized by product area. Each folder contains its own README with usage instructions and prerequisites.

---

## Structure

| Folder | Description |
|--------|-------------|
| [entra-rbac](./entra-rbac/) | Entra ID role assignment export and Unified RBAC migration toward Microsoft Defender XDR |

More folders coming as scripts are added.

---

## General Requirements

- PowerShell 5.1 or PowerShell 7+ (scripts are compatible with both)
- Microsoft.Graph PowerShell SDK >= 2.0
- Appropriate permissions on the target tenant (documented per script)

---

## Contributing

Issues and pull requests are welcome.  
Please test on both Windows PowerShell 5.1 and PowerShell 7+ before submitting.

---

## License

MIT — see [LICENSE](LICENSE) for full text.
