#!/usr/bin/env bash
set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$TOOL_DIR/.." && pwd)"
CONFIG_ROOT="$TOOL_DIR/configs"
BIN_DIR="$TOOL_DIR/bin"
REMOTE_NAME="${1:-remote1}"
REMOTE_DIR="$CONFIG_ROOT/$REMOTE_NAME"
SSH_CONFIG_FILE="$REMOTE_DIR/ssh_config"
CONFIG_FILE="$REMOTE_DIR/config.toml"

mkdir -p "$REMOTE_DIR" "$BIN_DIR" "$PROJECT_DIR/workspaces"

echo "[tool4remote setup]"
echo "project: $PROJECT_DIR"
echo "remote config: $REMOTE_DIR"

if [[ ! -s "$SSH_CONFIG_FILE" ]]; then
  cat > "$SSH_CONFIG_FILE" <<EOF
Host ${REMOTE_NAME}-host
    HostName YOUR_SERVER_HOST_OR_IP
    User SHARED_REMOTE_USER
    Port 22
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 60
    ServerAliveCountMax 5
    IdentitiesOnly yes
EOF
  echo "created SSH template: $SSH_CONFIG_FILE"
else
  echo "kept existing SSH config: $SSH_CONFIG_FILE"
fi

if [[ ! -s "$CONFIG_FILE" ]]; then
  cat > "$CONFIG_FILE" <<EOF
[defaults]
workspace = "default"

[remotes.$REMOTE_NAME]
host = "${REMOTE_NAME}-host"
ssh_config = "ssh_config"
ssh_options = []

[workspaces.default]
remote = "$REMOTE_NAME"
local_dir = "workspaces/default"
remote_dir = "/data/workspaces/YOUR_NAME/my_project"
rsync_flags = ["-az", "--info=progress2"]
excludes = [
  ".git/",
  ".venv/",
  "__pycache__/",
  "*.pyc",
  "outputs/",
  "output/",
  "logs/",
  "checkpoints/",
  "wandb/",
  "runs/",
  "tmp/",
]
status_commands = []
EOF
  echo "created config template: $CONFIG_FILE"
else
  echo "kept existing tool config: $CONFIG_FILE"
fi

write_wrapper() {
  local wrapper_name="$1"
  local remote_name="$2"
  cat > "$BIN_DIR/$wrapper_name" <<EOF
#!/usr/bin/env bash
args=()
if [[ "\${1:-}" == "--dry-run" ]]; then
  args+=("--dry-run")
  shift
fi
if [[ -n "\${TOOL4REMOTE_CONFIG:-}" ]]; then
  args+=("-c" "\$TOOL4REMOTE_CONFIG")
fi

case "\${1:-}" in
  list|init|pull|push|run|status|tail|gpu|tmux)
    exec "$TOOL_DIR/tool4remote" "\${args[@]}" "\$@"
    ;;
  "")
    exec "$TOOL_DIR/tool4remote" "\${args[@]}" "$remote_name"
    ;;
  *)
    exec "$TOOL_DIR/tool4remote" "\${args[@]}" "$remote_name" "\$@"
    ;;
esac
EOF
  chmod +x "$BIN_DIR/$wrapper_name"
  echo "created wrapper: $BIN_DIR/$wrapper_name -> $remote_name"
}

remotes_file="$(mktemp)"
trap 'rm -f "$remotes_file"' EXIT
"$TOOL_DIR/tool4remote" list >"$remotes_file"
mapfile -t remotes < <(awk '/^  remote[0-9]+:/{gsub(":", "", $1); print $1}' "$remotes_file")
for remote in "${remotes[@]}"; do
  write_wrapper "$remote" "$remote"
done
if [[ "${#remotes[@]}" -eq 1 ]]; then
  write_wrapper "remote" "${remotes[0]}"
fi

"$TOOL_DIR/tool4remote" init >/dev/null

echo
echo "Next steps:"
echo "1. Edit $SSH_CONFIG_FILE"
echo "2. Edit $CONFIG_FILE"
echo "3. Add wrappers to PATH for this shell:"
echo "   export PATH=\"$BIN_DIR:\$PATH\""
echo "4. Test:"
echo "   tool/tool4remote list"
echo "   $REMOTE_NAME pwd"
echo "   remote status -w default   # if only one remote is configured"
