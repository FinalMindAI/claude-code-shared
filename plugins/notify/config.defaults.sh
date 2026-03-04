#!/bin/bash
# Default configuration for the notify plugin.
# To override, create ~/.claude/notify-config.sh with your values.

# macOS sound name (see /System/Library/Sounds/)
NOTIFY_SOUND="${NOTIFY_SOUND:-Glass}"

# Enable Haiku topic summarization (true/false)
NOTIFY_TOPIC_ENABLED="${NOTIFY_TOPIC_ENABLED:-true}"

# Model for topic summarization
NOTIFY_TOPIC_MODEL="${NOTIFY_TOPIC_MODEL:-haiku}"

# Notification group ID (controls grouping/replacement in Notification Center)
NOTIFY_GROUP="${NOTIFY_GROUP:-claude-code}"

# Terminal app bundle ID to activate on click (auto-detected if empty)
NOTIFY_TERMINAL_APP="${NOTIFY_TERMINAL_APP:-}"
