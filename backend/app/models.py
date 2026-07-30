import enum

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    String,
    func,
)
from sqlalchemy.orm import relationship

from .db import Base


class AutonomyLevel(str, enum.Enum):
    L0 = "L0"
    L1 = "L1"
    L2 = "L2"


class SenderMode(str, enum.Enum):
    HUMAN = "human"
    TWIN = "twin"


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True)
    invite_code = Column(String, unique=True, nullable=False, index=True)
    display_name = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    twin_settings = relationship("TwinSettings", back_populates="user", uselist=False)


class Contact(Base):
    """A relationship between the owner and a counterpart -- carries
    per-peer state like the veto flag (tech-design.md §4:
    twin_disabled_by_peer), independent of any one conversation."""

    __tablename__ = "contacts"

    id = Column(Integer, primary_key=True)
    owner_user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    contact_user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    display_name = Column(String, nullable=False)
    relationship_note = Column(String, nullable=True)
    twin_disabled_by_peer = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class Conversation(Base):
    __tablename__ = "conversations"

    id = Column(Integer, primary_key=True)
    is_group = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    participants = relationship("ConversationParticipant", back_populates="conversation")
    messages = relationship("Message", back_populates="conversation")


class ConversationParticipant(Base):
    __tablename__ = "conversation_participants"

    id = Column(Integer, primary_key=True)
    conversation_id = Column(Integer, ForeignKey("conversations.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    conversation = relationship("Conversation", back_populates="participants")


class Message(Base):
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True)
    conversation_id = Column(Integer, ForeignKey("conversations.id"), nullable=False)
    sender_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    sender_mode = Column(Enum(SenderMode), nullable=False, default=SenderMode.HUMAN)
    text = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    conversation = relationship("Conversation", back_populates="messages")


class TwinSettings(Base):
    __tablename__ = "twin_settings"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), unique=True, nullable=False)
    autonomy_level = Column(Enum(AutonomyLevel), nullable=False, default=AutonomyLevel.L0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="twin_settings")


class WhitelistRule(Base):
    """L2 auto-send whitelist -- a (contact, topic) pair the owner has
    approved for unattended replies. contact_id null = applies to any
    counterpart (PRD.md §3.1)."""

    __tablename__ = "whitelist_rules"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    contact_id = Column(Integer, ForeignKey("contacts.id"), nullable=True)
    topic_keyword = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class EscalationLog(Base):
    """One row per escalation_filter.py trigger -- the post-hoc notification
    + undo trail required by AGENTS.md's absolute safety invariants."""

    __tablename__ = "escalation_logs"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    conversation_id = Column(Integer, ForeignKey("conversations.id"), nullable=False)
    reason = Column(String, nullable=False)
    message_snippet = Column(String, nullable=False)
    resolved = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
