from flask import Blueprint, jsonify, request
from models.score_recorder import ScoreRecord, db
from validators import validate_submit_data, validate_content_type

api_bp = Blueprint('api', __name__)

@api_bp.route('/ping', methods=['GET'])
def ping():
    """
    GET /ping - healthcheck эндпоинт согласно заданию.
    Возвращает статус-сообщение {"status": "ok"}.
    """
    try:
        with db.engine.connect() as conn:
            conn.execute(db.text('SELECT 1'))
        return jsonify({"status": "ok"})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 503

@api_bp.route('/submit', methods=['POST'])
def submit():
    """
    POST /submit - эндпоинт для сохранения данных согласно заданию.
    Принимает JSON: {"name": "Kirill", "score": 88}
    Сохраняет данные в базу данных PostgreSQL.
    """
    try:
        is_valid_content, content_error = validate_content_type(request)
        if not is_valid_content:
            return jsonify({"error": content_error}), 400
        
        data = request.get_json()
        is_valid, error_msg, cleaned_data = validate_submit_data(data)
        
        if not is_valid:
            return jsonify({"error": error_msg}), 400
        
        record, db_error = ScoreRecord.create_record(
            name=cleaned_data['name'], 
            score=cleaned_data['score']
        )
        
        if db_error:
            return jsonify({
                "error": "Failed to save record", 
                "details": db_error
            }), 500
        
        return jsonify({
            "message": "Record created successfully",
            "data": record.to_dict()
        }), 201
        
    except Exception as e:
        return jsonify({
            "error": "Internal server error", 
            "details": str(e)
        }), 500

@api_bp.route('/results', methods=['GET'])
def results():
    """
    GET /results - эндпоинт для получения всех записей согласно заданию.
    Возвращает все записи из базы данных в формате JSON.
    """
    try:
        records = ScoreRecord.get_all_records()
        return jsonify([record.to_dict() for record in records]), 200
        
    except Exception as e:
        return jsonify({
            "error": "Failed to fetch records", 
            "details": str(e)
        }), 500

@api_bp.route('/health', methods=['GET'])
def health():
    """Расширенный healthcheck с информацией о БД"""
    try:
        with db.engine.connect() as conn:
            conn.execute(db.text('SELECT 1'))
        
        total_records = ScoreRecord.query.count()
        
        return jsonify({
            "status": "ok",
            "database": "connected",
            "total_records": total_records
        }), 200
    except Exception as e:
        return jsonify({
            "status": "error",
            "database": "disconnected",
            "error": str(e)
        }), 503

@api_bp.errorhandler(404)
def not_found(error):
    return jsonify({"error": "Endpoint not found"}), 404

@api_bp.errorhandler(405)
def method_not_allowed(error):
    return jsonify({"error": "Method not allowed"}), 405

@api_bp.errorhandler(500)
def internal_error(error):
    db.session.rollback()
    return jsonify({"error": "Internal server error"}), 500
