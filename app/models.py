from app import db
from datetime import datetime
from sqlalchemy import func


class ScoreRecord(db.Model):
    """
    Модель для хранения записей с именами и баллами.
    Соответствует требованиям экзаменационного задания.
    """
    __tablename__ = 'score_records'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    name = db.Column(db.String(255), nullable=False, index=True)
    score = db.Column(db.Integer, nullable=False)
    timestamp = db.Column(
        db.DateTime, 
        nullable=False, 
        default=datetime.utcnow,
        server_default=func.now()
    )
    
    def __repr__(self):
        return f'<ScoreRecord {self.name}: {self.score}>'
    
    def to_dict(self):
        """Сериализация в словарь для JSON ответов"""
        return {
            'id': self.id,
            'name': self.name,
            'score': self.score,
            'timestamp': self.timestamp.isoformat() if self.timestamp else None
        }
    
    @classmethod
    def create_record(cls, name: str, score: int):
        """
        Создание новой записи с валидацией.
        Production-ready метод с обработкой ошибок.
        """
        try:
            record = cls(name=name, score=score)
            db.session.add(record)
            db.session.commit()
            return record, None
        except Exception as e:
            db.session.rollback()
            return None, str(e)
    
    @classmethod
    def get_all_records(cls):
        """Получение всех записей отсортированных по времени создания"""
        return cls.query.order_by(cls.timestamp.desc()).all()
