import logging
import sys
from django.conf import settings

# Get the logger instance
logger = logging.getLogger("my_app_logger")

def get_logger():
    """
    Get the configured logger instance.
    Use this function to get the logger in other parts of your app.
    """
    return logger

def log_info(message, *args, **kwargs):
    """Log an info message"""
    logger.info(message, *args, **kwargs)

def log_error(message, *args, **kwargs):
    """Log an error message"""
    logger.error(message, *args, **kwargs)

def log_warning(message, *args, **kwargs):
    """Log a warning message"""
    logger.warning(message, *args, **kwargs)

def log_debug(message, *args, **kwargs):
    """Log a debug message"""
    logger.debug(message, *args, **kwargs)

def log_critical(message, *args, **kwargs):
    """Log a critical message"""
    logger.critical(message, *args, **kwargs)

# Convenience functions for common logging patterns
def log_request(request, view_name):
    """Log incoming request information"""
    logger.info(f"Request to {view_name} - Method: {request.method}, User: {request.user}, Path: {request.path}")

def log_api_call(endpoint, method, status_code, response_time=None):
    """Log API call information"""
    if response_time:
        logger.info(f"API {method} {endpoint} - Status: {status_code}, Time: {response_time}ms")
    else:
        logger.info(f"API {method} {endpoint} - Status: {status_code}")

def log_user_action(user, action, details=None):
    """Log user actions"""
    if details:
        logger.info(f"User {user} performed action: {action} - Details: {details}")
    else:
        logger.info(f"User {user} performed action: {action}")

def log_database_operation(operation, model, record_id=None):
    """Log database operations"""
    if record_id:
        logger.debug(f"Database {operation} on {model} with ID: {record_id}")
    else:
        logger.debug(f"Database {operation} on {model}")
