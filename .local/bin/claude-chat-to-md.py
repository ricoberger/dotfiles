#!/usr/bin/env python3

# Source: https://github.com/luckynick/claude-chat-to-md

"""Convert Claude Code chat sessions (.jsonl) to Markdown.

Reads session JSONL files from ~/.claude/projects/ and produces clean,
readable Markdown — including subagent conversations.

Usage:
    # List all sessions
    claude-chat-to-md --list

    # Convert a specific session (by UUID or partial match)
    claude-chat-to-md 2354ca15

    # Convert the most recent session for a project
    claude-chat-to-md --latest --project myapp

    # Convert all sessions
    claude-chat-to-md --all

    # Output to a specific file
    claude-chat-to-md 2354ca15 -o chat.md
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import TextIO


CLAUDE_DIR = Path.home() / ".claude"
PROJECTS_DIR = CLAUDE_DIR / "projects"


@dataclass
class SessionInfo:
    """Metadata about a discovered session."""

    path: Path
    session_id: str
    project_path: str
    title: str | None = None
    timestamp: str | None = None
    subagent_dir: Path | None = None

    @property
    def display_project(self) -> str:
        """Human-readable project path.

        Claude Code encodes project paths by replacing '/' with '-',
        e.g. '/Users/nick/my-project' becomes '-Users-nick-my-project'.
        We reverse this by splitting on the known leading pattern and
        reconstructing path separators only where they originally were.
        """
        # The encoded path starts with '-' (representing the leading '/')
        # and uses '-' for every '/' in the original path. However, actual
        # directory names may contain hyphens too. We can't perfectly reverse
        # this, but we can use os.sep knowledge: the original path segments
        # are valid directory names. We try to find the longest valid prefix.
        raw = self.project_path
        if not raw:
            return raw

        # Try to find the actual path on disk by checking ~/.claude/projects/
        # Fall back to a heuristic: replace leading '-' with '/' and try to
        # reconstruct by checking which splits produce real-looking paths.
        # Best heuristic: the encoded form is the absolute path with '/' -> '-'
        # and a leading '-'. Try to resolve by checking if the path exists.
        candidate = "/" + raw[1:] if raw.startswith("-") else raw
        # Replace hyphens with '/' and check if it's a real path
        full_replace = candidate.replace("-", "/")
        if Path(full_replace).exists():
            return full_replace.lstrip("/")

        # Fallback: use a smarter reconstruction. Split by '-' and greedily
        # rejoin segments that form existing directories.
        parts = raw.lstrip("-").split("-")
        reconstructed = [parts[0]]
        for part in parts[1:]:
            # Try joining with the previous segment (hyphenated name)
            test_hyphen = "/" + "/".join(
                reconstructed[:-1] + [reconstructed[-1] + "-" + part]
            )
            test_slash = "/" + "/".join(reconstructed + [part])
            if Path(test_hyphen).exists():
                reconstructed[-1] += "-" + part
            else:
                reconstructed.append(part)

        return "/".join(reconstructed)


def discover_sessions() -> list[SessionInfo]:
    """Find all session JSONL files under ~/.claude/projects/."""
    sessions: list[SessionInfo] = []
    if not PROJECTS_DIR.exists():
        return sessions

    for project_dir in PROJECTS_DIR.iterdir():
        if not project_dir.is_dir():
            continue
        for jsonl_file in project_dir.glob("*.jsonl"):
            sid = jsonl_file.stem
            # Skip subagent files
            if sid.startswith("agent-"):
                continue

            info = SessionInfo(
                path=jsonl_file,
                session_id=sid,
                project_path=project_dir.name,
            )

            # Check for subagent directory
            subagent_dir = project_dir / sid / "subagents"
            if subagent_dir.is_dir():
                info.subagent_dir = subagent_dir

            # Quick scan for title and first timestamp
            try:
                with open(jsonl_file) as f:
                    for line in f:
                        obj = json.loads(line)
                        if obj.get("type") == "ai-title":
                            info.title = obj.get("aiTitle")
                        if not info.timestamp and obj.get("timestamp"):
                            info.timestamp = obj["timestamp"]
                        if info.title and info.timestamp:
                            break
            except (json.JSONDecodeError, OSError):
                pass

            sessions.append(info)

    sessions.sort(key=lambda s: s.timestamp or "", reverse=True)
    return sessions


def parse_messages(jsonl_path: Path) -> list[dict]:
    """Parse a JSONL file into an ordered list of message records."""
    messages = []
    with open(jsonl_path) as f:
        for line in f:
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            if obj.get("type") in ("user", "assistant"):
                messages.append(obj)
    return messages


def format_tool_use(content_block: dict) -> str:
    """Format a tool_use content block as Markdown."""
    name = content_block.get("name", "Unknown")
    inp = content_block.get("input", {})

    lines = [f"**Tool: {name}**"]

    if name == "Bash":
        cmd = inp.get("command", "")
        desc = inp.get("description", "")
        if desc:
            lines.append(f"*{desc}*")
        lines.append(f"```bash\n{cmd}\n```")
    elif name == "Read":
        fp = inp.get("file_path", "")
        lines.append(f"Reading `{fp}`")
    elif name == "Write":
        fp = inp.get("file_path", "")
        content = inp.get("content", "")
        lines.append(f"Writing `{fp}`")
        if content:
            # Show first/last lines for long files
            content_lines = content.split("\n")
            if len(content_lines) > 30:
                preview = "\n".join(content_lines[:15])
                preview += f"\n\n... ({len(content_lines) - 30} lines omitted) ...\n\n"
                preview += "\n".join(content_lines[-15:])
            else:
                preview = content
            ext = Path(fp).suffix.lstrip(".")
            lines.append(f"```{ext}\n{preview}\n```")
    elif name == "Edit":
        fp = inp.get("file_path", "")
        old = inp.get("old_string", "")
        new = inp.get("new_string", "")
        lines.append(f"Editing `{fp}`")
        if old or new:
            lines.append("```diff")
            for ol in old.split("\n"):
                lines.append(f"- {ol}")
            for nl in new.split("\n"):
                lines.append(f"+ {nl}")
            lines.append("```")
    elif name == "Grep":
        pattern = inp.get("pattern", "")
        path = inp.get("path", ".")
        lines.append(f"Searching for `{pattern}` in `{path}`")
    elif name == "Glob":
        pattern = inp.get("pattern", "")
        lines.append(f"Finding files matching `{pattern}`")
    elif name == "Agent":
        desc = inp.get("description", "")
        subtype = inp.get("subagent_type", "general-purpose")
        lines.append(f"Spawning **{subtype}** agent: *{desc}*")
        prompt = inp.get("prompt", "")
        if prompt:
            # Truncate long prompts
            if len(prompt) > 500:
                prompt = prompt[:500] + "..."
            lines.append(f"\n> {prompt}")
    elif name in ("WebSearch", "WebFetch"):
        query = inp.get("query", inp.get("url", ""))
        lines.append(f"`{query}`")
    else:
        # Generic: show input as JSON
        if inp:
            lines.append(f"```json\n{json.dumps(inp, indent=2)[:500]}\n```")

    return "\n".join(lines)


def format_tool_result(content_block: dict) -> str:
    """Format a tool_result content block as Markdown."""
    content = content_block.get("content", "")
    is_error = content_block.get("is_error", False)

    if isinstance(content, list):
        # Content can be a list of text/image blocks
        parts = []
        for item in content:
            if isinstance(item, dict) and item.get("type") == "text":
                parts.append(item["text"])
            elif isinstance(item, dict) and item.get("type") == "image":
                parts.append("*[image]*")
            else:
                parts.append(str(item))
        content = "\n".join(parts)

    if not content:
        return ""

    prefix = "**Error:**\n" if is_error else ""
    # Truncate very long results
    lines = content.split("\n")
    if len(lines) > 50:
        content = "\n".join(lines[:25])
        content += f"\n\n... ({len(lines) - 50} lines omitted) ...\n\n"
        content += "\n".join(lines[-25:])

    return f"{prefix}```\n{content}\n```"


def format_content(content: list | str) -> str:
    """Format a message's content array into Markdown."""
    if isinstance(content, str):
        return content

    parts = []
    for block in content:
        if isinstance(block, str):
            parts.append(block)
        elif not isinstance(block, dict):
            continue
        elif block.get("type") == "text":
            text = block["text"]
            # Strip IDE system tags for cleaner output
            text = re.sub(
                r"<ide_opened_file>.*?</ide_opened_file>", "", text, flags=re.DOTALL
            )
            text = re.sub(
                r"<system-reminder>.*?</system-reminder>", "", text, flags=re.DOTALL
            )
            text = text.strip()
            if text:
                parts.append(text)
        elif block.get("type") == "tool_use":
            parts.append(format_tool_use(block))
        elif block.get("type") == "tool_result":
            parts.append(format_tool_result(block))

    return "\n\n".join(parts)


