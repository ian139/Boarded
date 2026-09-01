#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REPO=$(CDPATH= cd -- "$ROOT/../.." && pwd)
ENV_FILE=${SELF_HOSTED_ENV_FILE:-$ROOT/.env}
COMPOSE_FILE="$ROOT/docker-compose.yml"
usage_error() { printf '%s\n' "$1" >&2; exit 2; }
valid_port() {
  case "$1" in ''|*[!0-9]*) return 1;; esac
  [ "$1" -ge 1 ] 2>/dev/null && [ "$1" -le 65535 ] 2>/dev/null
}
STAT_DIALECT=bsd
_stat_probe=$(stat -c '%a' / 2>/dev/null) || _stat_probe=
case "$_stat_probe" in ''|*[!0-7]*) ;; *) STAT_DIALECT=gnu;; esac
ACL_PLATFORM=$(uname -s 2>/dev/null || printf '%s' unknown)
stat_mode() {
  if [ "$STAT_DIALECT" = gnu ]; then
    stat -c '%a' "$1"
  else
    stat -f '%Lp' "$1"
  fi
}
stat_uid() {
  if [ "$STAT_DIALECT" = gnu ]; then
    stat -c '%u' "$1"
  else
    stat -f '%u' "$1"
  fi
}
stat_owner_name() {
  if [ "$STAT_DIALECT" = gnu ]; then
    stat -c '%U' "$1"
  else
    stat -f '%Su' "$1"
  fi
}
# Return success when an ACL entry is a foreign or otherwise unsafe grant.
# Owner/root allow entries and deny entries are not foreign grants.
acl_entry_is_foreign() {
  _acl_entry=$1
  _acl_owner_uid=$2
  _acl_owner_name=$3
  case "$ACL_PLATFORM" in
    Darwin)
      _acl_body=${_acl_entry#*: }
      [ "$_acl_body" != "$_acl_entry" ] || return 0
      _acl_type=${_acl_body%%:*}
      _acl_rest=${_acl_body#*:}
      _acl_principal=${_acl_rest%% *}
      _acl_action=${_acl_rest#* }
      _acl_action=${_acl_action%% *}
      [ "$_acl_action" = allow ] || return 1
      case "$_acl_type" in
        user)
          case "$_acl_principal" in
            "$_acl_owner_name"|root|"$_acl_owner_uid"|0) return 1;;
            *) return 0;;
          esac
          ;;
        *) return 0;;
      esac
      ;;
    Linux)
      case "$_acl_entry" in
        user::*|group::*|other::*|mask::*) return 1;;
        default:user::*|default:mask::*) return 1;;
        user:*:*)
          _acl_principal=${_acl_entry#user:}
          _acl_principal=${_acl_principal%%:*}
          case "$_acl_principal" in
            "$_acl_owner_name"|root|"$_acl_owner_uid"|0) return 1;;
            *) return 0;;
          esac
          ;;
        default:user:*:*)
          _acl_principal=${_acl_entry#default:user:}
          _acl_principal=${_acl_principal%%:*}
          case "$_acl_principal" in
            "$_acl_owner_name"|root|"$_acl_owner_uid"|0) return 1;;
            *) return 0;;
          esac
          ;;
        *) return 0;;
      esac
      ;;
    *) return 0;;
  esac
}
require_no_foreign_acl() {
  _acl_path=$1
  _acl_label=$2
  _acl_owner_uid=$3
  _acl_owner_name=$(stat_owner_name "$_acl_path" 2>/dev/null) ||
    usage_error "Cannot determine $_acl_label owner for ACL inspection: $_acl_path"
  case "$ACL_PLATFORM" in
    Darwin)
      _acl_listing=$(/bin/ls -lde "$_acl_path" 2>/dev/null) ||
        usage_error "Cannot inspect $_acl_label ACL: $_acl_path"
      _acl_entries=$(printf '%s\n' "$_acl_listing" | sed '1d') ||
        usage_error "Cannot inspect $_acl_label ACL: $_acl_path"
      ;;
    Linux)
      if command -v getfacl >/dev/null 2>&1; then
        _acl_entries=$(getfacl -cp "$_acl_path" 2>/dev/null) ||
          usage_error "Cannot inspect $_acl_label ACL: $_acl_path"
      else
        _acl_listing=$(ls -ld "$_acl_path" 2>/dev/null) ||
          usage_error "Cannot inspect $_acl_label ACL: $_acl_path"
        _acl_mode=${_acl_listing%% *}
        case "$_acl_mode" in
          *+) usage_error "$_acl_label has an ACL marker but getfacl is unavailable; refusing: $_acl_path";;
        esac
        _acl_entries=
      fi
      ;;
    *) usage_error "Cannot inspect $_acl_label ACL on unsupported platform: $ACL_PLATFORM";;
  esac
  while IFS= read -r _acl_entry || [ -n "$_acl_entry" ]; do
    [ -n "$_acl_entry" ] || continue
    if acl_entry_is_foreign "$_acl_entry" "$_acl_owner_uid" "$_acl_owner_name"; then
      usage_error "$_acl_label has an extended ACL granting access beyond owner/root: $_acl_path"
    fi
  done <<EOF
