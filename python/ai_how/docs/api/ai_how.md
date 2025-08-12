# AI-HOW API Reference

This page provides the complete API reference for the AI-HOW package.

## Modules

::: ai_how.cli
    handler: python
    selection:
      members:
        - app
        - validate_command
        - main

::: ai_how.validation
    handler: python
    selection:
      members:
        - validate_config
        - load_schema
        - validate_yaml

::: ai_how.schemas
    handler: python
    selection:
      members:
        - get_schema_path
        - load_schema_file
