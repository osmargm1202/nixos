#!/usr/bin/env python3
"""Copy ownership supersedes the former Nix seed-manifest integration."""
import os
from pathlib import Path
import sys

suite = Path(__file__).with_name("dotfiles-copies.py")
os.execv(sys.executable, [sys.executable, str(suite),
    "CopyIntegration.test_all_hosts_copy_dotfiles_without_home_manager_ownership",
    "CopyIntegration.test_rebuild_seed_preserves_changes_and_user_removals",
    "CopyIntegration.test_ryoku_prepares_native_desktop_and_keeps_user_choices"])
