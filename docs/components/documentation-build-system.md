# Documentation Build System

**Status:** Production
**Created:** 2025-10-24
**Last Updated:** 2025-10-24

## Overview

This document provides component-level documentation for the AI-HOW project's documentation build system, including
MkDocs configuration, plugin architecture, build workflow, and maintenance procedures.

The documentation system aggregates content from multiple directories into a unified site using MkDocs with the
Material theme and custom plugins.

## MkDocs Configuration Architecture

### Main Configuration File

The primary configuration is in `mkdocs.yml` at the project root:

```text
mkdocs.yml
├── Site metadata (name, description, author, URL)
├── Repository information (for edit links)
├── Theme configuration (Material for MkDocs)
├── Plugin configuration (5 plugins)
├── Markdown extensions
└── Navigation structure (multi-section nav)
```

### Configuration Sections

#### Site Metadata

```yaml
site_name: "AI-HOW: AI Hyperscaler on Workstation"
site_description: High-performance computing (HPC) hyperscaler infrastructure on workstation hardware
site_author: AI-HOW Team
site_url: https://idoudali.github.io/ai-hyperscaler-on-workskation
repo_name: idoudali/ai-hyperscaler-on-workskation
repo_url: https://github.com/idoudali/ai-hyperscaler-on-workskation
edit_uri: edit/main/docs/
copyright: Copyright &copy; 2024-2025 AI-HOW Team
```

#### Theme Configuration

Material for MkDocs provides modern UI and navigation features:

```yaml
theme:
  name: material
  language: en
  features:
    - content.code.annotate    # Code annotations support
    - content.code.copy        # Copy code button
    - content.tabs.link        # Link between tabs
    - header.autohide          # Hide header on scroll
    - navigation.expand        # Auto-expand nav sections
    - navigation.footer        # Footer with prev/next links
    - navigation.indexes       # Index pages for sections
    - navigation.instant       # Instant loading
    - navigation.sections      # Section-based nav
    - navigation.tabs          # Top-level tabs
    - navigation.tabs.sticky   # Sticky tabs
    - navigation.top           # "Back to top" button
    - navigation.tracking      # Anchor tracking
    - search.highlight         # Search result highlighting
    - search.share             # Share search results
    - search.suggest           # Search suggestions
    - toc.follow               # TOC follows scrolling
    - toc.integrate            # TOC integrated in sidebar
```

Color scheme configuration:

```yaml
palette:
  - scheme: default              # Light mode
    primary: blue grey
    accent: blue
    toggle:
      icon: material/brightness-7
      name: Switch to dark mode
  - scheme: slate                # Dark mode
    primary: blue grey
    accent: blue
    toggle:
      icon: material/brightness-4
      name: Switch to light mode
```

#### Font Configuration

```yaml
font:
  text: Roboto              # Sans-serif for body text
  code: Roboto Mono         # Monospace for code blocks
```

## Plugin Architecture

### 1. Search Plugin

```yaml
plugins:
  - search:
      lang: en
```

**Purpose:** Full-text search across all documentation
**Configuration:** Single language (English)
**Output:** Search index built during documentation build
**Performance:** Generates searchable index for instant search in sidebar

### 2. Simple Plugin (Multi-Directory Aggregation)

```yaml
  - simple:
      merge_docs_dir: true
      build_dir: "temp_docs"
      folders:
        - 'docs/**'
        - 'ansible/**'
        - 'packer/**'
        - 'containers/**'
        - '3rd-party/**'
        - 'scripts/**'
        - 'config/**'
        - 'docker/**'
        - 'tests/**'
        - 'python/ai_how/**'
        - 'README.md'
        - '.cursor/rules/**'
      ignore:
        - '.venv/**'
        - 'build/**'
        - 'site/**'
        - 'temp_docs/**'
        - '**/__pycache__/**'
        - '**/node_modules/**'
        - '.git/**'
        - '**/.pytest_cache/**'
        - '**/venv/**'
        - '**/.nox/**'
        - '**/site-packages/**'
        - '**/dist-info/**'
        - '**/.tox/**'
        - '**/htmlfiles/**'
        - 'AI-AGENT-GUIDE.md'
        - '**/LICENSE'
      include:
        - '*.md'
        - '*.png'
        - '*.jpg'
        - '*.jpeg'
        - '*.svg'
        - '*.gif'
        - '*.bmp'
        - '*.webp'
```

**Purpose:** Aggregate documentation from 11 different directories into single site
**Key Features:**

- Merges docs directory with other folders
- Collects README files from component directories
- Includes rule files from .cursor/rules/
- Generates unified build in temp_docs/

