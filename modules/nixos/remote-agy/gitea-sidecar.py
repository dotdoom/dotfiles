#!/usr/bin/env python3
"""Antigravity Gitea sidecar.

Polls Gitea notifications and issue/PR search endpoints, dispatches @mentions,
assignments, review requests, and replies through Antigravity's `agentapi`,
and routes pull-request follow-ups back to the matching conversation.
"""

from __future__ import annotations

import argparse
from concurrent.futures import Future, ThreadPoolExecutor
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
import http.client
import json
import logging
import os
from pathlib import Path
import re
import signal
import socket
import sqlite3
import subprocess
import sys
import threading
import time
from typing import Any
from urllib.parse import unquote, urlencode, urljoin, urlparse

LOG = logging.getLogger("remote-agy-gitea-sidecar")

MAX_TRANSCRIPT_BYTES = 2 * 1024 * 1024
MAX_DESCRIPTION_CHARS = 2000
MAX_BACKOFF_SECONDS = 300
AGENTAPI_TIMEOUT_SECONDS = 120


@dataclass(frozen=True)
class Config:
    """Runtime configuration loaded from environment variables."""

    gitea_url: str
    token_file: Path
    poll_interval: int
    max_concurrency: int
    model: str | None
    app_data_dir: Path
    gemini_config_dir: Path
    repos_dir: Path
    state_file: Path
    agentapi_bin: str = "agentapi"
    allowed_users: frozenset[str] = frozenset()
    dry_run: bool = False

    @classmethod
    def from_env(cls, *, dry_run: bool = False) -> Config:
        home = Path.home()
        gitea_url = os.environ.get("GITEA_SERVER_URL", "").strip().rstrip("/")
        if not gitea_url:
            raise ValueError("GITEA_SERVER_URL environment variable must be set")
        app_data_dir = home / ".gemini" / "antigravity"
        data_dir = Path(
            os.environ.get("ANTIGRAVITY_EXECUTABLE_DATA_DIR")
            or (app_data_dir / "sidecar_data" / "gitea" / "data")
        )
        return cls(
            gitea_url=gitea_url,
            token_file=Path(
                os.environ.get("GITEA_TOKEN_FILE") or (home / ".config" / "gitea-token")
            ),
            poll_interval=max(1, int(os.environ.get("GITEA_POLL_INTERVAL", "30"))),
            max_concurrency=max(1, int(os.environ.get("GITEA_MAX_CONCURRENCY", "2"))),
            model=os.environ.get("AGY_MODEL", "").strip() or None,
            app_data_dir=app_data_dir,
            gemini_config_dir=home / ".gemini" / "config",
            repos_dir=home / "src",
            state_file=data_dir / "state.json",
            allowed_users=frozenset(
                u.strip().lower()
                for u in os.environ.get("GITEA_ALLOWED_USERS", "").split(",")
                if u.strip()
            ),
            dry_run=dry_run,
        )


def normalize_repo_slug(url: str) -> str:
    """Extract lowercase 'owner/repo' from an HTTPS, SSH, or SCP-style Git URL."""
    raw = url.strip()
    if not raw:
        return ""
    if "://" in raw:
        path = urlparse(raw).path
    elif ":" in raw and not raw.startswith("/"):
        # SCP-style git@host:owner/repo.git
        path = raw.split(":", 1)[1]
    else:
        path = raw
    parts = [p for p in path.strip("/").removesuffix(".git").split("/") if p]
    if len(parts) < 2:
        return ""
    return f"{parts[-2]}/{parts[-1]}".lower()


def mentions_user(text: str | None, username: str) -> bool:
    """Return True if text contains a standalone @username mention."""
    if not text or not username:
        return False
    pattern = rf"(?<![A-Za-z0-9._-])@{re.escape(username)}(?![A-Za-z0-9_-])"
    return bool(re.search(pattern, text, re.IGNORECASE))


def extract_index_from_url(url: str) -> int | None:
    """Extract trailing numeric issue/PR index from a Gitea API or HTML URL."""
    if not url:
        return None
    parts = [p for p in urlparse(url).path.strip("/").split("/") if p]
    if parts and parts[-1].isdigit():
        return int(parts[-1])
    return None


def file_uri_to_path(uri: str) -> Path | None:
    """Convert a file:// URI to a local Path, or return None for other schemes."""
    parsed = urlparse(uri)
    if parsed.scheme != "file":
        return None
    return Path(unquote(parsed.path))


def _fast_create_connection(
    address: tuple[str, int],
    timeout: float,
    source_address: tuple[str, int] | None = None,
    preferred_family: list[socket.AddressFamily | None] | None = None,
) -> socket.socket:
    """Connect quickly across dual-stack hosts without stalling on blackholed IPv6."""
    host, port = address
    infos = socket.getaddrinfo(host, port, 0, socket.SOCK_STREAM)
    if not infos:
        raise OSError(f"getaddrinfo returned empty list for {host}:{port}")

    pref = preferred_family[0] if preferred_family else None
    if pref is not None:
        infos.sort(key=lambda info: 0 if info[0] == pref else 1)

    passes = (
        [min(timeout, 0.5), timeout] if len(infos) > 1 and pref is None else [timeout]
    )
    last_err: OSError | None = None
    for connect_timeout in passes:
        for af, socktype, proto, _, sa in infos:
            sock: socket.socket | None = None
            try:
                sock = socket.socket(af, socktype, proto)
                sock.settimeout(connect_timeout)
                if source_address:
                    sock.bind(source_address)
                sock.connect(sa)
                sock.settimeout(timeout)
                if preferred_family is not None:
                    preferred_family[0] = af
                return sock
            except OSError as err:
                last_err = err
                if sock is not None:
                    sock.close()
    assert last_err is not None
    raise last_err