def convert_subagent(jsonl_path: Path, meta_path: Path | None) -> str:
    """Convert a subagent session into a Markdown section."""
    meta = {}
    if meta_path and meta_path.exists():
        try:
            meta = json.loads(meta_path.read_text())
        except (json.JSONDecodeError, OSError):
            pass

    agent_type = meta.get("agentType", "unknown")
    description = meta.get("description", "Subagent")

    messages = parse_messages(jsonl_path)
    lines = [f"#### Subagent: {description}", f"*Type: {agent_type}*\n"]

    for msg in messages:
        role = msg.get("type", msg.get("message", {}).get("role", "unknown"))
        content = msg.get("message", {}).get("content", [])
        formatted = format_content(content)
        if not formatted:
            continue

        if role == "user":
            lines.append(f"**Prompt:**\n\n{formatted}\n")
        elif role == "assistant":
            lines.append(f"{formatted}\n")

    return "\n".join(lines)


def convert_session(
    session: SessionInfo,
    include_subagents: bool = True,
    include_tool_results: bool = True,
) -> str:
    """Convert a full session to Markdown."""
    messages = parse_messages(session.path)

    # Collect subagent data if available
    subagents: dict[str, str] = {}  # tool_use_id -> markdown
    if include_subagents and session.subagent_dir:
        for meta_file in session.subagent_dir.glob("*.meta.json"):
            agent_id = meta_file.stem.replace(".meta", "")
            jsonl_file = session.subagent_dir / f"{agent_id}.jsonl"
            if jsonl_file.exists():
                subagents[agent_id] = convert_subagent(jsonl_file, meta_file)

    # Build output
    lines = []

    # Header
    title = session.title or "Untitled Session"
    ts = session.timestamp or ""
    if ts:
        try:
            dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
            ts = dt.strftime("%Y-%m-%d %H:%M UTC")
        except ValueError:
            pass

    lines.append(f"# {title}")
    lines.append("")
    lines.append(f"**Session:** `{session.session_id}`  ")
    lines.append(f"**Project:** `{session.display_project}`  ")
    if ts:
        lines.append(f"**Date:** {ts}  ")
    lines.append("")
    lines.append("---")
    lines.append("")

    # Track which agent tool_use_ids map to which subagent
    agent_tool_use_map: dict[str, str] = {}

    for msg in messages:
        role = msg.get("type", "")
        content = msg.get("message", {}).get("content", [])

        if role == "user":
            # Check if this is a tool_result (not direct user input)
            if isinstance(content, list) and all(
                isinstance(b, dict) and b.get("type") == "tool_result" for b in content
            ):
                if include_tool_results:
                    formatted = format_content(content)
                    if formatted.strip():
                        lines.append(
                            f"<details><summary>Tool Result</summary>\n\n{formatted}\n\n</details>\n"
                        )
                continue

            formatted = format_content(content)
            if formatted.strip():
                lines.append(f"## User\n\n{formatted}\n")

        elif role == "assistant":
            formatted_parts = []
            if isinstance(content, list):
                for block in content:
                    if isinstance(block, dict) and block.get("type") == "tool_use":
                        if block.get("name") == "Agent":
                            # Map this tool_use to subagent output
                            desc = block.get("input", {}).get("description", "")
                            # Find matching subagent by description
                            for aid, md in subagents.items():
                                if desc and desc in md:
                                    agent_tool_use_map[block["id"]] = aid

                        formatted_parts.append(format_tool_use(block))
                    elif isinstance(block, dict) and block.get("type") == "text":
                        import re

                        text = block["text"]
                        text = re.sub(
                            r"<ide_opened_file>.*?</ide_opened_file>",
                            "",
                            text,
                            flags=re.DOTALL,
                        )
                        text = re.sub(
                            r"<system-reminder>.*?</system-reminder>",
                            "",
                            text,
                            flags=re.DOTALL,
                        )
                        text = text.strip()
                        if text:
                            formatted_parts.append(text)
                    elif isinstance(block, dict) and block.get("type") == "tool_result":
                        if include_tool_results:
                            r = format_tool_result(block)
                            if r:
                                formatted_parts.append(r)

            formatted = "\n\n".join(formatted_parts)
            if formatted.strip():
                lines.append(f"## Assistant\n\n{formatted}\n")

            # Insert subagent conversations after the assistant message that spawned them
            if isinstance(content, list):
                for block in content:
                    if (
                        isinstance(block, dict)
                        and block.get("type") == "tool_use"
                        and block.get("name") == "Agent"
                    ):
                        tid = block.get("id", "")
                        if tid in agent_tool_use_map:
                            aid = agent_tool_use_map[tid]
                            lines.append(
                                f"<details><summary>Subagent Conversation</summary>\n"
                            )
                            lines.append(subagents[aid])
                            lines.append("</details>\n")
                        else:
                            # Try to find by description match
                            desc = block.get("input", {}).get("description", "")
                            for aid, md in subagents.items():
                                if (
                                    desc
                                    and desc.lower() in md.lower()
                                    and aid not in agent_tool_use_map.values()
                                ):
                                    lines.append(
                                        f"<details><summary>Subagent Conversation</summary>\n"
                                    )
                                    lines.append(md)
                                    lines.append("</details>\n")
                                    agent_tool_use_map[tid] = aid
                                    break

    return "\n".join(lines)


