---
alwaysApply: true
---
# Documentation DRY Principle

## Critical Rule

**Don't Repeat Yourself in documentation. Reference, don't duplicate.**

## Guidelines

1. **Reference existing docs** - Link to authoritative sources instead of copying
2. **Single source of truth** - Each piece of information lives in ONE place
3. **Use links liberally** - Point to other docs, READMEs, design documents
4. **Update in one place** - If information changes, only one file needs updating

## When Writing Documentation

- ✅ "See `ansible/README.md` for deployment details"
- ✅ "Refer to design document at `docs/design-docs/slurm-config.md`"
- ✅ "Configuration options documented in `config/README.md`"
- ❌ Copying entire sections from other documents
- ❌ Duplicating command examples across multiple files
- ❌ Repeating configuration details already documented elsewhere

## CLI Documentation

**Never replicate CLI help messages or detailed command examples.**

CLI interfaces change. Documentation that duplicates CLI usage becomes outdated.

### Do This Instead

- ✅ Describe what the tool does (core functionality)
- ✅ Direct users to `--help`: "Run `<tool> --help` for detailed usage"
- ✅ Link to design docs for concepts
- ❌ Don't copy CLI help output or document every option

### Exception: Step-by-Step Tutorials

Detailed command examples are allowed in explicit tutorials (e.g., `docs/tutorials/`) teaching specific workflows.
Even then, prefer minimal working examples over exhaustive flag documentation.

## Exceptions

Brief context or critical safety information may be repeated if necessary for clarity.

## Summary

- Always reference existing documentation rather than duplicating content
- Point users to CLI `--help` flags rather than replicating command usage
- Reserve detailed examples for explicit step-by-step tutorials only
