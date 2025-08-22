"""Logging utilities and subprocess wrapper with debug logging."""

import logging
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Union

# ANSI color codes for console output
COLORS = {
    "DEBUG": "\033[36m",  # Cyan
    "INFO": "\033[32m",  # Green
    "WARNING": "\033[33m",  # Yellow
    "ERROR": "\033[31m",  # Red
    "CRITICAL": "\033[35m",  # Magenta
    "RESET": "\033[0m",  # Reset
}


# NOTE: _get_caller_logger was removed as it was brittle and error-prone.
# Always pass logger instances directly to functions that need them.


class ColoredFormatter(logging.Formatter):
    """Custom formatter that adds colors to log levels."""

    def format(self, record):
        if hasattr(record, "levelname"):
            color = COLORS.get(record.levelname, COLORS["RESET"])
            record.levelname = f"{color}{record.levelname}{COLORS['RESET']}"
        return super().format(record)


def configure_logging(
    level: str = "INFO",
    log_file: Union[Path, None] = None,
    console_output: bool = True,
    include_timestamps: bool = True,
) -> None:
    """Configure logging for the application.

    Args:
        level: Logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        log_file: Optional file to write logs to
        console_output: Whether to output logs to console
        include_timestamps: Whether to include timestamps in log format
    """
    # Convert level string to logging constant
    numeric_level = getattr(logging, level.upper(), logging.INFO)

    # Clear any existing handlers
    logging.root.handlers.clear()

    # Create formatters
    if include_timestamps:
        console_format = (
            "%(asctime)s - %(name)s - %(levelname)s - %(filename)s:%(lineno)d - "
            + "%(funcName)s() - %(message)s"
        )
        file_format = (
            "%(asctime)s - %(name)s - %(levelname)s - %(filename)s:%(lineno)d - "
            + "%(funcName)s() - %(message)s"
        )
    else:
        console_format = (
            "%(name)s - %(levelname)s - %(filename)s:%(lineno)d - %(funcName)s() - %(message)s"
        )
        file_format = (
            "%(name)s - %(levelname)s - %(filename)s:%(lineno)d - %(funcName)s() - %(message)s"
        )

    # Configure root logger
    logging.root.setLevel(numeric_level)

    # Console handler
    if console_output:
        console_handler = logging.StreamHandler(sys.stderr)
        console_handler.setLevel(numeric_level)
        console_formatter = ColoredFormatter(console_format)
        console_handler.setFormatter(console_formatter)
        logging.root.addHandler(console_handler)

    # File handler
    if log_file:
        log_file.parent.mkdir(parents=True, exist_ok=True)
        file_handler = logging.FileHandler(log_file)
        file_handler.setLevel(logging.DEBUG)  # Always log debug to file
        file_formatter = logging.Formatter(file_format)
        file_handler.setFormatter(file_formatter)
        logging.root.addHandler(file_handler)

    # Set specific logger levels
    logging.getLogger("ai_how").setLevel(numeric_level)

    # Log the configuration
    logger = logging.getLogger(__name__)
    logger.info(f"Logging configured: level={level}, console={console_output}, file={log_file}")


class SubprocessResult:
    """Result object for subprocess operations."""

    def __init__(
        self, returncode: int, stdout: str, stderr: str, command: list[str], execution_time: float
    ):
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr
        self.command = command
        self.execution_time = execution_time
        self.success = returncode == 0

    def __repr__(self) -> str:
        return (
            f"SubprocessResult(returncode={self.returncode}, "
            f"success={self.success}, execution_time={self.execution_time:.2f}s)"
        )


def _execute_command(
    command_list: list[str],
    cwd: Union[Path, None],
    env: Union[dict[str, str], None],
    input_data: Union[str, None],
    timeout: Union[float, None],
    capture_output: bool,
) -> subprocess.CompletedProcess:
    """Execute a subprocess command."""
    return subprocess.run(
        command_list,
        cwd=cwd,
        env=env,
        input=input_data,
        timeout=timeout,
        check=False,
        capture_output=capture_output,
        text=True,
    )