**Folder Structure:**

- `docs/` - Main documentation sections
- `ansible/` - Ansible playbooks and role documentation
- `packer/` - Packer image templates and docs
- `containers/` - Container definitions and docs
- `3rd-party/` - Third-party dependencies documentation
- `scripts/` - Utility scripts documentation
- `config/` - Configuration examples and reference
- `docker/` - Docker development environment docs
- `tests/` - Test framework documentation
- `python/ai_how/` - Python CLI documentation

**Ignore Patterns:** Build artifacts, cache, virtual environments, git history

### 3. Awesome Pages Plugin

```yaml
  - awesome-pages
```

**Purpose:** Advanced navigation and section management
**Configuration:** Uses `.pages` files in directories for custom ordering
**Features:**

- Override default alphabetical sorting
- Customize section hierarchy
- Hide/show pages dynamically
- Define section titles

### 4. Include Markdown Plugin

```yaml
  - include-markdown
```

**Purpose:** Include external markdown files in other documents
**Use Cases:**

- Reuse common content sections
- Include generated documentation
- Share content between files
- Reduce duplication

### 5. HTMLProofer Plugin

```yaml
  - htmlproofer:
      enabled: true
      raise_error: false
      raise_error_excludes:
        404: ['https://.*']
```

**Purpose:** Validate links in generated HTML
**Configuration:**

- Enabled for all builds
- Non-fatal errors (documentation still builds)
- Allows external HTTPS URLs to fail (404 exclusion)
- Checks for broken internal links

## Markdown Extensions

### Content Processing

```yaml
markdown_extensions:
  - abbr                    # Abbreviations
  - admonition              # Admonition boxes (note, warning, etc.)
  - attr_list               # Attribute lists for elements
  - def_list                # Definition lists
  - footnotes               # Footnote references
  - md_in_html              # Markdown inside HTML blocks
  - toc:                    # Table of contents
      permalink: true
      title: On this page
```

### Code and Text Formatting

```yaml
  - pymdownx.arithmatex:
      generic: true         # LaTeX math support
  - pymdownx.betterem:
      smart_enable: all     # Better emphasis
  - pymdownx.caret          # Caret (superscript)
  - pymdownx.details        # Collapsible details
  - pymdownx.emoji:         # Emoji support
      emoji_generator: !!python/name:material.extensions.emoji.to_svg
      emoji_index: !!python/name:material.extensions.emoji.twemoji
  - pymdownx.highlight:
      anchor_linenums: true # Line number anchors in code
  - pymdownx.inlinehilite   # Inline code highlighting
  - pymdownx.keys           # Keyboard key indicators
  - pymdownx.mark           # Text highlighting
  - pymdownx.smartsymbols   # Smart symbols (→, ©, etc.)
  - pymdownx.superfences:   # Advanced code fences
      custom_fences:
        - name: mermaid
          class: mermaid
          format: !!python/name:pymdownx.superfences.fence_code_format
  - pymdownx.tabbed:        # Tabbed content
      alternate_style: true
  - pymdownx.tasklist:      # Task lists (checkboxes)
      custom_checkbox: true
  - pymdownx.tilde          # Strikethrough
```

## Navigation Structure

The navigation in `mkdocs.yml` organizes documentation into logical sections:

```text
nav:
├── Home (index.md)
├── Getting Started
│   ├── Prerequisites
│   ├── Installation
│   ├── 5-Minute Quickstart
│   ├── Cluster Quickstart
│   ├── GPU Quickstart
│   ├── Container Quickstart
│   └── Monitoring Quickstart
├── Tutorials (7 tutorials)
├── Architecture (8 sections)
├── Operations (6 sections)
├── Workflows (5 workflows)
├── Troubleshooting (4 guides)
├── Design Documents (4 documents)
├── Development (5 topics)
├── Components (15+ component docs)
└── Testing (2 sections)
```

### Key Navigation Principles

1. **Top-level sections** group related content
2. **Logical progression** from basics to advanced
3. **Component documentation** lives with code
4. **Workflows** describe end-to-end processes
5. **Operations** guides for production use

## Build Workflow

### Build Process

#### 1. Configuration Loading

```bash
mkdocs build
```

Steps:

1. Read `mkdocs.yml` configuration
2. Load all plugins
3. Initialize theme
4. Parse navigation structure

#### 2. Documentation Collection

Simple plugin aggregates:

1. Scans all configured folders
2. Collects `.md` files and images
3. Applies ignore patterns
4. Builds file tree

#### 3. Processing

1. Parse Markdown with extensions
2. Apply theme styling
3. Run include-markdown replacements
4. Generate navigation HTML
5. Build search index
6. Validate links with HTMLProofer

