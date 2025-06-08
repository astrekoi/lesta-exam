from flask import Flask
from flask_migrate import Migrate
from models.score_recorder import db, ScoreRecord
from configs import app_config

class App(Flask):
    pass

def create_flask_app_with_configs() -> App:
    app = App(__name__)
    
    app.config.update(app_config.model_dump())
    app.config['SQLALCHEMY_DATABASE_URI'] = app_config.database_url
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    app.config['SQLALCHEMY_ENGINE_OPTIONS'] = {
        'pool_pre_ping': True,
        'pool_recycle': 300,
        'connect_args': {
            'connect_timeout': 10,
        }
    }
    
    db.init_app(app)
    migrate = Migrate(app, db)
    
    with app.app_context():
        try:
            from models.score_recorder import ScoreRecord
            
            db.create_all()
            
            with db.engine.connect() as conn:
                conn.execute(db.text('SELECT 1'))
            
            print("Successfully connected to PostgreSQL")
            print("Database tables created successfully")
            
        except Exception as e:
            raise RuntimeError(f"Failed to connect to PostgreSQL: {str(e)}") from e
    
    return app

def create_app() -> App:
    app = create_flask_app_with_configs()
    return app
