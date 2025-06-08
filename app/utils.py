from typing import Dict, Any
from flask import jsonify
import logging

def create_error_response(message: str, details: str = None, status_code: int = 500) -> tuple:
    """
    Создание стандартизированного ответа об ошибке.
    
    Args:
        message: Основное сообщение об ошибке
        details: Дополнительные детали ошибки
        status_code: HTTP код ответа
    
    Returns:
        Tuple[Response, int]: Flask response и status code
    """
    response_data = {"error": message}
    
    if details:
        response_data["details"] = details
    
    if status_code >= 500:
        logging.error(f"Server error: {message}. Details: {details}")
    
    return jsonify(response_data), status_code

def create_success_response(data: Any, message: str = None, status_code: int = 200) -> tuple:
    """
    Создание стандартизированного успешного ответа.
    
    Args:
        data: Данные для ответа
        message: Сообщение о успехе
        status_code: HTTP код ответа
    
    Returns:
        Tuple[Response, int]: Flask response и status code
    """
    if message:
        response_data = {
            "message": message,
            "data": data
        }
    else:
        response_data = data
    
    return jsonify(response_data), status_code