def _log_subprocess_result(
    logger: logging.Logger, result: SubprocessResult, operation_description: str | None = None
) -> None:
    """Log subprocess execution result with metrics.

    Args:
        logger: Logger instance
        result: Subprocess result object
        operation_description: Optional description of the operation
    """
    operation_name = operation_description or "subprocess"

    # Log execution time as metric
    execution_time_ms = result.execution_time * 1000
    logger.info(
        f"{operation_name} completed in {execution_time_ms:.1f}ms (exit_code={result.returncode})"
    )

    # Log detailed metrics for debugging
    if logger.isEnabledFor(logging.DEBUG):
        logger.debug(
            f"{operation_name} metrics: "
            f"execution_time={result.execution_time:.3f}s, "
            f"stdout_length={len(result.stdout)}, "
            f"stderr_length={len(result.stderr)}"
        )

    # Log output if verbose
    if result.stdout and logger.isEnabledFor(logging.DEBUG):
        logger.debug(f"{operation_name} stdout: {result.stdout.strip()}")
    if result.stderr and logger.isEnabledFor(logging.DEBUG):
        logger.debug(f"{operation_name} stderr: {result.stderr.strip()}")


def _prepare_command(command: str | list[str]) -> list[str]:
    """Prepare command for execution with validation.

    Args:
        command: Command to prepare (string or list of strings)

    Returns:
        List of command arguments

    Raises:
        ValueError: If command contains potentially dangerous characters
    """
    command_list = command.split() if isinstance(command, str) else list(command)

    # Validate command arguments for potential injection
    for arg in command_list:
        if not isinstance(arg, str):
            raise ValueError(f"Command argument must be string, got {type(arg)}")

        # Check for potentially dangerous patterns that could lead to command injection
        # Note: '>' and '<' are valid in many legitimate commands when shell=False
        dangerous_patterns = [";", "&&", "||", "|", "`", "$(", "eval", "exec"]
        for pattern in dangerous_patterns:
            if pattern in arg:
                raise ValueError(
                    f"Potentially dangerous command pattern '{pattern}' detected in argument: {arg}"
                )

    return command_list


def _log_command_start(
    logger: logging.Logger,
    command_list: list[str],
    operation_description: Union[str, None],
    cwd: Union[Path, None],
    env: Union[dict[str, str], None],
    timeout: Union[float, None],
    capture_output: bool,
) -> None:
    """Log the start of command execution."""
    if operation_description:
        logger.debug(f"{operation_description} with command: {' '.join(command_list)}")
    else:
        logger.debug(f"Executing subprocess command: {' '.join(command_list)}")

    if logger.isEnabledFor(logging.DEBUG):
        logger.debug(f"Working directory: {cwd}")
        if env:
            logger.debug(f"Environment variables: {len(env)} additional vars")
        if timeout:
            logger.debug(f"Timeout: {timeout}s")
        logger.debug(f"Capture output: {capture_output}")


def _handle_subprocess_exception(
    logger: logging.Logger,
    command_list: list[str],
    exception: Exception,
    start_time: float,
) -> None:
    """Handle and log subprocess exceptions."""
    execution_time = time.time() - start_time

    if isinstance(exception, subprocess.TimeoutExpired):
        logger.error(f"Command timed out after {execution_time:.2f}s")
        logger.debug(f"Timeout command: {' '.join(command_list)}")
        if exception.stdout:
            logger.debug(f"Partial stdout: {exception.stdout.decode().strip()}")
        if exception.stderr:
            logger.debug(f"Partial stderr: {exception.stderr.decode().strip()}")
    elif isinstance(exception, subprocess.CalledProcessError):
        logger.error(
            f"Command failed after {execution_time:.2f}s with exit code {exception.returncode}"
        )
        logger.debug(f"Failed command: {' '.join(command_list)}")
        if exception.stdout:
            logger.debug(f"Error stdout: {exception.stdout.strip()}")
        if exception.stderr:
            logger.debug(f"Error stderr: {exception.stderr.strip()}")
    else:
        logger.error(f"Unexpected error running command after {execution_time:.2f}s: {exception}")
        logger.debug(f"Error command: {' '.join(command_list)}")