class GiteaClient:
    """Minimal Gitea/Forgejo REST API client with HTTP/1.1 keep-alive."""

    def __init__(self, base_url: str, token_file: Path, timeout: int = 30) -> None:
        self.base_url = base_url.rstrip("/")
        self.token_file = token_file
        self.timeout = timeout
        self._lock = threading.Lock()
        self._cached_token: str = ""
        self._cached_mtime: float = -1.0
        self._preferred_family: list[socket.AddressFamily | None] = [None]
        self._local = threading.local()

        preferred_family = self._preferred_family

        class _HTTPConn(http.client.HTTPConnection):
            def connect(conn_self) -> None:
                conn_self.sock = _fast_create_connection(
                    (conn_self.host, conn_self.port),
                    conn_self.timeout or timeout,
                    conn_self.source_address,
                    preferred_family,
                )

        class _HTTPSConn(http.client.HTTPSConnection):
            def connect(conn_self) -> None:
                raw_sock = _fast_create_connection(
                    (conn_self.host, conn_self.port),
                    conn_self.timeout or timeout,
                    conn_self.source_address,
                    preferred_family,
                )
                server_hostname = conn_self._tunnel_host or conn_self.host
                conn_self.sock = conn_self._context.wrap_socket(
                    raw_sock, server_hostname=server_hostname
                )

        self._http_cls = _HTTPConn
        self._https_cls = _HTTPSConn

    def close(self) -> None:
        self._close_conn()

    def _close_conn(self) -> None:
        conn = getattr(self._local, "conn", None)
        if conn is not None:
            try:
                conn.close()
            except OSError:
                pass
        self._local.conn = None
        self._local.conn_key = None

    def _get_conn(
        self, scheme: str, host: str, port: int | None
    ) -> http.client.HTTPConnection:
        key = (scheme, host, port)
        conn = getattr(self._local, "conn", None)
        if conn is not None and getattr(self._local, "conn_key", None) == key:
            return conn
        self._close_conn()
        cls = self._https_cls if scheme == "https" else self._http_cls
        conn = cls(host, port=port, timeout=self.timeout)
        self._local.conn = conn
        self._local.conn_key = key
        return conn

    def read_token(self) -> str:
        """Read and cache the Gitea token, reloading automatically on file updates."""
        with self._lock:
            stat = self.token_file.stat()
            if stat.st_mtime != self._cached_mtime:
                self._cached_token = self.token_file.read_text(encoding="utf-8").strip()
                self._cached_mtime = stat.st_mtime
            if not self._cached_token:
                raise ValueError(f"Gitea token file {self.token_file} is empty")
            return self._cached_token

    def request(
        self,
        method: str,
        path_or_url: str,
        params: dict[str, Any] | None = None,
        data: dict[str, Any] | None = None,
    ) -> Any:
        url = (
            path_or_url
            if path_or_url.startswith("http")
            else f"{self.base_url}/api/v1{path_or_url}"
        )
        if params:
            sep = "&" if "?" in url else "?"
            url = f"{url}{sep}{urlencode(params, doseq=True)}"
        body_bytes = None
        headers = {
            "Authorization": f"token {self.read_token()}",
            "Accept": "application/json",
            "User-Agent": "antigravity-gitea-sidecar/1.0",
        }
        if data is not None:
            body_bytes = json.dumps(data).encode("utf-8")
            headers["Content-Type"] = "application/json"

        cur_method = method
        cur_url = url
        for _ in range(4):
            parsed = urlparse(cur_url)
            if not parsed.hostname:
                raise RuntimeError(f"Gitea API invalid URL: {cur_url}")
            target = (parsed.path or "/") + (f"?{parsed.query}" if parsed.query else "")

            status = 0
            raw = b""
            location: str | None = None
            for attempt in range(2):
                conn = self._get_conn(parsed.scheme, parsed.hostname, parsed.port)
                reused = conn.sock is not None
                try:
                    conn.request(cur_method, target, body=body_bytes, headers=headers)
                    resp = conn.getresponse()
                    raw = resp.read()
                    status = resp.status
                    location = resp.getheader("Location")
                    if resp.will_close:
                        self._close_conn()
                    break
                except (
                    http.client.RemoteDisconnected,
                    http.client.BadStatusLine,
                    http.client.CannotSendRequest,
                    BrokenPipeError,
                    ConnectionResetError,
                ) as err:
                    self._close_conn()
                    if reused and attempt == 0:
                        continue
                    raise RuntimeError(
                        f"Gitea API {cur_method} {cur_url} unreachable: {err}"
                    ) from err
                except (OSError, http.client.HTTPException) as err:
                    self._close_conn()
                    raise RuntimeError(
                        f"Gitea API {cur_method} {cur_url} unreachable: {err}"
                    ) from err

            if status in (301, 302, 303, 307, 308) and location:
                cur_url = urljoin(cur_url, location)
                if status == 303:
                    cur_method = "GET"
                    body_bytes = None
                continue
            if status >= 400:
                detail = raw.decode("utf-8", errors="replace")[:300]
                raise RuntimeError(
                    f"Gitea API {cur_method} {cur_url} failed ({status}): {detail}"
                )
            if not raw:
                return None
            return json.loads(raw.decode("utf-8"))

        raise RuntimeError(f"Gitea API {method} {url} exceeded redirect limit")

    def paginate(
        self,
        path: str,
        params: dict[str, Any] | None = None,
        limit: int = 50,
        max_pages: int = 20,
    ) -> list[dict[str, Any]]:
        results: list[dict[str, Any]] = []
        base_params = dict(params or {})
        base_params["limit"] = limit
        for page in range(1, max_pages + 1):
            base_params["page"] = page
            chunk = self.request("GET", path, params=base_params)
            if not isinstance(chunk, list) or not chunk:
                break
            results.extend(chunk)
            if len(chunk) < limit:
                break
        return results

    def get_current_user(self) -> dict[str, Any]:
        return self.request("GET", "/user")

    def list_unread_notifications(self) -> list[dict[str, Any]]:
        return self.paginate("/notifications", params={"status-types": "unread"})

    def get_notification_thread(self, thread_id: str) -> dict[str, Any] | None:
        res = self.request("GET", f"/notifications/threads/{thread_id}")
        return res if isinstance(res, dict) else None

    def mark_thread_read(self, thread_id: str) -> None:
        self.request(
            "PATCH", f"/notifications/threads/{thread_id}", params={"to-status": "read"}
        )

    def get_issue(self, owner: str, repo: str, index: int) -> dict[str, Any]:
        return self.request("GET", f"/repos/{owner}/{repo}/issues/{index}")

    def get_repo(self, owner: str, repo: str) -> dict[str, Any]:
        res = self.request("GET", f"/repos/{owner}/{repo}")
        return res if isinstance(res, dict) else {}

    def get_pull(self, owner: str, repo: str, index: int) -> dict[str, Any]:
        return self.request("GET", f"/repos/{owner}/{repo}/pulls/{index}")

    def search_issues(
        self,
        *,
        state: str = "open",
        since: str | None = None,
        mentioned: bool = False,
        assigned: bool = False,
        review_requested: bool = False,
        created: bool = False,
        reviewed: bool = False,
    ) -> list[dict[str, Any]]:
        params: dict[str, Any] = {"state": state}
        if since:
            params["since"] = since
        if mentioned:
            params["mentioned"] = "true"
        if assigned:
            params["assigned"] = "true"
        if review_requested:
            params["review_requested"] = "true"
        if created:
            params["created"] = "true"
        if reviewed:
            params["reviewed"] = "true"
        return self.paginate("/repos/issues/search", params=params)

    def list_issue_comments(
        self, owner: str, repo: str, index: int
    ) -> list[dict[str, Any]]:
        return self.paginate(f"/repos/{owner}/{repo}/issues/{index}/comments")

    def list_issue_timeline(
        self, owner: str, repo: str, index: int
    ) -> list[dict[str, Any]]:
        return self.paginate(f"/repos/{owner}/{repo}/issues/{index}/timeline")

    def list_pull_reviews(
        self, owner: str, repo: str, index: int
    ) -> list[dict[str, Any]]:
        return self.paginate(f"/repos/{owner}/{repo}/pulls/{index}/reviews")

    def list_pull_review_comments(
        self, owner: str, repo: str, index: int, review_id: int
    ) -> list[dict[str, Any]]:
        res = self.request(
            "GET", f"/repos/{owner}/{repo}/pulls/{index}/reviews/{review_id}/comments"
        )
        return res if isinstance(res, list) else []


