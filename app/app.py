from app_factory import create_app
from routes import api_bp
from configs import app_config

app = create_app()
app.register_blueprint(api_bp)

def print_startup_info():
    print("🚀 Starting Flask application for exam task...")
    print("📋 Available endpoints:")
    print("  - GET  /ping    - healthcheck")
    print("  - POST /submit  - save name and score")
    print("  - GET  /results - get all records")
    print("  - GET  /health  - detailed health info")
    print("📊 Database: PostgreSQL")
    print("🐳 Ready for Docker deployment")

if __name__ == '__main__':
    print_startup_info()
    
    flask_env = app_config.FLASK_ENV
    flask_debug = app_config.FLASK_DEBUG
    
    print(f"🔧 Environment: {flask_env}")
    print(f"🔧 Debug mode: {flask_debug}")
    
    if flask_env == 'production':
        app.run(host='0.0.0.0', port=5000, debug=False)
    else:
        app.run(host='0.0.0.0', port=5000, debug=flask_debug)