#### 4. Output Generation

1. Write HTML files to temp_docs/
2. Copy static assets (CSS, JS, images)
3. Generate search index
4. Create sitemap

### Build Commands

#### Build Documentation

```bash
make docs-build
```

Generates static HTML in `temp_docs/` directory

#### Serve Locally

```bash
make docs-serve
```

Starts development server (typically at http://localhost:8000)

#### Build with Verbose Output

```bash
mkdocs build -v
```

Shows detailed build progress and any warnings

### Build Timing

Typical build times on modern hardware:

- **First build:** 2-3 minutes (full processing)
- **Incremental rebuild:** 30-60 seconds (cached)
- **Serve mode:** <5 seconds (watch and rebuild)

## Documentation Standards and Conventions

### File Organization

Component documentation follows DRY principle:

```text
component/
├── README.md              # Main component documentation
├── README_ADDITIONAL.md   # If needed for large components
└── [subcomponents]/
    └── README.md          # Sub-component docs
```

### Markdown Standards

**File Naming:**

- Use lowercase with hyphens: `my-guide.md`
- Descriptive names reflecting content
- No spaces in filenames

**Line Length:**

- Maximum 120 characters per line
- Wrap long lines for readability
- Exception: URLs and code blocks

**Headings:**

- Use ATX-style (`#`, `##`, `###`)
- Start with `#` for page title
- Logical hierarchy (no skipping levels)
- One title per file

**Code Blocks:**

- Always specify language: ` ```bash `, ` ```python `, ` ```text `
- Include language identifier for syntax highlighting
- Use ` ```text ` for generic output/examples

**Lists:**

- Use dashes (`-`) for unordered lists
- Number (1., 2., 3.) for ordered lists
- Start ordered lists at 1
- Consistent indentation

**Links:**

- Use relative paths for internal links
- Use full URLs for external links
- Descriptive link text (not "click here")

### Content Structure

Each component document should include:

1. **Overview** - What is this component?
2. **Architecture/Design** - How does it work?
3. **Configuration** - What can be configured?
4. **Usage Examples** - Practical examples
5. **Troubleshooting** - Common issues and solutions
6. **Related Documentation** - Links to related docs

### Status Markers

Use status in document frontmatter:

```yaml
**Status:** Production
**Created:** 2025-10-24
**Last Updated:** 2025-10-24
```

Valid statuses:

- **Production** - Ready for use, fully documented
- **Stable** - Complete but may have minor updates
- **Beta** - Functional but incomplete documentation
- **Planning** - Not yet implemented

## Adding New Documentation Sections

### 1. Create Documentation File

Create `.md` file in appropriate directory:

```bash
# For component docs (lives with code)
mkdir -p component/docs
echo "# My Component Documentation" > component/docs/my-guide.md

# For main docs
mkdir -p docs/my-section
echo "# My Section" > docs/my-section/my-guide.md
```

### 2. Update mkdocs.yml Navigation

Edit `mkdocs.yml` to add entry to `nav:` section:

```yaml
nav:
  - My Section:
      - My Guide: my-section/my-guide.md
```

### 3. Follow Markdown Standards

- Use lowercase filenames
- Keep line length ≤ 120 characters
- Specify language for code blocks
- Add status markers

### 4. Test Build Locally

```bash
make docs-serve
```

Browse to http://localhost:8000 and verify:

- Navigation appears correctly
- Content renders properly
- Links work
- Code blocks have syntax highlighting

### 5. Check for Build Warnings

```bash
make docs-build 2>&1 | grep -i warning
```

Resolve any warnings before committing

### 6. Validate with Pre-commit

```bash
pre-commit run --files my-file.md
```

Ensure markdownlint passes (120 char limit, language specs, etc.)

## Troubleshooting Build Issues

### Build Fails: "Plugin Not Found"

**Error:** `Error: Failed to load plugin 'simple'`

**Solution:**

```bash
# Install plugin
pip install mkdocs-simple-plugin

# Or install all docs dependencies
pip install -r requirements-dev.txt

# Verify installation
pip list | grep mkdocs
```

### Build Warning: "Link Not Found"

**Error:** `WARNING - htmlproofer: invalid url`

**Causes:**

- Broken internal links
- External URL unreachable
- Missing relative path

**Solutions:**

```bash
# Check link exists
ls -la path/to/file.md

# Fix relative path (use ../ if needed)
# Example: [Link](../other-section/file.md)

# For external URLs, ensure they're valid
curl -I https://example.com
```

### Navigation Not Showing

**Problem:** Section doesn't appear in sidebar

**Solution:**

1. Verify entry in `mkdocs.yml` nav section
2. Check file path is correct and file exists
3. Check file is not in ignore list
4. Run build with verbose output: `mkdocs build -v`

### Search Not Working

**Problem:** Search index empty or incomplete

**Solution:**

```bash
# Force rebuild search index
rm -rf temp_docs/

# Full rebuild
make docs-build

# Check search index was generated
ls -la temp_docs/search/search_index.json
```

### Slow Build Time

**Problem:** `make docs-build` takes >5 minutes

**Causes:**

- Too many documentation files
- Large images not optimized
- Plugin processing slow
- Disk I/O bottleneck

**Solutions:**

```bash
# Clear cache
rm -rf temp_docs/ .cache/

# Rebuild without link checking (faster for development)
# Edit mkdocs.yml: change raise_error: true to false

# Optimize images
# Use png/jpg compression tools for images >1MB

# Check for large files
find docs/ -size +5M -type f
```

## Plugin Configuration Details

### Awesome Pages Configuration

Create `.pages` files in directories to customize order:

```yaml
# In docs/architecture/.pages
nav:
  - Overview: overview.md
  - Build System: build-system.md
  - Network: network.md
  - ... (custom order)
```

### Include Markdown Examples

Include external content:

```markdown
{!reference/common-patterns.md!}
```

Include specific sections:

```markdown
{!reference/file.md!#section-anchor}
```

### HTMLProofer Configuration

Allow specific link failures:

```yaml
htmlproofer:
  raise_error_excludes:
    404: ['https://external-site.com']
```

## CI/CD Integration

### GitHub Actions

Documentation is built in CI/CD pipeline:

```yaml
# In .github/workflows/ci.yml
- name: Build Documentation
  run: make docs-build

- name: Deploy to GitHub Pages
  run: |
    cd temp_docs/
    # GitHub Pages deployment logic
```

### Local Pre-commit Hook

Validate documentation before commit:

```bash
pre-commit run markdownlint
```

Checks:

- Line length (120 char max)
- Code block language specs
- Proper list formatting
- Link syntax

## Theme Customization

### Adding Custom CSS

Create `docs/stylesheets/extra.css`:

```css
/* Custom color scheme */
:root {
  --md-primary-fg-color: #1976d2;
}

/* Custom component styling */
.custom-box {
  padding: 1rem;
  border: 1px solid #ccc;
}
```

Enable in `mkdocs.yml`:

```yaml
extra_css:
  - stylesheets/extra.css
```

### Adding Custom JavaScript

Create `docs/javascripts/extra.js`:

```javascript
// Custom analytics or functionality
document.addEventListener('DOMContentLoaded', function() {
  console.log('Documentation loaded');
});
```

Enable in `mkdocs.yml`:

```yaml
extra_javascript:
  - javascripts/extra.js
```

### Modifying Theme Colors

Edit `mkdocs.yml` palette section:

```yaml
palette:
  - scheme: default
    primary: blue           # Primary color
    accent: red             # Accent color
```

Available colors: red, pink, purple, deep purple, indigo, blue, light blue, cyan,
teal, green, light green, lime, yellow, amber, orange, deep orange, brown, grey,
blue grey.

## Best Practices

1. **Keep documentation close to code** - Component docs live in component directories
2. **Follow naming conventions** - Lowercase filenames with hyphens
3. **Enforce line length** - Pre-commit hooks catch violations
4. **Test locally first** - Always verify with `make docs-serve` before pushing
5. **Link thoughtfully** - Use relative paths for internal links
6. **Update status markers** - Keep Creation/Update dates current
7. **DRY principle** - Use include-markdown to avoid duplication
8. **Review build output** - Check for warnings even if build succeeds
9. **Optimize media** - Keep image files small for faster builds
10. **Version control docs** - Treat documentation as code

## Related Documentation

- **Main Build System:** `docs/architecture/build-system.md`
- **CI/CD Pipeline:** `docs/development/ci-cd-pipeline.md`
- **Code Quality Tools:** `docs/development/code-quality-linters.md`
- **Build Container Rules:** `.ai/rules/build-container.md`
- **MkDocs Documentation:** https://www.mkdocs.org/
- **Material Theme:** https://squidfunk.github.io/mkdocs-material/

## References

- MkDocs Configuration: https://www.mkdocs.org/user-guide/configuration/
- Material Theme Features: https://squidfunk.github.io/mkdocs-material/reference/
- PyMdown Extensions: https://facelessuser.github.io/pymdown-extensions/
- Plugin List: https://www.mkdocs.org/user-guide/plugins/