class StateStore:
    """Thread-safe persistent JSON state for processed notifications and conversation links."""

    def __init__(self, path: Path) -> None:
        self.path = path
        self._lock = threading.Lock()
        self._data: dict[str, Any] = {
            "threads": {},
            "conversations": {},
            "commit_comments": [],
            "retries": {},
            "search_cursor": None,
        }
        self._load()

    def _load(self) -> None:
        if not self.path.exists():
            return
        try:
            loaded = json.loads(self.path.read_text(encoding="utf-8"))
            if isinstance(loaded, dict):
                for key in ("threads", "conversations", "retries"):
                    if isinstance(loaded.get(key), dict):
                        self._data[key] = loaded[key]
                if isinstance(loaded.get("commit_comments"), list):
                    self._data["commit_comments"] = loaded["commit_comments"]
                if isinstance(loaded.get("search_cursor"), str):
                    self._data["search_cursor"] = loaded["search_cursor"]
        except (OSError, json.JSONDecodeError) as err:
            LOG.warning(
                "Failed to load state file %s (%s); starting fresh", self.path, err
            )

    def get_search_cursor(self) -> str | None:
        with self._lock:
            val = self._data.get("search_cursor")
            return str(val) if val else None

    def set_search_cursor(self, cursor: str) -> None:
        with self._lock:
            self._data["search_cursor"] = cursor
            self._save_locked()

    def _save_locked(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_suffix(".tmp")
        tmp.write_text(
            json.dumps(self._data, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        os.replace(tmp, self.path)

    def get_thread_state(self, key: str) -> dict[str, Any] | None:
        with self._lock:
            entry = self._data["threads"].get(key)
            return dict(entry) if entry is not None else None

    def set_thread_state(self, key: str, state: dict[str, Any]) -> None:
        with self._lock:
            self._data["threads"][key] = state
            self._data["retries"].pop(key, None)
            self._save_locked()

    def get_conversation(self, key: str) -> str | None:
        with self._lock:
            val = self._data["conversations"].get(key)
            return str(val) if val else None

    def set_conversation(self, key: str, conversation_id: str) -> None:
        with self._lock:
            self._data["conversations"][key] = conversation_id
            self._save_locked()

    def has_commit_comment(self, comment_id: int) -> bool:
        with self._lock:
            return comment_id in self._data["commit_comments"]

    def add_commit_comment(self, comment_id: int) -> None:
        with self._lock:
            ids: list[int] = self._data["commit_comments"]
            if comment_id not in ids:
                ids.append(comment_id)
                if len(ids) > 500:
                    self._data["commit_comments"] = ids[-500:]
            self._save_locked()

    def should_skip_retry(self, key: str, now: float | None = None) -> bool:
        current = time.time() if now is None else now
        with self._lock:
            entry = self._data["retries"].get(key)
            return bool(entry and entry.get("next_retry_at", 0) > current)

    def get_ready_retry_keys(self, now: float | None = None) -> list[str]:
        current = time.time() if now is None else now
        with self._lock:
            return [
                k
                for k, entry in self._data["retries"].items()
                if entry.get("next_retry_at", 0) <= current
            ]

    def record_failure(self, key: str, base_delay: int = 15) -> float:
        with self._lock:
            entry = self._data["retries"].get(key, {"count": 0})
            count = int(entry.get("count", 0)) + 1
            delay = min(MAX_BACKOFF_SECONDS, base_delay * (2 ** min(count - 1, 5)))
            next_at = time.time() + delay
            self._data["retries"][key] = {"count": count, "next_retry_at": next_at}
            self._save_locked()
            return delay


def _git_output(repo_dir: Path, *args: str) -> str | None:
    try:
        proc = subprocess.run(
            ["git", "-C", str(repo_dir), *args],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        if proc.returncode != 0:
            return None
        return proc.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return None


def get_git_repo_info(repo_dir: Path) -> tuple[set[str], str | None]:
    """Return (normalized remote slugs, current branch name) for a local git checkout."""
    if not repo_dir.is_dir():
        return set(), None
    remotes_raw = _git_output(repo_dir, "remote", "-v")
    if remotes_raw is None:
        return set(), None
    slugs: set[str] = set()
    for line in remotes_raw.splitlines():
        parts = line.split()
        if len(parts) >= 2:
            slug = normalize_repo_slug(parts[1])
            if slug:
                slugs.add(slug)
    branch = _git_output(repo_dir, "rev-parse", "--abbrev-ref", "HEAD")
    return slugs, branch


def is_conversation_archived(app_data_dir: Path, conversation_id: str) -> bool:
    pbtxt = app_data_dir / "annotations" / f"{conversation_id}.pbtxt"
    if not pbtxt.is_file():
        return False
    try:
        return "archived:true" in pbtxt.read_text(
            encoding="utf-8", errors="ignore"
        ).replace(" ", "")
    except OSError:
        return False


def read_transcript_excerpt(app_data_dir: Path, conversation_id: str) -> str:
    """Read the tail of a conversation transcript so recent PR links stay visible."""
    transcript = (
        app_data_dir
        / "brain"
        / conversation_id
        / ".system_generated"
        / "logs"
        / "transcript.jsonl"
    )
    if not transcript.is_file():
        return ""
    try:
        with transcript.open("rb") as fh:
            fh.seek(0, os.SEEK_END)
            fh.seek(max(0, fh.tell() - MAX_TRANSCRIPT_BYTES))
            return fh.read(MAX_TRANSCRIPT_BYTES).decode("utf-8", errors="ignore")
    except OSError:
        return ""


class ConversationRouter:
    """Maps Gitea PRs and issues to Antigravity conversations and workspaces."""

    def __init__(self, cfg: Config, state: StateStore) -> None:
        self.cfg = cfg
        self.state = state

    def conversation_exists(self, conversation_id: str) -> bool:
        return (
            self.cfg.app_data_dir / "conversations" / f"{conversation_id}.db"
        ).is_file()

    def _list_top_level_conversations(self) -> list[dict[str, Any]]:
        db_path = self.cfg.app_data_dir / "conversation_summaries.db"
        if not db_path.is_file():
            return []
        try:
            conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True, timeout=5.0)
            conn.row_factory = sqlite3.Row
            try:
                rows = conn.execute("""
                    SELECT conversation_id, title, workspace_uris, project_id, last_modified_time
                    FROM conversation_summaries
                    WHERE parent_conversation_id = ''
                    ORDER BY last_modified_time DESC
                    """).fetchall()
                return [dict(r) for r in rows]
            finally:
                conn.close()
        except sqlite3.Error as err:
            LOG.warning("Failed to read %s: %s", db_path, err)
            return []

    def _parse_workspace_dirs(self, workspace_uris_json: str) -> list[Path]:
        if not workspace_uris_json:
            return []
        try:
            uris = json.loads(workspace_uris_json)
        except json.JSONDecodeError:
            return []
        dirs: list[Path] = []
        if isinstance(uris, list):
            for uri in uris:
                if isinstance(uri, str):
                    p = file_uri_to_path(uri)
                    if p is not None and p.is_dir():
                        dirs.append(p)
        return dirs

    def find_conversation_for_pr(
        self,
        *,
        repo_full: str,
        index: int,
        head_repo: str,
        head_ref: str,
    ) -> tuple[str, Path | None] | None:
        """Locate the best existing Antigravity conversation matching a PR."""
        thread_key = f"{repo_full}#{index}"
        cached = self.state.get_conversation(thread_key)
        rows = self._list_top_level_conversations()
        rows_by_id = {r["conversation_id"]: r for r in rows}

        if cached and self.conversation_exists(cached):
            row = rows_by_id.get(cached)
            ws_dirs = self._parse_workspace_dirs(row["workspace_uris"]) if row else []
            return cached, (ws_dirs[0] if ws_dirs else None)

        target_repos = {repo_full.lower()}
        if head_repo:
            target_repos.add(head_repo.lower())

        non_default_branch = bool(head_ref) and head_ref not in {"main", "master"}
        exact_url_needle = f"/{repo_full.lower()}/pulls/{index}"
        pr_ref_re = re.compile(rf"(?:pulls/{index}(?!\d)|#{index}(?!\d))")

        best: tuple[int, str, str, Path | None] | None = None
        for row in rows:
            conv_id = row["conversation_id"]
            if not self.conversation_exists(conv_id):
                continue
            ws_dirs = self._parse_workspace_dirs(row.get("workspace_uris", ""))

            repo_slugs: set[str] = set()
            branches: set[str] = set()
            matched_ws: Path | None = None
            for ws in ws_dirs:
                slugs, branch = get_git_repo_info(ws)
                repo_slugs.update(slugs)
                if branch:
                    branches.add(branch)
                if slugs & target_repos:
                    if matched_ws is None or (
                        non_default_branch and branch == head_ref
                    ):
                        matched_ws = ws

            matches_repo = bool(repo_slugs & target_repos)
            # Exclude conversations clearly belonging to a different git repo.
            if repo_slugs and not matches_repo:
                continue

            branch_match = (
                non_default_branch and matches_repo and (head_ref in branches)
            )
            transcript = read_transcript_excerpt(self.cfg.app_data_dir, conv_id)
            transcript_lower = transcript.lower()
            exact_url_match = exact_url_needle in transcript_lower
            pr_ref_match = matches_repo and bool(pr_ref_re.search(transcript_lower))
            head_ref_match = (
                non_default_branch
                and matches_repo
                and (head_ref.lower() in transcript_lower)
            )

            if not (branch_match or exact_url_match or pr_ref_match):
                continue

            archived = is_conversation_archived(self.cfg.app_data_dir, conv_id)
            score = 0
            if branch_match:
                score += 2000
            if matches_repo:
                score += 1000
            if exact_url_match:
                score += 500
            if pr_ref_match:
                score += 300
            if head_ref_match:
                score += 200
            if not archived:
                score += 500

            last_mod = str(row.get("last_modified_time", ""))
            candidate = (
                score,
                last_mod,
                conv_id,
                matched_ws or (ws_dirs[0] if ws_dirs else None),
            )
            if best is None or (candidate[0], candidate[1]) > (best[0], best[1]):
                best = candidate

        if best is None:
            return None
        _, _, conv_id, ws_dir = best
        self.state.set_conversation(thread_key, conv_id)
        return conv_id, ws_dir

    def resolve_workspace(
        self,
        *,
        repo_full: str,
        ssh_url: str,
        clone_url: str,
    ) -> Path:
        """Find or clone a local workspace matching the repository."""
        target_slug = repo_full.lower()
        owner, repo_name = repo_full.split("/", 1)
        projects_dir = self.cfg.gemini_config_dir / "projects"

        if projects_dir.is_dir():
            for proj_file in sorted(projects_dir.glob("*.json")):
                try:
                    proj = json.loads(proj_file.read_text(encoding="utf-8"))
                except (OSError, json.JSONDecodeError):
                    continue
                resources = (proj.get("projectResources") or {}).get("resources") or []
                for res in resources:
                    git_folder = res.get("gitFolder") or {}
                    folder_uri = git_folder.get("folderUri", "")
                    ws_path = file_uri_to_path(folder_uri)
                    if ws_path is not None and ws_path.is_dir():
                        slugs, _ = get_git_repo_info(ws_path)
                        if target_slug in slugs:
                            return ws_path

        # Check ~/src/<repo_name> or ~/src/<owner>/<repo_name>
        candidate_dir = self.cfg.repos_dir / repo_name
        if candidate_dir.is_dir():
            slugs, _ = get_git_repo_info(candidate_dir)
            if target_slug in slugs:
                return candidate_dir
            candidate_dir = self.cfg.repos_dir / owner / repo_name
            if candidate_dir.is_dir():
                slugs, _ = get_git_repo_info(candidate_dir)
                if target_slug in slugs:
                    return candidate_dir

        return self._clone_repo(candidate_dir, ssh_url=ssh_url, clone_url=clone_url)

    def _clone_repo(self, dest: Path, *, ssh_url: str, clone_url: str) -> Path:
        if dest.exists():
            return dest
        dest.parent.mkdir(parents=True, exist_ok=True)
        urls = [u for u in (ssh_url, clone_url) if u]
        for url in urls:
            LOG.info("Cloning %s into %s", url, dest)
            proc = subprocess.run(
                ["git", "clone", url, str(dest)],
                capture_output=True,
                text=True,
                timeout=300,
                check=False,
            )
            if proc.returncode == 0:
                return dest
            LOG.warning("git clone %s failed: %s", url, proc.stderr.strip())
        raise RuntimeError(f"Failed to clone repository into {dest}")


@dataclass
class NotificationTrigger:
    """Actionable notification payload to dispatch to Antigravity."""

    thread_id: str | None
    thread_key: str
    subject_type: str
    repo_full: str
    index: int
    title: str
    html_url: str
    state_str: str
    body: str
    author: str
    ssh_url: str
    clone_url: str
    head_repo: str = ""
    head_ref: str = ""
    base_ref: str = ""
    reasons: list[str] = field(default_factory=list)
    new_comments: list[dict[str, Any]] = field(default_factory=list)
    new_reviews: list[dict[str, Any]] = field(default_factory=list)
    new_review_comments: list[dict[str, Any]] = field(default_factory=list)
    next_thread_state: dict[str, Any] = field(default_factory=dict)
    commit_comment_id: int | None = None


def _last_bot_comment_id(comments: list[dict[str, Any]], bot_login: str) -> int:
    last_id = 0
    for c in comments:
        if ((c.get("user") or {}).get("login") or "") == bot_login:
            last_id = max(last_id, int(c.get("id") or 0))
    return last_id


def _last_bot_review_id(reviews: list[dict[str, Any]], bot_login: str) -> int:
    last_id = 0
    for r in reviews:
        if ((r.get("user") or {}).get("login") or "") == bot_login:
            last_id = max(last_id, int(r.get("id") or 0))
    return last_id


def _is_allowed_actor(login: str, allowed_users: frozenset[str]) -> bool:
    if not allowed_users:
        return True
    return login.lower() in allowed_users


def _assignment_actor_allowed(
    client: GiteaClient,
    owner: str,
    repo_name: str,
    index: int,
    bot_login: str,
    issue_author: str,
    allowed_users: frozenset[str],
) -> bool:
    if not allowed_users:
        return True
    try:
        timeline = client.list_issue_timeline(owner, repo_name, index)
    except Exception as err:  # noqa: BLE001
        LOG.warning(
            "Failed to inspect timeline for %s/%s#%d: %s", owner, repo_name, index, err
        )
        return _is_allowed_actor(issue_author, allowed_users)

    latest_actor: str | None = None
    for ev in timeline:
        if ev.get("type") in {"assignees", "review_request"}:
            target = ((ev.get("assignee") or {}).get("login") or "").lower()
            if target == bot_login.lower():
                latest_actor = (ev.get("user") or {}).get("login") or ""
    actor = latest_actor if latest_actor is not None else issue_author
    if not _is_allowed_actor(actor, allowed_users):
        LOG.info(
            "Ignoring assignment/review-request on %s/%s#%d from disallowed user @%s",
            owner,
            repo_name,
            index,
            actor or "unknown",
        )
        return False
    return True


def evaluate_thread(
    client: GiteaClient,
    state_store: StateStore,
    thread: dict[str, Any],
    bot_login: str,
    allowed_users: frozenset[str] = frozenset(),
) -> tuple[NotificationTrigger | None, dict[str, Any] | None]:
    """Inspect a Gitea unread notification thread and decide whether to trigger an agent run.

    Returns (trigger, state_to_mark_seen_if_ignored).
    """
    raw_thread_id = thread.get("id")
    thread_id = str(raw_thread_id) if raw_thread_id is not None else None
    repo_info = thread.get("repository") or {}
    repo_full = repo_info.get("full_name", "")
    subject = thread.get("subject") or {}
    subject_type = subject.get("type", "")
    subject_url = subject.get("url", "")
    html_url = subject.get("html_url", "")
    updated_at = thread.get("updated_at", "")

    if "/" not in repo_full:
        return None, None
    owner, repo_name = repo_full.split("/", 1)

    if subject_type == "Commit":
        latest_comment_url = subject.get("latest_comment_url", "")
        if not latest_comment_url:
            return None, None
        comment = client.request("GET", latest_comment_url)
        if not isinstance(comment, dict):
            return None, None
        cid = int(comment.get("id") or 0)
        author = (comment.get("user") or {}).get("login") or ""
        body = comment.get("body") or ""
        if (
            author != bot_login
            and cid
            and not state_store.has_commit_comment(cid)
            and mentions_user(body, bot_login)
        ):
            if not _is_allowed_actor(author, allowed_users):
                LOG.info(
                    "Ignoring commit comment #%d on %s from disallowed user @%s",
                    cid,
                    repo_full,
                    author or "unknown",
                )
                return None, None
            sha = subject_url.rstrip("/").split("/")[-1]
            return (
                NotificationTrigger(
                    thread_id=thread_id,
                    thread_key=f"{repo_full}@commit:{sha[:12]}",
                    subject_type="Commit",
                    repo_full=repo_full,
                    index=0,
                    title=subject.get("title") or f"Commit {sha[:12]}",
                    html_url=comment.get("html_url") or html_url,
                    state_str="open",
                    body="",
                    author=author,
                    ssh_url=repo_info.get("ssh_url", ""),
                    clone_url=repo_info.get("clone_url", ""),
                    reasons=[f"mentioned @{bot_login} in commit comment"],
                    new_comments=[comment],
                    commit_comment_id=cid,
                ),
                None,
            )
        return None, None

    if subject_type not in {"Issue", "Pull"}:
        return None, None

    index = extract_index_from_url(subject_url) or extract_index_from_url(html_url)
    if index is None:
        return None, None

    thread_key = f"{repo_full}#{index}"
    issue = client.get_issue(owner, repo_name, index)
    is_pr = subject_type == "Pull" or bool(issue.get("pull_request"))
    pr = client.get_pull(owner, repo_name, index) if is_pr else None

    state_str = (
        "merged" if (pr and pr.get("merged")) else (issue.get("state") or "open")
    )
    issue_author = (issue.get("user") or {}).get("login") or ""
    issue_body = issue.get("body") or ""

    assignees: set[str] = set()
    for a in issue.get("assignees") or []:
        if a.get("login"):
            assignees.add(a["login"])
    if (issue.get("assignee") or {}).get("login"):
        assignees.add(issue["assignee"]["login"])
    requested_reviewers: set[str] = set()
    if pr:
        for r in pr.get("requested_reviewers") or []:
            if r.get("login"):
                requested_reviewers.add(r["login"])

    is_assigned = (bot_login in assignees) or (bot_login in requested_reviewers)

    comments = client.list_issue_comments(owner, repo_name, index)
    reviews = client.list_pull_reviews(owner, repo_name, index) if is_pr else []

    review_comments_all: list[dict[str, Any]] = []
    for rev in reviews:
        if rev.get("state") == "PENDING":
            continue
        if int(rev.get("comments_count") or 0) > 0:
            review_comments_all.extend(
                client.list_pull_review_comments(
                    owner, repo_name, index, int(rev["id"])
                )
            )

    has_bot_activity = (
        _last_bot_comment_id(comments, bot_login) > 0
        or _last_bot_review_id(reviews, bot_login) > 0
        or any(
            ((rc.get("user") or {}).get("login") or "") == bot_login
            for rc in review_comments_all
        )
    )
    is_participant = (issue_author == bot_login) or is_assigned or has_bot_activity

    prev = state_store.get_thread_state(thread_key)
    if prev is None:
        cutoff_comment_id = _last_bot_comment_id(comments, bot_login)
        cutoff_review_id = _last_bot_review_id(reviews, bot_login)
        seen_comment_ids = {
            int(c["id"]) for c in comments if int(c.get("id") or 0) <= cutoff_comment_id
        }
        seen_review_ids = {
            int(r["id"]) for r in reviews if int(r.get("id") or 0) <= cutoff_review_id
        }
        seen_review_comment_ids: set[int] = set()
        if cutoff_review_id:
            for rc in review_comments_all:
                if int(rc.get("pull_request_review_id") or 0) <= cutoff_review_id:
                    seen_review_comment_ids.add(int(rc["id"]))
        prev_assigned = False
        seen_body = cutoff_comment_id > 0 or cutoff_review_id > 0
    else:
        seen_comment_ids = {int(i) for i in prev.get("seen_comment_ids", [])}
        seen_review_ids = {int(i) for i in prev.get("seen_review_ids", [])}
        seen_review_comment_ids = {
            int(i) for i in prev.get("seen_review_comment_ids", [])
        }
        prev_assigned = bool(prev.get("assigned", False))
        seen_body = bool(prev.get("seen_body", False))

    raw_unseen_comments = [
        c
        for c in comments
        if int(c.get("id") or 0) not in seen_comment_ids
        and ((c.get("user") or {}).get("login") or "") != bot_login
    ]
    raw_unseen_reviews = [
        r
        for r in reviews
        if r.get("state") != "PENDING"
        and int(r.get("id") or 0) not in seen_review_ids
        and ((r.get("user") or {}).get("login") or "") != bot_login
    ]
    raw_unseen_review_comments = [
        rc
        for rc in review_comments_all
        if int(rc.get("id") or 0) not in seen_review_comment_ids
        and ((rc.get("user") or {}).get("login") or "") != bot_login
    ]

    unseen_comments = [
        c
        for c in raw_unseen_comments
        if _is_allowed_actor(((c.get("user") or {}).get("login") or ""), allowed_users)
    ]
    unseen_reviews = [
        r
        for r in raw_unseen_reviews
        if _is_allowed_actor(((r.get("user") or {}).get("login") or ""), allowed_users)
    ]
    unseen_review_comments = [
        rc
        for rc in raw_unseen_review_comments
        if _is_allowed_actor(((rc.get("user") or {}).get("login") or ""), allowed_users)
    ]

    disallowed_actors = sorted(
        {
            ((item.get("user") or {}).get("login") or "unknown")
            for item in (
                raw_unseen_comments + raw_unseen_reviews + raw_unseen_review_comments
            )
            if not _is_allowed_actor(
                ((item.get("user") or {}).get("login") or ""), allowed_users
            )
        }
    )
    if disallowed_actors:
        LOG.info(
            "Ignoring comment/review activity on %s from disallowed user(s): %s",
            thread_key,
            ", ".join(f"@{u}" for u in disallowed_actors),
        )

    raw_body_mentioned = (
        (not seen_body)
        and (issue_author != bot_login)
        and mentions_user(issue_body, bot_login)
    )
    if raw_body_mentioned and not _is_allowed_actor(issue_author, allowed_users):
        LOG.info(
            "Ignoring body mention on %s from disallowed user @%s",
            thread_key,
            issue_author or "unknown",
        )
    body_mentioned = raw_body_mentioned and _is_allowed_actor(
        issue_author, allowed_users
    )
    comment_mentioned = any(
        mentions_user(c.get("body"), bot_login) for c in unseen_comments
    )
    review_mentioned = any(
        mentions_user(r.get("body"), bot_login) for r in unseen_reviews
    ) or any(mentions_user(rc.get("body"), bot_login) for rc in unseen_review_comments)
    has_mention = body_mentioned or comment_mentioned or review_mentioned
    newly_assigned = (
        is_assigned
        and not prev_assigned
        and _assignment_actor_allowed(
            client, owner, repo_name, index, bot_login, issue_author, allowed_users
        )
    )

    substantive_reviews = [
        r
        for r in unseen_reviews
        if (r.get("body") or "").strip()
        or r.get("state") in {"REQUEST_CHANGES", "REQUEST_REVIEW"}
    ]
    has_new_feedback = bool(
        unseen_comments or unseen_review_comments or substantive_reviews
    )

    should_trigger = has_mention or (
        state_str == "open"
        and (newly_assigned or (is_participant and has_new_feedback))
    )

    next_state = {
        "seen_body": True,
        "seen_comment_ids": sorted({int(c["id"]) for c in comments if c.get("id")}),
        "seen_review_ids": sorted(
            {
                int(r["id"])
                for r in reviews
                if r.get("id") and r.get("state") != "PENDING"
            }
        ),
        "seen_review_comment_ids": sorted(
            {int(rc["id"]) for rc in review_comments_all if rc.get("id")}
        ),
        "assigned": is_assigned,
        "last_updated_at": updated_at,
    }

    if not should_trigger:
        return None, next_state

    reasons: list[str] = []
    if has_mention:
        reasons.append(f"@{bot_login} mentioned")
    if newly_assigned:
        reasons.append(f"assigned/review-requested @{bot_login}")
    if is_participant and has_new_feedback and not reasons:
        reasons.append("new PR/issue reply or review feedback")

    head_repo = ""
    head_ref = ""
    base_ref = ""
    if pr:
        head = pr.get("head") or {}
        base = pr.get("base") or {}
        head_ref = head.get("ref") or ""
        head_repo = ((head.get("repo") or {}).get("full_name")) or repo_full
        base_ref = base.get("ref") or ""

    ssh_url = repo_info.get("ssh_url", "")
    clone_url = repo_info.get("clone_url", "")
    if pr and (not ssh_url or not clone_url):
        base_repo = (pr.get("base") or {}).get("repo") or {}
        ssh_url = ssh_url or base_repo.get("ssh_url", "")
        clone_url = clone_url or base_repo.get("clone_url", "")
    if not ssh_url or not clone_url:
        full_repo = client.get_repo(owner, repo_name)
        ssh_url = ssh_url or full_repo.get("ssh_url", "")
        clone_url = clone_url or full_repo.get("clone_url", "")

    trigger = NotificationTrigger(
        thread_id=thread_id,
        thread_key=thread_key,
        subject_type="Pull" if is_pr else "Issue",
        repo_full=repo_full,
        index=index,
        title=issue.get("title") or subject.get("title") or "",
        html_url=issue.get("html_url") or html_url,
        state_str=state_str,
        body=issue_body,
        author=issue_author,
        ssh_url=ssh_url,
        clone_url=clone_url,
        head_repo=head_repo,
        head_ref=head_ref,
        base_ref=base_ref,
        reasons=reasons,
        new_comments=unseen_comments,
        new_reviews=substantive_reviews,
        new_review_comments=unseen_review_comments,
        next_thread_state=next_state,
    )
    return trigger, None


def _truncate_description(body: str) -> str:
    text = body.strip()
    if len(text) <= MAX_DESCRIPTION_CHARS:
        return text
    return (
        text[:MAX_DESCRIPTION_CHARS].rstrip()
        + "\n... (truncated; fetch full body with `tea` if needed)"
    )


def build_prompt(
    trigger: NotificationTrigger,
    bot_login: str,
    workspace_dir: Path | None = None,
    *,
    existing_conversation: bool = False,
) -> str:
    """Render a concise prompt describing the Gitea notification event."""
    del bot_login
    ref = f"{trigger.repo_full}#{trigger.index}" if trigger.index else trigger.repo_full
    has_updates = bool(
        trigger.new_reviews or trigger.new_review_comments or trigger.new_comments
    )

    if existing_conversation:
        details: list[str] = []
        if trigger.subject_type == "Pull" and trigger.head_ref:
            details.append(f"branch `{trigger.head_ref}`")
        details.extend(trigger.reasons)
        lines = [f"Gitea follow-up on `{ref}` ({', '.join(details)}):"]
        if not has_updates and trigger.body.strip():
            lines.extend(["", "Description:", _truncate_description(trigger.body)])
    else:
        lines = [
            f"Gitea {trigger.subject_type} `{ref}` ({trigger.state_str}, by @{trigger.author}): {trigger.title}",
            f"Trigger: {', '.join(trigger.reasons)} | URL: {trigger.html_url}",
        ]
        meta: list[str] = []
        if workspace_dir is not None:
            meta.append(f"Workspace: {workspace_dir}")
        if trigger.subject_type == "Pull":
            meta.append(
                f"Branches: {trigger.head_repo}:{trigger.head_ref} -> {trigger.base_ref}"
            )
        if meta:
            lines.append(" | ".join(meta))

        if trigger.body.strip():
            lines.extend(["", "Description:", _truncate_description(trigger.body)])

    if trigger.new_reviews:
        lines.extend(["", "New PR Reviews:"])
        for rev in trigger.new_reviews:
            r_user = (rev.get("user") or {}).get("login") or "unknown"
            r_state = rev.get("state") or ""
            r_body = (rev.get("body") or "").strip() or "(no review summary)"
            lines.append(
                f"- Review #{rev.get('id')} by @{r_user} [{r_state}]: {r_body}"
            )

    if trigger.new_review_comments:
        lines.extend(["", "New Inline PR Review Comments:"])
        for rc in trigger.new_review_comments:
            rc_user = (rc.get("user") or {}).get("login") or "unknown"
            rc_path = rc.get("path") or ""
            rc_hunk = (rc.get("diff_hunk") or "").strip()
            rc_body = (rc.get("body") or "").strip()
            lines.append(
                f"- File `{rc_path}` (by @{rc_user}, comment #{rc.get('id')}):"
            )
            if rc_hunk:
                lines.append(f"  Diff hunk:\n```\n{rc_hunk[-1000:]}\n```")
            lines.append(f"  Comment: {rc_body}")

    if trigger.new_comments:
        lines.extend(["", "New Comments:"])
        for c in trigger.new_comments:
            c_user = (c.get("user") or {}).get("login") or "unknown"
            c_body = (c.get("body") or "").strip()
            lines.append(
                f"- Comment #{c.get('id')} by @{c_user} ({c.get('created_at', '')}):\n{c_body}"
            )

    reaction_target = ""
    if trigger.new_comments and trigger.new_comments[-1].get("id"):
        reaction_target = f"comment #{trigger.new_comments[-1]['id']}"
    elif trigger.new_review_comments and trigger.new_review_comments[-1].get("id"):
        reaction_target = f"comment #{trigger.new_review_comments[-1]['id']}"
    elif trigger.index:
        reaction_target = f"{trigger.subject_type.lower()} #{trigger.index}"

    lines.extend(["", "Instructions (use the `gitea` skill):"])
    step = 1
    if reaction_target:
        lines.append(f"{step}. First, add an `eyes` reaction to {reaction_target}.")
        step += 1

    if not existing_conversation:
        if trigger.subject_type == "Pull" and trigger.head_ref:
            lines.append(
                f"{step}. If code changes are needed, work on PR branch `{trigger.head_ref}`, verify, commit, and push."
            )
        elif trigger.index:
            lines.append(f"{step}. Investigate or address this in the repository.")
        else:
            lines.append(f"{step}. Investigate the commit comment in the repository.")
        step += 1

    if trigger.new_review_comments and trigger.new_review_comments[-1].get("id"):
        rcid = trigger.new_review_comments[-1]["id"]
        reply_cmd = f'(`tea pr reply --login local --repo {trigger.repo_full} {trigger.index} {rcid} "<reply>"`); do not open a new review thread.'
        if existing_conversation:
            lines.append(
                f"{step}. Address the update above (making and pushing changes if needed) "
                f"and reply in-thread for comment #{rcid} {reply_cmd}"
            )
        else:
            lines.append(f"{step}. Reply in-thread for comment #{rcid} {reply_cmd}")
    elif trigger.index:
        if existing_conversation:
            lines.append(
                f"{step}. Address the update above (making and pushing changes if needed) "
                f"and post a concise reply on `{ref}`."
            )
        else:
            lines.append(f"{step}. Post a concise reply on `{ref}`.")
    else:
        if existing_conversation:
            lines.append(
                f"{step}. Address the update above and post a concise reply on Gitea for `{trigger.repo_full}`."
            )
        else:
            lines.append(
                f"{step}. Post a concise reply on Gitea for `{trigger.repo_full}`."
            )
    return "\n".join(lines)


_UUID_RE = re.compile(
    r"\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b",
    re.IGNORECASE,
)


def parse_agentapi_conversation_id(stdout: str) -> str:
    """Extract a conversation ID from `agentapi new-conversation` output."""
    text = stdout.strip()
    if not text:
        return ""

    def _find_in_obj(obj: Any) -> str:
        if isinstance(obj, dict):
            for key in ("conversationId", "conversation_id", "cascadeId", "cascade_id"):
                val = obj.get(key)
                if isinstance(val, str) and val.strip():
                    return val.strip()
            for val in obj.values():
                found = _find_in_obj(val)
                if found:
                    return found
        elif isinstance(obj, list):
            for item in obj:
                found = _find_in_obj(item)
                if found:
                    return found
        return ""

    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        parsed = None
    if parsed is not None:
        found = _find_in_obj(parsed)
        if found:
            return found

    match = _UUID_RE.search(text)
    return match.group(0) if match else ""


def run_agentapi(
    cfg: Config,
    *,
    conversation_id: str | None,
    workspace_dir: Path,
    prompt: str,
    title: str = "",
) -> str:
    """Dispatch a turn through the parent language server via `agentapi`."""
    clean_title = title.strip()[:120]
    if conversation_id:
        cmd = [cfg.agentapi_bin, "send-message"]
        if clean_title:
            cmd.append(f"--title={clean_title}")
        cmd.extend(["--", conversation_id, prompt])
    else:
        cmd = [cfg.agentapi_bin, "new-conversation"]
        if cfg.model:
            cmd.append(f"--model={cfg.model}")
        if clean_title:
            cmd.append(f"--title={clean_title}")
        cmd.extend(["--", prompt])

    proc = subprocess.run(
        cmd,
        cwd=str(workspace_dir),
        env=dict(os.environ),
        capture_output=True,
        text=True,
        timeout=AGENTAPI_TIMEOUT_SECONDS,
        check=False,
    )
    if proc.returncode != 0:
        err_msg = proc.stderr.strip() or proc.stdout.strip()
        raise RuntimeError(f"agentapi failed (rc={proc.returncode}): {err_msg[:500]}")
    if conversation_id:
        return conversation_id
    return parse_agentapi_conversation_id(proc.stdout)


class SidecarDaemon:
    """Coordinates Gitea polling, conversation routing, and worker execution."""

    def __init__(self, cfg: Config) -> None:
        self.cfg = cfg
        self.client = GiteaClient(cfg.gitea_url, cfg.token_file)
        self.state = StateStore(cfg.state_file)
        self.router = ConversationRouter(cfg, self.state)
        self.stop_event = threading.Event()
        self._lock_guard = threading.Lock()
        self._locks: dict[str, threading.Lock] = {}
        self._in_flight: set[str] = set()
        self._futures: set[Future[Any]] = set()
        self._bot_login: str = ""

    def _get_lock(self, key: str) -> threading.Lock:
        with self._lock_guard:
            lock = self._locks.get(key)
            if lock is None:
                lock = threading.Lock()
                self._locks[key] = lock
            return lock

    def _ensure_bot_login(self) -> str:
        if not self._bot_login:
            user = self.client.get_current_user()
            login = user.get("login") or user.get("username") or ""
            if not login:
                raise RuntimeError(
                    "Could not determine authenticated Gitea username from /api/v1/user"
                )
            self._bot_login = login
            LOG.info(
                "Authenticated with Gitea (%s) as @%s",
                self.cfg.gitea_url,
                self._bot_login,
            )
        return self._bot_login

    def _handle_trigger(self, trigger: NotificationTrigger) -> None:
        thread_lock = self._get_lock(f"thread:{trigger.thread_key}")
        with thread_lock:
            conv_id: str | None = None
            ws_dir: Path | None = None

            if trigger.subject_type == "Pull":
                routed = self.router.find_conversation_for_pr(
                    repo_full=trigger.repo_full,
                    index=trigger.index,
                    head_repo=trigger.head_repo,
                    head_ref=trigger.head_ref,
                )
                if routed is not None:
                    conv_id, ws_dir = routed
            elif trigger.index:
                cached = self.state.get_conversation(trigger.thread_key)
                if cached and self.router.conversation_exists(cached):
                    conv_id = cached

            if ws_dir is None:
                with self._get_lock(f"repo:{trigger.repo_full.lower()}"):
                    ws_dir = self.router.resolve_workspace(
                        repo_full=trigger.repo_full,
                        ssh_url=trigger.ssh_url,
                        clone_url=trigger.clone_url,
                    )

            prompt = build_prompt(
                trigger,
                self._bot_login,
                workspace_dir=ws_dir,
                existing_conversation=bool(conv_id),
            )
            conv_title = (
                f"Gitea {trigger.repo_full}#{trigger.index}: {trigger.title}"
                if trigger.index
                else f"Gitea {trigger.repo_full}: {trigger.title}"
            )[:120]
            action = (
                f"send-message conversation={conv_id}"
                if conv_id
                else "new-conversation"
            )
            if self.cfg.dry_run:
                LOG.info(
                    "[DRY RUN] Would dispatch %s (%s) via %s in %s",
                    trigger.thread_key,
                    ", ".join(trigger.reasons),
                    action,
                    ws_dir,
                )
                return

            LOG.info(
                "Dispatching %s (%s) via %s in %s",
                trigger.thread_key,
                ", ".join(trigger.reasons),
                action,
                ws_dir,
            )
            new_conv_id = run_agentapi(
                self.cfg,
                conversation_id=conv_id,
                workspace_dir=ws_dir,
                prompt=prompt,
                title=conv_title,
            )

            if new_conv_id and trigger.index:
                self.state.set_conversation(trigger.thread_key, new_conv_id)
            if trigger.commit_comment_id:
                self.state.add_commit_comment(trigger.commit_comment_id)
            if trigger.next_thread_state:
                self.state.set_thread_state(
                    trigger.thread_key, trigger.next_thread_state
                )
            # Only mark the notification thread read if nothing new arrived while dispatching.
            if trigger.thread_id is not None:
                expected_updated_at = trigger.next_thread_state.get("last_updated_at")
                should_mark_read = True
                if expected_updated_at:
                    try:
                        latest = self.client.get_notification_thread(trigger.thread_id)
                        if latest and latest.get("updated_at") != expected_updated_at:
                            should_mark_read = False
                            LOG.info(
                                "Thread %s updated during dispatch (%s -> %s); keeping unread",
                                trigger.thread_key,
                                expected_updated_at,
                                latest.get("updated_at"),
                            )
                    except Exception as err:  # noqa: BLE001
                        LOG.debug(
                            "Could not re-check thread %s before marking read: %s",
                            trigger.thread_id,
                            err,
                        )
                if should_mark_read:
                    self.client.mark_thread_read(trigger.thread_id)
            LOG.info(
                "Completed %s -> conversation %s",
                trigger.thread_key,
                new_conv_id or conv_id,
            )

    def _on_future_done(self, thread_key: str, future: Future[Any]) -> None:
        with self._lock_guard:
            self._in_flight.discard(thread_key)
            self._futures.discard(future)
        exc = future.exception()
        if exc is not None:
            delay = self.state.record_failure(thread_key)
            LOG.error(
                "Failed processing %s (retry in %.0fs): %s", thread_key, delay, exc
            )

    @staticmethod
    def _issue_to_synthetic_thread(
        item: dict[str, Any], *, seed_only: bool = False
    ) -> dict[str, Any] | None:
        repo_info = item.get("repository") or {}
        repo_full = repo_info.get("full_name", "")
        number = item.get("number")
        if not repo_full or not number:
            return None
        is_pr = bool(item.get("pull_request"))
        kind = "pulls" if is_pr else "issues"
        return {
            "id": None,
            "updated_at": item.get("updated_at", ""),
            "repository": repo_info,
            "subject": {
                "type": "Pull" if is_pr else "Issue",
                "title": item.get("title", ""),
                "url": item.get("url") or f"{repo_full}/api/{kind}/{number}",
                "html_url": item.get("html_url") or "",
            },
            "_seed_only": seed_only,
        }

    def _collect_candidate_threads(self) -> tuple[list[dict[str, Any]], str]:
        now = datetime.now(timezone.utc)
        overlap_seconds = max(60, self.cfg.poll_interval * 2)
        next_cursor = (now - timedelta(seconds=overlap_seconds)).strftime(
            "%Y-%m-%dT%H:%M:%SZ"
        )
        search_cursor = self.state.get_search_cursor()
        cold_cutoff = (now - timedelta(hours=1)).strftime("%Y-%m-%dT%H:%M:%SZ")

        by_key: dict[str, dict[str, Any]] = {}
        extra_threads: list[dict[str, Any]] = []
        for thread in self.client.list_unread_notifications():
            repo_full = (thread.get("repository") or {}).get("full_name", "")
            subject = thread.get("subject") or {}
            idx = extract_index_from_url(
                subject.get("url", "")
            ) or extract_index_from_url(subject.get("html_url", ""))
            if (
                repo_full
                and idx is not None
                and subject.get("type") in {"Issue", "Pull"}
            ):
                by_key[f"{repo_full}#{idx}"] = thread
            else:
                extra_threads.append(thread)

        # Gitea/Forgejo does not generate /notifications entries for type=Bot accounts,
        # so also poll /repos/issues/search for mentions, assignments, and PR replies.
        search_queries = [
            {"state": "all", "mentioned": True},
            {"state": "open", "assigned": True},
            {"state": "open", "review_requested": True},
            {"state": "open", "created": True},
            {"state": "open", "reviewed": True},
        ]
        for query in search_queries:
            try:
                items = self.client.search_issues(since=search_cursor, **query)
            except Exception as err:  # noqa: BLE001
                LOG.warning("Issue search (%s) failed: %s", query, err)
                continue
            for item in items:
                repo_full = (item.get("repository") or {}).get("full_name", "")
                number = item.get("number")
                if not repo_full or not number:
                    continue
                key = f"{repo_full}#{number}"
                if key in by_key:
                    continue
                updated_at = item.get("updated_at") or ""
                prev = self.state.get_thread_state(key)
                if prev is not None and prev.get("last_updated_at") == updated_at:
                    continue
                seed_only = (
                    search_cursor is None
                    and bool(updated_at)
                    and updated_at < cold_cutoff
                )
                synthetic = self._issue_to_synthetic_thread(item, seed_only=seed_only)
                if synthetic is not None:
                    by_key[key] = synthetic

        # Re-check any previously failed issue/PR keys whose retry backoff expired.
        for key in self.state.get_ready_retry_keys():
            if key in by_key or "#" not in key:
                continue
            repo_full, idx_str = key.rsplit("#", 1)
            if "/" not in repo_full or not idx_str.isdigit():
                continue
            owner, repo_name = repo_full.split("/", 1)
            try:
                item = self.client.get_issue(owner, repo_name, int(idx_str))
            except Exception as err:  # noqa: BLE001
                LOG.warning("Failed re-fetching retry item %s: %s", key, err)
                continue
            if isinstance(item, dict):
                item.setdefault("repository", {"full_name": repo_full})
                synthetic = self._issue_to_synthetic_thread(item, seed_only=False)
                if synthetic is not None:
                    by_key[key] = synthetic

        return list(by_key.values()) + extra_threads, next_cursor

    def poll_once(self, executor: ThreadPoolExecutor | None = None) -> int:
        """Poll unread notifications and issue/PR search once and dispatch triggers."""
        bot_login = self._ensure_bot_login()
        threads, next_cursor = self._collect_candidate_threads()
        dispatched = 0
        for thread in threads:
            if self.stop_event.is_set():
                break
            seed_only = bool(thread.get("_seed_only", False))
            try:
                trigger, ignored_state = evaluate_thread(
                    self.client,
                    self.state,
                    thread,
                    bot_login,
                    allowed_users=self.cfg.allowed_users,
                )
            except Exception as err:  # noqa: BLE001
                LOG.warning(
                    "Error inspecting notification thread %s: %s", thread.get("id"), err
                )
                continue

            if trigger is None or seed_only:
                if not self.cfg.dry_run:
                    state_to_save = (
                        trigger.next_thread_state
                        if trigger is not None
                        else ignored_state
                    )
                    if state_to_save is not None:
                        repo_full = (thread.get("repository") or {}).get(
                            "full_name", ""
                        )
                        idx = extract_index_from_url(
                            (thread.get("subject") or {}).get("url", "")
                        )
                        if repo_full and idx is not None:
                            self.state.set_thread_state(
                                f"{repo_full}#{idx}", state_to_save
                            )
                    if thread.get("id") is not None:
                        try:
                            self.client.mark_thread_read(str(thread["id"]))
                        except Exception as err:  # noqa: BLE001
                            LOG.warning(
                                "Failed marking thread %s read: %s",
                                thread.get("id"),
                                err,
                            )
                continue

            if self.state.should_skip_retry(trigger.thread_key):
                continue

            with self._lock_guard:
                if trigger.thread_key in self._in_flight:
                    continue
                self._in_flight.add(trigger.thread_key)

            dispatched += 1
            if executor is None:
                try:
                    self._handle_trigger(trigger)
                except Exception as err:  # noqa: BLE001
                    delay = self.state.record_failure(trigger.thread_key)
                    LOG.error(
                        "Failed processing %s (retry in %.0fs): %s",
                        trigger.thread_key,
                        delay,
                        err,
                    )
                finally:
                    with self._lock_guard:
                        self._in_flight.discard(trigger.thread_key)
            else:
                fut = executor.submit(self._handle_trigger, trigger)
                with self._lock_guard:
                    self._futures.add(fut)
                fut.add_done_callback(
                    lambda f, key=trigger.thread_key: self._on_future_done(key, f)
                )
        if not self.cfg.dry_run:
            self.state.set_search_cursor(next_cursor)
        return dispatched

    def run_forever(self) -> int:
        LOG.info(
            "Starting Gitea sidecar (app_data=%s, state=%s)",
            self.cfg.app_data_dir,
            self.cfg.state_file,
        )
        missing_token_logged = False
        error_streak = 0
        with ThreadPoolExecutor(
            max_workers=self.cfg.max_concurrency, thread_name_prefix="gitea-worker"
        ) as executor:
            while not self.stop_event.is_set():
                if not self.cfg.token_file.is_file():
                    if not missing_token_logged:
                        LOG.info(
                            "Waiting for Gitea token file at %s...", self.cfg.token_file
                        )
                        missing_token_logged = True
                    self.stop_event.wait(30)
                    continue
                missing_token_logged = False
                try:
                    self.poll_once(executor=executor)
                    error_streak = 0
                    self.stop_event.wait(self.cfg.poll_interval)
                except Exception as err:  # noqa: BLE001
                    error_streak += 1
                    wait_s = min(
                        MAX_BACKOFF_SECONDS,
                        self.cfg.poll_interval * (2 ** min(error_streak, 5)),
                    )
                    LOG.warning("Poll cycle error (retrying in %ds): %s", wait_s, err)
                    self.stop_event.wait(wait_s)

            with self._lock_guard:
                pending = list(self._futures)
            for fut in pending:
                fut.result()
        self.client.close()
        return 0


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Antigravity Remote Gitea notifications sidecar"
    )
    parser.add_argument("--once", action="store_true", help="Poll once and exit")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Log actions without invoking agentapi or marking read",
    )
    parser.add_argument("--verbose", action="store_true", help="Enable debug logging")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    cfg = Config.from_env(dry_run=args.dry_run)
    daemon = SidecarDaemon(cfg)

    def _stop_handler(signum: int, _frame: Any) -> None:
        LOG.info("Received signal %d; shutting down...", signum)
        daemon.stop_event.set()

    signal.signal(signal.SIGTERM, _stop_handler)
    signal.signal(signal.SIGINT, _stop_handler)

    if args.once:
        if not cfg.token_file.is_file():
            LOG.info(
                "Gitea token file not found at %s; nothing to poll.", cfg.token_file
            )
            return 0
        daemon.poll_once(executor=None)
        return 0

    return daemon.run_forever()


if __name__ == "__main__":
    sys.exit(main())
