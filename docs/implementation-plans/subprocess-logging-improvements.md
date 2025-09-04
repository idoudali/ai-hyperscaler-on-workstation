# Subprocess Logging Improvements

## Overview

Enhanced the `run_subprocess_with_logging` function to consolidate logging and
reduce redundant log statements throughout the codebase.

**Implementation Status**: ✅ **VERIFIED** - The current codebase includes the
enhanced `run_subprocess_with_logging` function in `utils/logging.py` with the
`operation_description` parameter as described.

## Changes Made

### 1. **Enhanced `run_subprocess_with_logging` Function**

Added new parameter `operation_description` to provide context-aware logging:

```python
def run_subprocess_with_logging(
    command: Union[str, List[str]],
    cwd: Optional[Path] = None,
    env: Optional[Dict[str, str]] = None,
    input_data: Optional[str] = None,
    timeout: Optional[float] = None,
    check: bool = False,
    capture_output: bool = True,
    logger_name: Optional[str] = None,
    operation_description: Optional[str] = None  # NEW PARAMETER
) -> SubprocessResult:
```

### 2. **Improved Logging Messages**

#### Before:

```python
logger.debug(f"Creating COW disk with command: {' '.join(cmd)}")
result = run_subprocess_with_logging(cmd, check=True, logger_name=__name__)
if result.success:
    logger.debug(f"qemu-img create completed successfully in {result.execution_time:.2f}s")
```

#### After:

```python
result = run_subprocess_with_logging(
    cmd,
    check=True,
    logger_name=__name__,
    operation_description="Creating COW disk"
)
```

### 3. **Consolidated Debug Output**

The function now provides more meaningful and consolidated debug output:

```text
DEBUG - Creating COW disk with command: qemu-img create -f qcow2 -b 
/path/to/base.qcow2 -F qcow2 /path/to/new.qcow2
DEBUG - Creating COW disk completed successfully in 0.23s
```

Instead of the previous scattered logging:

```text
DEBUG - Creating COW disk with command: qemu-img create -f qcow2 -b 
/path/to/base.qcow2 -F qcow2 /path/to/new.qcow2
DEBUG - Executing subprocess command: qemu-img create -f qcow2 -b 
/path/to/base.qcow2 -F qcow2 /path/to/new.qcow2
DEBUG - Working directory: None
DEBUG - Command completed in 0.23s with exit code 0
DEBUG - qemu-img create completed successfully in 0.23s
```

## Updated Functions

### **Disk Manager (`disk_manager.py`)**

#### 1. **`create_disk_from_base()`**

- **Before**: 3 separate debug statements
- **After**: 1 operation-specific log message
- **Operation**: `"Creating COW disk"`

#### 2. **`resize_disk()`**

- **Before**: 3 separate debug statements  
- **After**: 1 operation-specific log message
- **Operation**: `f"Resizing disk to {new_size_gb}GB"`

#### 3. **`get_disk_info()`**

- **Before**: 3 separate debug statements
- **After**: 1 operation-specific log message
- **Operation**: `"Getting disk information"`

## Benefits

### 1. **Reduced Log Noise**

- Eliminated redundant debug statements before subprocess calls
- Consolidated execution context into meaningful descriptions

### 2. **Improved Readability**

- Operation-specific descriptions instead of raw commands
- Clear context about what each subprocess call accomplishes

### 3. **Better Performance**

- Reduced number of logger calls
- Conditional debug context logging (only when DEBUG level enabled)

### 4. **Consistency**

- Standardized logging pattern across all subprocess calls
- Unified approach to operation descriptions

## Usage Guidelines

### **When calling `run_subprocess_with_logging`:**

1. **Always provide `operation_description`** for better log readability:

   ```python
   result = run_subprocess_with_logging(
       cmd,
       operation_description="Creating VM disk image"
   )
   ```

2. **Use descriptive, action-oriented descriptions**:
   - ✅ Good: `"Creating COW disk"`, `"Resizing disk to 100GB"`,
     `"Getting disk information"`
   - ❌ Poor: `"Running qemu-img"`, `"Executing command"`, `"Processing"`

3. **Don't add redundant logger calls before the function**:

   ```python
   # ❌ AVOID THIS:
   logger.debug(f"Running command: {' '.join(cmd)}")
   result = run_subprocess_with_logging(cmd)
   
   # ✅ DO THIS:
   result = run_subprocess_with_logging(cmd, operation_description="Creating disk")
   ```

4. **Keep post-execution logging for additional context**:

   ```python
   result = run_subprocess_with_logging(cmd, operation_description="Creating disk")
   if result.success:
       log_operation_success(logger, "disk creation", disk_path=disk_path)
   ```

## Future Enhancements

1. **Operation Categories**: Add operation type parameter for filtering logs
2. **Progress Callbacks**: Add callback support for long-running operations
3. **Metrics Collection**: Automatic collection of execution statistics
4. **Command Sanitization**: Better handling of sensitive command arguments

## Migration Guide

To update existing code that uses `run_subprocess_with_logging`:

1. **Remove pre-execution debug logging**:

   ```diff
   - logger.debug(f"Running command: {' '.join(cmd)}")
     result = run_subprocess_with_logging(cmd)
   ```

2. **Add operation description**:

   ```diff
     result = run_subprocess_with_logging(
         cmd,
   +     operation_description="Creating disk image"
     )
   ```

3. **Remove redundant post-execution logging**:

   ```diff
     result = run_subprocess_with_logging(cmd, operation_description="Creating disk")
   - if result.success:
   -     logger.debug(f"Command completed successfully in {result.execution_time:.2f}s")
   ```

4. **Keep meaningful post-execution logging**:

   ```diff
     result = run_subprocess_with_logging(cmd, operation_description="Creating disk")
     if result.success:
   +     log_operation_success(logger, "disk creation", disk_path=disk_path)
   ```

This enhancement provides cleaner, more focused logging while maintaining all the
debugging capabilities needed for troubleshooting and monitoring subprocess
operations.
