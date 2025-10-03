# Software Management

Automate **software deployment, updates, and patch compliance** across Windows hosts. Scripts are designed to be **parameterized** and **GUI-ready** (every environment-specific input can be prompted at runtime).

---

## Prerequisites
- Admin access to target computers (ADMIN$ shares, remote process/service permissions)
- Access to software share(s) (UNC paths)
- For patch reporting: Windows Update service + access to WSUS or Microsoft Update
- Optional: Winget installed on desktops if you use the `-UseWinget` mode

---

## Scripts

### 1) [InstallSoftware.ps1](./InstallSoftware/) ✅ **IMPLEMENTED**
Silently installs MSI/EXE packages on one or more computers, with **post-install detection** and CSV/log output.

**Examples**
```powershell
# MSI install with ProductCode detection
.\InstallSoftware.ps1 -ComputerName server01,server02 `
  -InstallerPath \\filesrv\sw\AcmeClient.msi `
  -ProductCode '{11111111-2222-3333-4444-555555555555}' `
  -SilentArgs "/qn /norestart" -Verbose

# EXE install with DisplayName detection and version gating
.\InstallSoftware.ps1 -ComputerName (gc .\hosts.txt) `
  -InstallerPath \\filesrv\sw\AcmeSetup.exe -InstallerType EXE -SilentArgs "/S /v/qn" `
  -DisplayNameContains "Acme Client" -MinimumVersion "10.5.0" -OutputCsv .\install_results.csv -Verbose
```

**Adjust for your environment:**
- Installer UNC path & silent switches
- Detection method (ProductCode vs DisplayName)
- MinimumVersion gate (optional)
- Credentials for remote install
- Log/CSV output paths

### 2) [UpdateSoftware.ps1](./UpdateSoftware/) ✅ **IMPLEMENTED**
Update an application to a target version using either a new installer or winget (if present).

**Examples**
```powershell
# Update via installer when current version < target
.\UpdateSoftware.ps1 -ComputerName server01 `
  -ProductCode '{111...}' -TargetVersion 10.6.0 `
  -InstallerPath \\fs\sw\AcmeClient_10.6.0.msi -SilentArgs "/qn /norestart" -Verbose

# Use winget for desktops
.\UpdateSoftware.ps1 -ComputerName desktop01 -UseWinget -WingetId "Acme.Client" -TargetVersion 10.6.0 -Verbose
```

**Adjust for your environment:**
- TargetVersion (semantic)
- Installer vs Winget mode
- ProductCode/DisplayName detection
- SilentArgs per vendor
- Credentials & CSV output path

### 3) [PatchComplianceReport.ps1](./PatchComplianceReport/) ✅ **IMPLEMENTED**
Check Windows Update for not yet installed updates to gauge patch compliance; outputs a per-host summary and optional titles.

**Examples**
```powershell
# Large fleet to CSV with pending titles
.\PatchComplianceReport.ps1 -ComputerName (gc .\servers.txt) -IncludeTitles -OutputCsv .\patch_report.csv

# Single server
.\PatchComplianceReport.ps1 -ComputerName server01 -Verbose
```

**Adjust for your environment:**
- WSUS vs Microsoft Update connectivity/policy
- Titles included or not
- CSV output path
- Credentials for remote execution

---

## Tips

- Keep a silent switch catalog per vendor in your docs.
- Prefer ProductCode for MSI detection; fallback to DisplayName when needed.
- Stage installers on a reliable SMB share and verify AV exclusions if necessary.
- Pilot on a small set of machines; then scale out.

---

## Future GUI Integration Ideas

- File/Folder pickers for installers and logs
- Preset library for silent switches (per vendor)
- Detection helpers (read ProductCode from an MSI)
- Progress & result dashboards with CSV/HTML exports