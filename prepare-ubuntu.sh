#!/usr/bin/env bash
# Prepare an Ubuntu host with Caddy, automatic security updates, and basic
# SSH/kernel hardening. Site configuration, DNS, and provider firewalls are
# left to the operator.

set -Eeuo pipefail

SCRIPT_NAME=$(basename "$0")
RUN_OS_UPGRADE=1
HARDEN_SSH=1
HARDEN_KERNEL=1
ENABLE_UFW=0
CREATE_USER=0
ADMIN_USER=${SUDO_USER:-root}
ADMIN_KEY_FILE=
SSH_PORT=
TMP_DIR=
SSH_HARDENING_FILE=/etc/ssh/sshd_config.d/00-prepare-ubuntu-hardening.conf

log() { printf '\n==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}
on_error() {
  local exit_code=$?
  printf 'ERROR: %s failed at line %s (exit code %s).\n' \
    "$SCRIPT_NAME" "${BASH_LINENO[0]:-unknown}" "$exit_code" >&2
  exit "$exit_code"
}
trap on_error ERR
trap '[[ -z $TMP_DIR ]] || rm -rf -- "$TMP_DIR"' EXIT

usage() {
  cat << USAGE
Usage: sudo ./$SCRIPT_NAME [options]

  --admin-user USER        Non-root SSH administrator (default: sudo user).
  --create-user            Create that user if absent and set its sudo password
                           interactively.
  --admin-key FILE         Public key file for a new user, without authorized_keys
                           options. Required when creating a user with SSH hardening.
  --skip-upgrade           Skip the initial Ubuntu package upgrade.
  --skip-ssh-hardening     Leave OpenSSH authentication settings alone.
  --skip-kernel-hardening  Do not install the sysctl profile.
  --enable-ufw             Enable UFW for SSH, HTTP, and HTTPS. Review other
                           required inbound ports before using this option.
  --ssh-port PORT          Actual local SSH TCP port; required with --enable-ufw.
  -h, --help               Show this help.

Examples:
  sudo ./$SCRIPT_NAME --admin-user operator --create-user --admin-key ./operator.pub
  sudo ./$SCRIPT_NAME --admin-user operator --enable-ufw --ssh-port 22
USAGE
}

while (($#)); do
  case "$1" in
    --admin-user)
      (($# >= 2)) || die "--admin-user requires a value"
      ADMIN_USER=$2
      shift 2
      ;;
    --create-user)
      CREATE_USER=1
      shift
      ;;
    --admin-key)
      (($# >= 2)) || die "--admin-key requires a value"
      ADMIN_KEY_FILE=$2
      shift 2
      ;;
    --skip-upgrade)
      RUN_OS_UPGRADE=0
      shift
      ;;
    --skip-ssh-hardening)
      HARDEN_SSH=0
      shift
      ;;
    --skip-kernel-hardening)
      HARDEN_KERNEL=0
      shift
      ;;
    --enable-ufw)
      ENABLE_UFW=1
      shift
      ;;
    --ssh-port)
      (($# >= 2)) || die "--ssh-port requires a value"
      SSH_PORT=$2
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die "Unknown option: $1 (use --help)" ;;
  esac
done

# Only accept explicitly supplied, bare public keys for a newly created admin.
# In particular, never copy or strip cloud-init's root-only forced commands.
admin_key_file_is_usable() {
  local line key_type key_data comment found=0
  [[ -f $1 && -s $1 ]] || return 1
  while IFS= read -r line || [[ -n $line ]]; do
    [[ $line =~ ^[[:space:]]*(#|$) ]] && continue
    read -r key_type key_data comment <<< "$line"
    case "$key_type" in
      ssh-ed25519 | ssh-rsa | ecdsa-sha2-nistp256 | ecdsa-sha2-nistp384 | ecdsa-sha2-nistp521 | sk-ssh-ed25519@openssh.com | sk-ecdsa-sha2-nistp256@openssh.com) ;;
      *) return 1 ;;
    esac
    ssh-keygen -lf /dev/stdin <<< "$line" > /dev/null 2>&1 || return 1
    found=1
  done < "$1"
  ((found))
}

# An early unconditional Match pins the auth policy for all connection contexts.
# Prove its ordering rather than attempting to enumerate existing Match rules.
ssh_hardening_has_precedence() (
  export LC_ALL=C
  local main_config=$1 dropin_dir=$2 managed_file=$3
  local first directive include trailing file
  first=$(awk '!/^[[:space:]]*(#|$)/ { print; exit }' "$main_config") || return 1
  read -r directive include trailing <<< "$first"
  [[ ${directive,,} == include && $include == "$dropin_dir/*.conf" &&
    (-z $trailing || $trailing == \#*) ]] || return 1
  [[ ! -L $managed_file && (! -e $managed_file || -f $managed_file) ]] || return 1
  shopt -s nullglob
  for file in "$dropin_dir"/*.conf; do
    [[ $file < $managed_file ]] && return 1
  done
  return 0
)

[[ $EUID -eq 0 ]] || die "Run this script as root, normally with sudo."
[[ $ADMIN_USER =~ ^[a-z_][a-z0-9_-]*$ ]] || die "Invalid Linux username: $ADMIN_USER"
if ((HARDEN_SSH)); then
  [[ $ADMIN_USER != root ]] ||
    die "SSH hardening requires a non-root --admin-user, or --skip-ssh-hardening."
fi
if ((CREATE_USER)); then
  [[ $ADMIN_USER != root ]] || die "--create-user requires a non-root --admin-user."
fi
if ((ENABLE_UFW)); then
  [[ $SSH_PORT =~ ^[0-9]{1,5}$ ]] &&
    ((10#$SSH_PORT >= 1 && 10#$SSH_PORT <= 65535)) ||
    die "--enable-ufw requires --ssh-port with the actual local SSH port (1-65535)."
elif [[ -n $SSH_PORT ]]; then
  die "--ssh-port is only used with --enable-ufw."
fi

log "Validating Ubuntu and the administrator"
[[ -r /etc/os-release ]] || die "/etc/os-release is missing."
# shellcheck disable=SC1091
source /etc/os-release
[[ ${ID:-} == ubuntu ]] || die "This script supports Ubuntu only. Detected: ${ID:-unknown}."
info "Ubuntu: ${PRETTY_NAME:-Ubuntu}"
info "Architecture: $(dpkg --print-architecture)"

if ((HARDEN_SSH)) && [[ -e /etc/ssh/sshd_config ]]; then
  ssh_hardening_has_precedence /etc/ssh/sshd_config /etc/ssh/sshd_config.d "$SSH_HARDENING_FILE" ||
    die "SSH hardening requires the standard first Include /etc/ssh/sshd_config.d/*.conf and no drop-in before $SSH_HARDENING_FILE. Review custom SSH ordering first."
fi

TMP_DIR=$(mktemp -d)
if id "$ADMIN_USER" > /dev/null 2>&1; then
  [[ -z $ADMIN_KEY_FILE ]] || die "--admin-key only installs keys for a newly created user."
  if ((HARDEN_SSH)); then
    ADMIN_HOME=$(getent passwd "$ADMIN_USER" | cut -d: -f6)
    [[ -d $ADMIN_HOME && -d $ADMIN_HOME/.ssh && ! -L $ADMIN_HOME/.ssh ]] ||
      die "The administrator needs a real .ssh directory in their home."
    [[ -s $ADMIN_HOME/.ssh/authorized_keys &&
      ! -L $ADMIN_HOME/.ssh/authorized_keys ]] ||
      die "The administrator needs a nonempty, regular authorized_keys file."
    ADMIN_GROUPS=" $(id -nG "$ADMIN_USER") "
    [[ $ADMIN_GROUPS == *" sudo "* ]] ||
      die "Existing administrator '$ADMIN_USER' must belong to the sudo group."
  fi
else
  ((CREATE_USER)) ||
    die "User '$ADMIN_USER' does not exist. Use --create-user or select an existing user."
  [[ -t 0 && -t 1 ]] ||
    die "--create-user requires a terminal to set the new user's sudo password."
  if [[ -n $ADMIN_KEY_FILE ]]; then
    install -m 0600 -- "$ADMIN_KEY_FILE" "$TMP_DIR/admin-authorized_keys"
    admin_key_file_is_usable "$TMP_DIR/admin-authorized_keys" ||
      die "--admin-key must contain valid bare public keys without authorized_keys options. Supply the administrator's .pub file; do not copy restricted root entries."
  elif ((HARDEN_SSH)); then
    die "Creating an administrator with SSH hardening requires --admin-key FILE."
  fi
fi

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

log "Updating Ubuntu packages"
apt-get update
if ((RUN_OS_UPGRADE)); then
  apt-get -y upgrade
else
  warn "Initial package upgrade skipped by request."
fi

log "Installing host utilities and automatic security updates"
apt-get install -y \
  apt-transport-https ca-certificates curl debian-archive-keyring \
  debian-keyring gnupg iproute2 openssh-server sudo ufw unattended-upgrades

log "Preparing the administrative user"
if ! id "$ADMIN_USER" > /dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "$ADMIN_USER"
  usermod --append --groups sudo "$ADMIN_USER"
  passwd "$ADMIN_USER"
  if [[ -n $ADMIN_KEY_FILE ]]; then
    ADMIN_HOME=$(getent passwd "$ADMIN_USER" | cut -d: -f6)
    ADMIN_GROUP=$(id -gn "$ADMIN_USER")
    install -d -m 0700 -o "$ADMIN_USER" -g "$ADMIN_GROUP" "$ADMIN_HOME/.ssh"
    install -m 0600 -o "$ADMIN_USER" -g "$ADMIN_GROUP" \
      "$TMP_DIR/admin-authorized_keys" "$ADMIN_HOME/.ssh/authorized_keys"
    info "Installed the supplied administrator public keys in $ADMIN_HOME/.ssh/."
  else
    warn "No SSH key was copied. Configure the new user's SSH access."
  fi
fi
info "Administrator account: $ADMIN_USER"

log "Checking Caddy's public ports"
if ! systemctl is-active --quiet caddy 2> /dev/null; then
  PORT_LISTENERS=$(ss -H -ltnp '( sport = :80 or sport = :443 )')
  [[ -z $PORT_LISTENERS ]] ||
    die "TCP 80 or 443 is already in use; resolve the listener before installing Caddy: $PORT_LISTENERS"
fi

log "Installing Caddy from its official stable APT repository"
curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL \
  https://dl.cloudsmith.io/public/caddy/stable/gpg.key -o "$TMP_DIR/caddy-gpg.key"
# Reviewed public-key bytes, resolved 2026-11-12. A rotation must be reviewed
# and this pin updated deliberately before provisioning resumes.
printf '%s  %s\n' '783dfee04b19e851a928cd87b34710213ebbe7628f98d9f34595ab83be578c00' "$TMP_DIR/caddy-gpg.key" |
  sha256sum --check --status || die "Caddy signing key changed; verify its provenance before updating the pin."
install -d -m 0700 "$TMP_DIR/gnupg"
GNUPGHOME="$TMP_DIR/gnupg" gpg --batch --yes --dearmor --output "$TMP_DIR/caddy-keyring.gpg" \
  "$TMP_DIR/caddy-gpg.key"
cat > "$TMP_DIR/caddy-stable.list" << 'CADDY_APT'
deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main
CADDY_APT
install -m 0644 "$TMP_DIR/caddy-keyring.gpg" \
  /usr/share/keyrings/caddy-stable-archive-keyring.gpg
install -m 0644 "$TMP_DIR/caddy-stable.list" \
  /etc/apt/sources.list.d/caddy-stable.list
apt-get update
apt-get install -y caddy
caddy validate --config /etc/caddy/Caddyfile
systemctl enable --now caddy
systemctl is-active --quiet caddy || die "Caddy did not start successfully."
info "$(caddy version)"

# Ubuntu's default unattended-upgrades policy covers Ubuntu repositories.
# Third-party repositories such as Caddy are not added to that policy.
cat > "$TMP_DIR/auto-upgrades" << 'APT'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT
install -m 0644 "$TMP_DIR/auto-upgrades" \
  /etc/apt/apt.conf.d/90-prepare-ubuntu-auto-upgrades
systemctl enable --now apt-daily.timer apt-daily-upgrade.timer

if ((HARDEN_KERNEL)); then
  log "Installing conservative kernel and network hardening"
  SYSCTL_HARDENING_FILE=/etc/sysctl.d/99-prepare-ubuntu-hardening.conf
  cat > "$TMP_DIR/sysctl-hardening" << 'SYSCTL'
# Managed by prepare-ubuntu.sh. Preserve IPv6 and normal routed traffic.
fs.protected_fifos = 2
fs.protected_hardlinks = 1
fs.protected_regular = 2
fs.protected_symlinks = 1
fs.suid_dumpable = 0
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.randomize_va_space = 2
kernel.yama.ptrace_scope = 1

# Reject source-routed traffic and ICMP redirects.
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Loose reverse-path filtering tolerates asymmetric routing.
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2

net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
SYSCTL
  install -m 0644 "$TMP_DIR/sysctl-hardening" "$SYSCTL_HARDENING_FILE"
  sysctl -p "$SYSCTL_HARDENING_FILE" > /dev/null
  info "Applied: $SYSCTL_HARDENING_FILE"
else
  warn "Kernel hardening skipped by request."
fi

restore_ssh_config() {
  if [[ -f $TMP_DIR/previous-sshd-config ]]; then
    install -m 0600 "$TMP_DIR/previous-sshd-config" "$SSH_HARDENING_FILE"
  else
    rm -f -- "$SSH_HARDENING_FILE"
  fi
}

ssh_config_is_hardened() {
  local effective setting client_addr client_port server_addr server_port user
  read -r client_addr client_port server_addr server_port <<< "${SSH_CONNECTION:-127.0.0.1 0 127.0.0.1 22}"
  for user in "$ADMIN_USER" root; do
    effective=$(/usr/sbin/sshd -T \
      -C "user=$user,host=$client_addr,addr=$client_addr,laddr=$server_addr,lport=$server_port") || return 1
    effective=${effective,,}
    for setting in \
      'pubkeyauthentication yes' \
      'passwordauthentication no' \
      'kbdinteractiveauthentication no' \
      'hostbasedauthentication no' \
      'permitemptypasswords no' \
      'permitrootlogin no'; do
      grep -qx "$setting" <<< "$effective" || return 1
    done
  done
}

if ((HARDEN_SSH)); then
  log "Hardening OpenSSH"
  ADMIN_HOME=$(getent passwd "$ADMIN_USER" | cut -d: -f6)
  AUTHORIZED_KEYS="$ADMIN_HOME/.ssh/authorized_keys"
  [[ -s $AUTHORIZED_KEYS && ! -L $AUTHORIZED_KEYS ]] ||
    die "Refusing to disable SSH passwords: $AUTHORIZED_KEYS is missing or empty."
  ssh-keygen -lf "$AUTHORIZED_KEYS" > /dev/null ||
    die "No valid SSH public key was found in $AUTHORIZED_KEYS."
  ADMIN_GROUP=$(id -gn "$ADMIN_USER")
  chown "$ADMIN_USER:$ADMIN_GROUP" "$ADMIN_HOME/.ssh" "$AUTHORIZED_KEYS"
  chmod 0700 "$ADMIN_HOME/.ssh"
  chmod 0600 "$AUTHORIZED_KEYS"

  ssh_hardening_has_precedence /etc/ssh/sshd_config /etc/ssh/sshd_config.d "$SSH_HARDENING_FILE" ||
    die "SSH include ordering changed or is unsupported; refusing to install hardening."
  if [[ -e $SSH_HARDENING_FILE ]]; then
    cp -p "$SSH_HARDENING_FILE" "$TMP_DIR/previous-sshd-config"
  fi
  cat > "$TMP_DIR/sshd-hardening" << 'SSHD'
# Managed by prepare-ubuntu.sh. Early name precedes cloud-init drop-ins.
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
PermitRootLogin no
HostbasedAuthentication no
IgnoreRhosts yes
StrictModes yes
PermitUserEnvironment no
X11Forwarding no
AllowAgentForwarding no
LoginGraceTime 30
MaxAuthTries 3
LogLevel VERBOSE

# First matching conditional values win over later User/Group/Address rules.
# The containing file's Match state is restored when this include returns.
Match all
    PubkeyAuthentication yes
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    PermitEmptyPasswords no
    PermitRootLogin no
    HostbasedAuthentication no
SSHD
  install -m 0600 "$TMP_DIR/sshd-hardening" "$SSH_HARDENING_FILE"
  if ! /usr/sbin/sshd -t || ! ssh_config_is_hardened; then
    restore_ssh_config
    die "SSH hardening failed validation; previous configuration restored."
  fi
  if ! systemctl enable --now ssh || ! systemctl reload ssh; then
    restore_ssh_config
    systemctl reload ssh || true
    die "SSH service rejected the hardening; previous configuration restored."
  fi
  systemctl is-active --quiet ssh || die "The OpenSSH service is not active."
  info "SSH password and root login are disabled; test a new SSH session before closing this one."
else
  warn "SSH hardening skipped by request."
fi

if ((ENABLE_UFW)); then
  log "Configuring UFW"
  ufw allow "$SSH_PORT/tcp"
  ufw allow 80/tcp
  ufw allow 443/tcp
  ufw default deny incoming
  ufw default allow outgoing
  if ! ufw status | grep -q '^Status: active'; then
    ufw --force enable
  fi
  ufw_policy=$(LC_ALL=C ufw status verbose)
  printf '%s\n' "$ufw_policy"
  grep -q '^Default: deny (incoming), allow (outgoing)' <<< "$ufw_policy" ||
    die "UFW default policy verification failed."
  warn "Test a new SSH connection and review any other required inbound ports."
else
  info "UFW was left unchanged. Review host and provider firewall rules for SSH, TCP 80, and TCP 443."
fi

log "Preparation complete"
cat << SUMMARY

Completed:
  - Installed and started Caddy from its official stable APT repository
  - Enabled Ubuntu's daily automatic security updates
  - Prepared administrator: $ADMIN_USER
SUMMARY
if ((RUN_OS_UPGRADE)); then info "Installed available Ubuntu package upgrades."; fi
if ((HARDEN_KERNEL)); then info "Applied kernel and network sysctl hardening."; fi
if ((HARDEN_SSH)); then info "Disabled OpenSSH password, keyboard-interactive, host-based, and root login; public-key authentication is enabled."; fi
if ((ENABLE_UFW)); then info "Enabled or updated UFW for SSH, HTTP, and HTTPS."; fi

cat << 'NEXT'

Next:
  - Configure /etc/caddy/Caddyfile for your site, then run
    caddy validate --config /etc/caddy/Caddyfile and systemctl reload caddy.
  - Point public DNS at this host and permit TCP 80/443 in the provider firewall.
  - Test a new SSH login before ending the current session.
  - Review Caddy updates separately: Ubuntu's default unattended-upgrades
    policy does not automatically include the third-party Caddy repository.
NEXT

if [[ -e /var/run/reboot-required ]]; then
  warn "Ubuntu reports that a reboot is required."
fi