$_acl_entries
EOF
}
# Clear inherited ACLs on artifacts created by this tooling, then re-check
# custody. Linux cannot safely normalize without setfacl when an ACL marker is
# present, so that case fails closed.
normalize_acl() {
  _na_path=$1
  _na_label=$2
  case "$ACL_PLATFORM" in
    Darwin)
      /bin/chmod -N "$_na_path" 2>/dev/null ||
        usage_error "Cannot clear inherited ACL from $_na_label: $_na_path"
      ;;
    Linux)
      if command -v setfacl >/dev/null 2>&1; then
        setfacl -b "$_na_path" 2>/dev/null ||
          usage_error "Cannot clear inherited ACL from $_na_label: $_na_path"
      else
        _na_listing=$(ls -ld "$_na_path" 2>/dev/null) ||
          usage_error "Cannot inspect $_na_label ACL: $_na_path"
        _na_mode=${_na_listing%% *}
        case "$_na_mode" in
          *+) usage_error "Cannot clear $_na_label ACL because setfacl is unavailable: $_na_path";;
        esac
      fi
      ;;
    *) usage_error "Cannot clear $_na_label ACL on unsupported platform: $ACL_PLATFORM";;
  esac
  _na_uid=$(stat_uid "$_na_path" 2>/dev/null) ||
    usage_error "Cannot determine $_na_label owner after ACL normalization: $_na_path"
  require_no_foreign_acl "$_na_path" "$_na_label" "$_na_uid"
}
require_trusted_component() {
  tc_path=$1
  tc_label=$2
  tc_uid=$(stat_uid "$tc_path") || usage_error "Cannot determine $tc_label owner: $tc_path"
  case "$tc_uid" in "$(id -u)"|0) ;; *) usage_error "$tc_label must be owned by the current effective user or root: $tc_path";; esac
  tc_mode=$(stat_mode "$tc_path") || usage_error "Cannot determine $tc_label permissions: $tc_path"
  case "$tc_mode" in ''|*[!0-7]*) usage_error "Invalid $tc_label permissions: $tc_mode";; esac
  case "$tc_mode" in *[2367][0-7]|*[0-7][2367]) usage_error "$tc_label must not be group- or world-writable: $tc_path";; esac
  require_no_foreign_acl "$tc_path" "$tc_label" "$tc_uid"
}
require_owned() {
  ro_path=$1
  ro_label=$2
  ro_uid=$(stat_uid "$ro_path") || usage_error "Cannot determine $ro_label owner: $ro_path"
  [ "$ro_uid" = "$(id -u)" ] || usage_error "$ro_label must be owned by the current effective user: $ro_path"
  ro_mode=$(stat_mode "$ro_path") || usage_error "Cannot determine $ro_label permissions: $ro_path"
  case "$ro_mode" in ''|*[!0-7]*) usage_error "Invalid $ro_label permissions: $ro_mode";; esac
  case "$ro_mode" in *[2367][0-7]|*[0-7][2367]) usage_error "$ro_label must not be group- or world-writable: $ro_path";; esac
  require_no_foreign_acl "$ro_path" "$ro_label" "$ro_uid"
}
require_trusted_ancestors() {
  ta_path=$1
  ta_label=$2
  case "$ta_path" in /*) ;; *) usage_error "$ta_label must be an absolute path: $ta_path";; esac
  require_trusted_component / "$ta_label"
  ta_cur=
  ta_rest=${ta_path#/}
  while [ -n "$ta_rest" ]; do
    ta_comp=${ta_rest%%/*}
    case "$ta_rest" in */*) ta_rest=${ta_rest#*/};; *) ta_rest=;; esac
    ta_cur=$ta_cur/$ta_comp
    [ -n "$ta_rest" ] || break
    require_trusted_component "$ta_cur" "$ta_label"
  done
}
require_rsa_key() {
  rk_path=$1
  rk_label=$2
  rk_kind=$3
  if [ "$rk_kind" = private ]; then
    rk_text=$(openssl rsa -in "$rk_path" -text -noout </dev/null 2>/dev/null) || usage_error "$rk_label is not a valid RSA private key: $rk_path"
  else
    rk_text=$(openssl rsa -pubin -in "$rk_path" -text -noout </dev/null 2>/dev/null) || usage_error "$rk_label is not a valid RSA public key: $rk_path"
  fi
  rk_bits=$(printf '%s\n' "$rk_text" | sed -n '1s/.*(\([0-9][0-9]*\) bit.*/\1/p')
  case "$rk_bits" in ''|*[!0-9]*) usage_error "Cannot determine $rk_label RSA key size: $rk_path";; esac
  [ "$rk_bits" -ge 3072 ] || usage_error "$rk_label must be an RSA key of at least 3072 bits (is $rk_bits): $rk_path"
}
require_mode_0600() {
  path=$1
  label=$2
  mode=$(stat_mode "$path") || usage_error "Cannot determine $label permissions: $path"
  [ "$mode" = 600 ] || usage_error "$label must have mode 0600: $path"
}
valid_url_path() {
  url=$1
  expected_path=$2
  case "$url" in *[[:space:]]*|*'?'*|*'#'*|*'@'*) return 1;; esac
  case "$url" in
    https://*) scheme=https; remainder=${url#https://};;
    http://*) scheme=http; remainder=${url#http://};;
    *) return 1;;
  esac
  authority=${remainder%%/*}
  path=${remainder#"$authority"}
  [ -n "$authority" ] && [ "$path" = "$expected_path" ] || return 1
  case "$authority" in
    *:*) host=${authority%%:*}; port=${authority#*:}; case "$port" in *:*) return 1;; esac; valid_port "$port" || return 1;;
    *) host=$authority; port=;;
  esac
  case "$host" in ''|.*|*.|-*|*-|*..*|*[!A-Za-z0-9.-]*) return 1;; esac
  if [ "$scheme" = http ]; then
    [ -n "$port" ] || return 1
    case "$host" in localhost|127.0.0.1) ;; *) return 1;; esac
  fi
}
valid_origin() { valid_url_path "$1" ''; }
MANAGED_ENV_VARS='POSTGRES_PASSWORD AUTHENTICATOR_DB_PASSWORD SUPABASE_AUTH_ADMIN_PASSWORD SUPABASE_STORAGE_ADMIN_PASSWORD SUPABASE_FUNCTIONS_ADMIN_PASSWORD PGBOUNCER_PASSWORD JWT_SECRET ANON_KEY SERVICE_ROLE_KEY API_PORT API_EXTERNAL_URL SITE_URL ADDITIONAL_REDIRECT_URLS JWT_EXPIRY DISABLE_SIGNUP ENABLE_EMAIL_SIGNUP ENABLE_EMAIL_AUTOCONFIRM PGRST_DB_SCHEMAS'
env_error() { printf '%s\n' "$1" >&2; exit 1; }
clear_managed_env() {
  for _name in $MANAGED_ENV_VARS; do
    unset "$_name"
  done
}
load_env_file() {
  _file=$1
  while IFS= read -r _line || [ -n "$_line" ]; do
    case "$_line" in ''|'#'*) continue;; esac
    _name=${_line%%=*}
    case "$_line" in *=*) ;; *) env_error "Invalid env line (expected NAME=value): $_line";; esac
    case "$_name" in ''|*[!A-Za-z0-9_]*) env_error "Invalid env variable name: $_name";; esac
    case "$_name" in [0-9]*) env_error "Invalid env variable name: $_name";; esac
    case " $MANAGED_ENV_VARS " in *" $_name "*) ;; *) env_error "Unmanaged env variable name: $_name";; esac
    _value=${_line#*=}
    case "$_value" in *[!A-Za-z0-9_.,:/-]*) env_error "Unsafe or unsupported value for $_name";; esac
    export "$_name=$_value"
  done < "$_file"
}
validate_env() {
  _required='POSTGRES_PASSWORD AUTHENTICATOR_DB_PASSWORD SUPABASE_AUTH_ADMIN_PASSWORD SUPABASE_STORAGE_ADMIN_PASSWORD SUPABASE_FUNCTIONS_ADMIN_PASSWORD PGBOUNCER_PASSWORD JWT_SECRET ANON_KEY SERVICE_ROLE_KEY API_PORT API_EXTERNAL_URL SITE_URL'
  for _name in $_required; do
    eval "_value=\${$_name-}"
    case "$_value" in ''|changeme|CHANGE_ME|replace-me|your-*|example|*'<placeholder>'*) env_error "$_name is empty or a placeholder";; esac
  done
  _db_passwords='POSTGRES_PASSWORD AUTHENTICATOR_DB_PASSWORD SUPABASE_AUTH_ADMIN_PASSWORD SUPABASE_STORAGE_ADMIN_PASSWORD SUPABASE_FUNCTIONS_ADMIN_PASSWORD PGBOUNCER_PASSWORD'
  _seen=
  for _name in $_db_passwords; do
    eval "_value=\${$_name}"
    [ ${#_value} -ge 43 ] || env_error "$_name must contain at least 32 bytes of URL-safe random data"
    case "$_value" in *[!A-Za-z0-9_-]*) env_error "$_name must be URL-safe (letters, digits, underscore, and hyphen only)";; esac
    case " $_seen " in *" $_value "*) env_error 'Every database role password must be distinct';; esac
    _seen="$_seen $_value"
  done
  [ ${#JWT_SECRET} -ge 32 ] || env_error 'JWT_SECRET must be at least 32 characters'
  case "$API_PORT" in *[!0-9]*|'') env_error 'API_PORT must be numeric';; esac
  [ "$API_PORT" -ge 1 ] && [ "$API_PORT" -le 65535 ] || env_error 'API_PORT out of range'
  valid_url_path "$API_EXTERNAL_URL" '/auth/v1' || env_error 'API_EXTERNAL_URL must be a valid HTTPS origin plus exactly /auth/v1 (HTTP loopback with an explicit valid port allowed)'
  valid_origin "$SITE_URL" || env_error 'SITE_URL must be a valid pathless HTTPS origin (HTTP loopback with an explicit valid port allowed)'
}
require_env() {
  [ -f "$ENV_FILE" ] && [ ! -L "$ENV_FILE" ] || env_error "Missing or unsafe $ENV_FILE"
  _env_dir=$(CDPATH= cd -P -- "$(dirname -- "$ENV_FILE")" && pwd) || env_error "Cannot resolve $ENV_FILE parent"
  _env_path=$_env_dir/$(basename -- "$ENV_FILE")
  require_trusted_ancestors "$_env_path" 'Environment file'
  require_owned "$_env_path" 'Environment file'
  require_mode_0600 "$_env_path" 'Environment file'
  clear_managed_env
  load_env_file "$_env_path"
  validate_env
  "$ROOT/bin/verify-pin"
}
compose() { docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"; }
run() { if [ "${DRY_RUN:-0}" = 1 ]; then printf '+ '; printf '%s ' "$@"; printf '\n'; else "$@"; fi; }
OPERATION_LOCK_DIR="$ROOT/.operation-lock"
OPERATION_LOCK_HELD=0
acquire_operation_lock() {
  operation=${1:-operation}
  [ "$OPERATION_LOCK_HELD" = 0 ] || {
    printf '%s\n' 'Operation lock is already held by this process; nested acquisition is not allowed.' >&2
    return 1
  }
  if mkdir "$OPERATION_LOCK_DIR" 2>/dev/null; then
    OPERATION_LOCK_HELD=1
    if ! {
      printf 'operation=%s\n' "$operation"
      printf 'pid=%s\n' "$$"
    } > "$OPERATION_LOCK_DIR/owner"; then
      rm -f "$OPERATION_LOCK_DIR/owner"
      rmdir "$OPERATION_LOCK_DIR"
      OPERATION_LOCK_HELD=0
      printf '%s\n' "Could not record operation lock ownership: $OPERATION_LOCK_DIR" >&2
      return 1
    fi
    return 0
  fi
  printf '%s\n' "Another backup, migration, or restore may be running (lock: $OPERATION_LOCK_DIR)." >&2
  printf '%s\n' 'If this lock is stale, remove it only after confirming no operation process is still running.' >&2
  return 1
}
release_operation_lock() {
  [ "$OPERATION_LOCK_HELD" = 1 ] || return 0
  rm -f "$OPERATION_LOCK_DIR/owner"
  rmdir "$OPERATION_LOCK_DIR"
  OPERATION_LOCK_HELD=0
}
parse_dry_run() { DRY_RUN=0; case "${1:-}" in --dry-run) DRY_RUN=1; shift;; '') ;; *) usage_error "Unknown option: $1";; esac; [ "$#" -eq 0 ] || usage_error 'Unexpected arguments'; }