def run_subprocess_with_logging(
    command: Union[str, list[str]],
    logger: logging.Logger,
    cwd: Union[Path, None] = None,
    env: Union[dict[str, str], None] = None,
    input_data: Union[str, None] = None,
    timeout: Union[float, None] = None,
    check: bool = False,
    capture_output: bool = True,
    operation_description: Union[str, None] = None,
) -> SubprocessResult:
    """Run a subprocess command with comprehensive debug logging.

    Args:
        command: Command to run (string or list of strings)
        logger: The logger instance to use for logging.
        cwd: Working directory for the command
        env: Environment variables for the command
        input_data: Input data to send to the command
        timeout: Timeout in seconds
        check: Whether to raise an exception on non-zero exit code
        capture_output: Whether to capture stdout and stderr
        operation_description: Optional description of what this command does

    Returns:
        SubprocessResult object with command results

    Raises:
        subprocess.CalledProcessError: If check=True and command fails
        subprocess.TimeoutExpired: If command times out
    """
    # Prepare command and log start
    command_list = _prepare_command(command)
    _log_command_start(
        logger, command_list, operation_description, cwd, env, timeout, capture_output
    )

    start_time = time.time()

    try:
        # Execute the command
        result = _execute_command(command_list, cwd, env, input_data, timeout, capture_output)
        execution_time = time.time() - start_time

        # Create result object
        subprocess_result = SubprocessResult(
            returncode=result.returncode,
            stdout=result.stdout if capture_output else "",
            stderr=result.stderr if capture_output else "",
            command=command_list,
            execution_time=execution_time,
        )

        # Log the result
        _log_subprocess_result(logger, subprocess_result, operation_description)

        # Check if we should raise an exception for non-zero exit
        if check and not subprocess_result.success:
            raise subprocess.CalledProcessError(
                result.returncode, command_list, output=result.stdout, stderr=result.stderr
            )

        return subprocess_result

    except Exception as e:
        _handle_subprocess_exception(logger, command_list, e, start_time)
        raise


def get_logger_for_module(module_name: str) -> logging.Logger:
    """Get a logger for a specific module with consistent naming.

    Args:
        module_name: Name of the module (typically __name__)

    Returns:
        Configured logger instance
    """
    return logging.getLogger(module_name)


def log_function_entry(logger: logging.Logger, func_name: str, *args: Any, **kwargs: Any) -> None:
    """Log function entry with parameters.

    Args:
        logger: Logger instance
        func_name: Name of the function
        *args: Positional arguments
        **kwargs: Function parameters to log
    """
    if logger.isEnabledFor(logging.DEBUG):
        params = ", ".join([str(arg) for arg in args] + [f"{k}={v}" for k, v in kwargs.items()])
        logger.debug(f"Entering {func_name}({params})")


def log_function_exit(logger: logging.Logger, func_name: str, result: Any = None) -> None:
    """Log function exit with optional result.

    Args:
        logger: Logger instance
        func_name: Name of the function
        result: Function result to log
    """
    if logger.isEnabledFor(logging.DEBUG):
        if result is not None:
            logger.debug(f"Exiting {func_name} with result: {result}")
        else:
            logger.debug(f"Exiting {func_name}")


def log_operation_start(logger: logging.Logger, operation: str, **context: Any) -> None:
    """Log the start of a significant operation.

    Args:
        logger: Logger instance
        operation: Description of the operation
        **context: Additional context information
    """
    context_str = ", ".join(f"{k}={v}" for k, v in context.items()) if context else ""
    logger.info(f"Starting {operation}" + (f" ({context_str})" if context_str else ""))


def log_operation_success(logger: logging.Logger, operation: str, **context: Any) -> None:
    """Log successful completion of an operation.

    Args:
        logger: Logger instance
        operation: Description of the operation
        **context: Additional context information
    """
    context_str = ", ".join(f"{k}={v}" for k, v in context.items()) if context else ""
    logger.info(
        f"Successfully completed {operation}" + (f" ({context_str})" if context_str else "")
    )
