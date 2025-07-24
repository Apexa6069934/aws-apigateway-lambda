import json
import pytest
from unittest.mock import Mock
import sys
import os

# Add the lambda directory to the Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'lambda'))

from hello import handler


def test_handler_returns_success():
    """Test that the Lambda handler returns a successful response"""
    # Mock event and context
    event = {
        "httpMethod": "GET",
        "path": "/",
        "headers": {},
        "queryStringParameters": None,
        "body": None
    }
    context = Mock()
    context.function_name = "test-function"
    context.function_version = "$LATEST"
    
    # Call the handler
    response = handler(event, context)
    
    # Assertions
    assert response['statusCode'] == 200
    assert 'headers' in response
    assert response['headers']['Content-Type'] == 'text/plain'
    assert 'body' in response
    assert 'successfully deployed' in response['body']


def test_handler_with_different_event():
    """Test handler with a different event structure"""
    event = {
        "httpMethod": "POST",
        "path": "/test",
        "headers": {"User-Agent": "test-agent"},
        "body": json.dumps({"test": "data"})
    }
    context = Mock()
    
    response = handler(event, context)
    
    assert response['statusCode'] == 200
    assert isinstance(response['body'], str)


def test_handler_event_logging():
    """Test that the handler properly handles event logging"""
    event = {"test": "event"}
    context = Mock()
    
    # Should not raise any exceptions
    response = handler(event, context)
    assert response is not None
    assert 'statusCode' in response