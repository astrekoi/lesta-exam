from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from app.config import settings

db = SQLAlchemy()
migrate = Migrate()

def create_app():
    """
    Application Factory для экзаменационного задания.
    """
    app = Flask(__name__)
    
    app.config['SQLALCHEMY_DATABASE_URI'] = settings.database_url
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    app.config['SQLALCHEMY_ENGINE_OPTIONS'] = {
        'pool_pre_ping': True,
        'pool_recycle': 300,
    }
    
    db.init_app(app)
    migrate.init_app(app, db)
    
    from app.routes import api_bp
    app.register_blueprint(api_bp)
    
    with app.app_context():
        from app.models import ScoreRecord
        
        try:
            with db.engine.connect() as conn:
                conn.execute(db.text('SELECT 1'))
            print("✅ Database connected successfully")
        except Exception as e:
            print(f"❌ Database connection failed: {e}")
    
    return app
