from typing import Tuple, Optional, Dict, Any

def validate_submit_data(data: Dict[str, Any]) -> Tuple[bool, Optional[str], Optional[Dict[str, Any]]]:
    """
    Валидация данных для POST /submit эндпоинта.
    
    Returns:
        Tuple[bool, Optional[str], Optional[Dict]]: 
        (is_valid, error_message, cleaned_data)
    """
    if not data:
        return False, "Request body is empty", None

    if 'name' not in data or 'score' not in data:
        return False, "Missing required fields: name, score", None
    
    name = data.get('name')
    score = data.get('score')

    if not isinstance(name, str) or not name.strip():
        return False, "Name must be a non-empty string", None
    
    if len(name.strip()) > 255:
        return False, "Name too long (max 255 characters)", None

    if not isinstance(score, int):
        return False, "Score must be an integer", None
    
    if score < 0 or score > 100:
        return False, "Score must be between 0 and 100", None

    cleaned_data = {
        'name': name.strip(),
        'score': score
    }
    
    return True, None, cleaned_data

def validate_content_type(request) -> Tuple[bool, Optional[str]]:
    """
    Проверка Content-Type для JSON запросов.
    
    Returns:
        Tuple[bool, Optional[str]]: (is_valid, error_message)
    """
    if not request.is_json:
        return False, "Content-Type must be application/json"
    
    return True, None
