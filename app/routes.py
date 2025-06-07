from flask import Blueprint, request, jsonify, current_app
from app.models import ScoreRecord
from app import db
from pydantic import BaseModel, ValidationError
from typing import Dict, Any

api_bp = Blueprint('api', __name__)

class SubmitRequest(BaseModel):
    """Pydantic модель для валидации POST /submit запросов"""
    name: str
    score: int
    
    class Config:
        str_strip_whitespace = True
        validate_assignment = True


@api_bp.route('/ping', methods=['GET'])
def ping():
    """
    Healthcheck эндпоинт для мониторинга.
    Проверяет доступность приложения и базы данных.
    """
    try:
        db.session.execute('SELECT 1')
        return jsonify({"status": "ok", "database": "connected"}), 200
    except Exception as e:
        current_app.logger.error(f"Database health check failed: {e}")
        return jsonify({
            "status": "error", 
            "database": "disconnected",
            "error": str(e)
        }), 503


@api_bp.route('/submit', methods=['POST'])
def submit():
    """
    POST /submit - сохранение данных в базу.
    Принимает JSON: {"name": "Kirill", "score": 88}
    """
    try:
        if not request.is_json:
            return jsonify({"error": "Content-Type must be application/json"}), 400
        
        submit_data = SubmitRequest(**request.get_json())
        
        if submit_data.score < 0 or submit_data.score > 100:
            return jsonify({"error": "Score must be between 0 and 100"}), 400
        
        if len(submit_data.name) < 1 or len(submit_data.name) > 255:
            return jsonify({"error": "Name must be between 1 and 255 characters"}), 400
        
        record, error = ScoreRecord.create_record(
            name=submit_data.name, 
            score=submit_data.score
        )
        
        if error:
            current_app.logger.error(f"Failed to create record: {error}")
            return jsonify({"error": "Failed to save record"}), 500
        
        current_app.logger.info(f"Created record: {record}")
        return jsonify({
            "message": "Record created successfully",
            "data": record.to_dict()
        }), 201
        
    except ValidationError as e:
        return jsonify({"error": "Invalid input data", "details": e.errors()}), 400
    except Exception as e:
        current_app.logger.error(f"Unexpected error in /submit: {e}")
        return jsonify({"error": "Internal server error"}), 500


@api_bp.route('/results', methods=['GET'])
def results():
    """
    GET /results - получение всех записей из базы.
    Возвращает JSON массив с записями.
    """
    try:
        records = ScoreRecord.get_all_records()
        return jsonify([record.to_dict() for record in records]), 200
    except Exception as e:
        current_app.logger.error(f"Failed to fetch results: {e}")
        return jsonify({"error": "Failed to fetch records"}), 500


@api_bp.errorhandler(404)
def not_found(error):
    """Обработчик 404 ошибок"""
    return jsonify({"error": "Endpoint not found"}), 404


@api_bp.errorhandler(405)
def method_not_allowed(error):
    """Обработчик 405 ошибок"""
    return jsonify({"error": "Method not allowed"}), 405


@api_bp.errorhandler(500)
def internal_error(error):
    """Обработчик 500 ошибок"""
    db.session.rollback()
    return jsonify({"error": "Internal server error"}), 500
