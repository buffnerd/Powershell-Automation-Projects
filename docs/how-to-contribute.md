# Contributing to PowerShell Automation Portfolio

Thank you for your interest in contributing to this PowerShell automation portfolio! This document provides guidelines for contributing code, documentation, and improvements.

## 🤝 How to Contribute

### 1. Fork the Repository
- Fork this repository to your GitHub account
- Clone your fork locally
- Create a new branch for your contribution

### 2. Development Guidelines

#### Code Standards
- Follow PowerShell best practices and approved verbs
- Use PascalCase for function names and camelCase for variables
- Include comprehensive comment-based help for all functions
- Implement proper error handling with try-catch blocks
- Add logging for debugging and audit purposes

#### Example Function Template
```powershell
<#
.SYNOPSIS
    Brief description of the function
.DESCRIPTION
    Detailed description of what the function does
.PARAMETER ParameterName
    Description of the parameter
.EXAMPLE
    Example of how to use the function
.NOTES
    Additional notes about the function
#>
function Verb-Noun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ParameterName
    )
    
    try {
        # Function logic here
        Write-Verbose "Processing $ParameterName"
    }
    catch {
        Write-Error "Error in Verb-Noun: $($_.Exception.Message)"
        throw
    }
}
```

#### Testing Requirements
- Test all scripts in isolated environments before submission
- Include unit tests where applicable
- Document test scenarios and expected outcomes
- Validate scripts with PSScriptAnalyzer

### 3. Documentation Standards

#### README Files
Each project folder should include:
- **README.md**: Project overview, installation, and usage instructions
- **CHANGELOG.md**: Version history and changes
- **EXAMPLES.md**: Practical usage examples

#### Code Documentation
- Comment complex logic and business rules
- Include parameter validation explanations
- Document any external dependencies
- Explain security considerations

### 4. Security Guidelines

#### Credential Management
- Never hardcode credentials or sensitive information
- Use Windows Credential Manager or Azure Key Vault
- Implement secure string handling for passwords
- Document credential requirements clearly

#### Error Handling
- Implement comprehensive error handling
- Log security-relevant events
- Avoid exposing sensitive information in error messages
- Include proper cleanup in finally blocks

### 5. Submission Process

#### Pull Request Requirements
1. **Descriptive Title**: Clearly describe what the PR accomplishes
2. **Detailed Description**: Explain the changes and reasoning
3. **Testing Evidence**: Include test results and validation steps
4. **Documentation Updates**: Update relevant documentation
5. **Breaking Changes**: Clearly mark any breaking changes

#### Review Process
- All PRs require review before merging
- Address reviewer feedback promptly
- Ensure CI/CD checks pass
- Maintain backward compatibility when possible

### 6. Project Structure

#### New Projects
When adding a new project:
```
Project-Name/
├─ README.md              # Project overview and usage
├─ src/                   # Main PowerShell scripts
├─ tests/                 # Unit and integration tests
├─ docs/                  # Additional documentation
├─ examples/              # Usage examples
└─ CHANGELOG.md           # Version history
```

#### File Naming Conventions
- Use descriptive, kebab-case names for files
- PowerShell scripts: `verb-noun.ps1`
- Modules: `ModuleName.psm1`
- Tests: `verb-noun.tests.ps1`

### 7. Code Review Checklist

Before submitting, ensure:
- [ ] Code follows PowerShell best practices
- [ ] All functions have comment-based help
- [ ] Error handling is comprehensive
- [ ] Security considerations are addressed
- [ ] Documentation is updated
- [ ] Tests are included and passing
- [ ] No hardcoded credentials or sensitive data
- [ ] PSScriptAnalyzer warnings are resolved

### 8. Getting Help

If you need help with your contribution:
- Create an issue with the `question` label
- Reach out to maintainers for guidance
- Check existing issues for similar questions
- Review the project documentation

## 📧 Contact

For questions about contributing, please open an issue or contact the maintainers.

Thank you for helping improve this PowerShell automation portfolio!