def list_sessions(sessions: list[SessionInfo], out: TextIO = sys.stdout) -> None:
    """Print a table of discovered sessions."""
    if not sessions:
        print("No sessions found.", file=out)
        return

    print(f"{'#':<4} {'Date':<20} {'ID':<12} {'Title':<50} {'Project'}", file=out)
    print("-" * 120, file=out)
    for i, s in enumerate(sessions, 1):
        ts = ""
        if s.timestamp:
            try:
                dt = datetime.fromisoformat(s.timestamp.replace("Z", "+00:00"))
                ts = dt.strftime("%Y-%m-%d %H:%M")
            except ValueError:
                ts = s.timestamp[:16]
        title = (s.title or "Untitled")[:50]
        sid = s.session_id[:10] + ".."
        proj = s.display_project
        # Shorten project path
        parts = proj.split("/")
        if len(parts) > 3:
            proj = "/".join(parts[-3:])
        print(f"{i:<4} {ts:<20} {sid:<12} {title:<50} {proj}", file=out)


def find_session(sessions: list[SessionInfo], query: str) -> SessionInfo | None:
    """Find a session by UUID prefix or index."""
    # Try as index
    try:
        idx = int(query) - 1
        if 0 <= idx < len(sessions):
            return sessions[idx]
    except ValueError:
        pass

    # Try as UUID prefix
    for s in sessions:
        if s.session_id.startswith(query):
            return s

    # Try title substring
    for s in sessions:
        if s.title and query.lower() in s.title.lower():
            return s

    return None


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Convert Claude Code chat sessions to Markdown",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "session",
        nargs="?",
        help="Session UUID (prefix), index number from --list, or title substring",
    )
    parser.add_argument("--list", "-l", action="store_true", help="List all sessions")
    parser.add_argument(
        "--latest", action="store_true", help="Convert the most recent session"
    )
    parser.add_argument("--all", action="store_true", help="Convert all sessions")
    parser.add_argument("--project", "-p", help="Filter by project path substring")
    parser.add_argument("--output", "-o", help="Output file path (default: stdout)")
    parser.add_argument(
        "--no-subagents", action="store_true", help="Exclude subagent conversations"
    )
    parser.add_argument(
        "--no-tool-results", action="store_true", help="Exclude tool results"
    )
    parser.add_argument("--output-dir", "-d", help="Output directory (for --all mode)")

    args = parser.parse_args()
    sessions = discover_sessions()

    if args.project:
        sessions = [
            s for s in sessions if args.project.lower() in s.project_path.lower()
        ]

    if args.list:
        list_sessions(sessions)
        return

    if not args.session and not args.latest and not args.all:
        parser.print_help()
        print("\nUse --list to see available sessions.", file=sys.stderr)
        sys.exit(1)

    include_subagents = not args.no_subagents
    include_tool_results = not args.no_tool_results

    if args.all:
        out_dir = Path(args.output_dir) if args.output_dir else Path(".")
        out_dir.mkdir(parents=True, exist_ok=True)
        for s in sessions:
            md = convert_session(s, include_subagents, include_tool_results)
            ts = ""
            if s.timestamp:
                try:
                    dt = datetime.fromisoformat(s.timestamp.replace("Z", "+00:00"))
                    ts = dt.strftime("%Y-%m-%d")
                except ValueError:
                    pass
            safe_title = (
                (s.title or "untitled").replace(" ", "-").replace("/", "-")[:50]
            )
            filename = (
                f"{ts}-{safe_title}.md" if ts else f"{s.session_id[:8]}-{safe_title}.md"
            )
            out_path = out_dir / filename
            out_path.write_text(md)
            print(f"Wrote {out_path}", file=sys.stderr)
        return

    if args.latest:
        if not sessions:
            print("No sessions found.", file=sys.stderr)
            sys.exit(1)
        session = sessions[0]
    else:
        session = find_session(sessions, args.session)
        if not session:
            print(f"Session not found: {args.session}", file=sys.stderr)
            print("Use --list to see available sessions.", file=sys.stderr)
            sys.exit(1)

    md = convert_session(session, include_subagents, include_tool_results)

    if args.output:
        Path(args.output).write_text(md)
        print(f"Wrote {args.output}", file=sys.stderr)
    else:
        print(md)


if __name__ == "__main__":
    main()
