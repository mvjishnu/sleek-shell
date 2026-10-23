#define _GNU_SOURCE
#include <errno.h>
#include <poll.h>
#include <pthread.h>
#include <signal.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#include <glib.h>
#include <gmodule.h>

#include <rofi/helper.h>
#include <rofi/mode-private.h>
#include <rofi/mode.h>

#ifndef SLEEK_CALC_SCRIPT
#define SLEEK_CALC_SCRIPT ""
#endif

#define RS "\x1e"
#define US "\x1f"
#define REPLY_TIMEOUT_MS 1500
#define FIRST_REPLY_TIMEOUT_MS 4000
#define MAX_REPLY_BYTES (1024 * 1024)
#define MAX_SEND_BYTES 4096

#define SC_URGENT 1
#define SC_ACTIVE 2

typedef struct RofiViewState RofiViewState;
extern RofiViewState *rofi_view_get_active(void);
extern const char *rofi_view_get_user_input(const RofiViewState *state);
extern void rofi_view_reload(void);

G_MODULE_EXPORT Mode mode;

typedef enum { ROW_NONE, ROW_LIVE, ROW_ALT, ROW_HIST } RowKind;
typedef enum { RL_OK, RL_TIMEOUT, RL_EOF } ReadStatus;

typedef struct {
  GHashTable *s;
  GHashTable *a;
} JObj;

typedef struct {
  GPid pid;
  int in_fd;
  int out_fd;
  gboolean fresh;
  GString *rbuf;
  char *script;
  char *engine_error;

  char *input;
  gboolean ok;
  char *result;
  char *value;
  char *error;
  char *kind;
  GPtrArray *alts;

  GPtrArray *hres;
  GPtrArray *hexpr;
  char *angle;

  unsigned int shown_rows;
  char *shown_message;
} CalcPriv;

/* ------------------------------------------------------------ JSON */

static void jobj_free(JObj *o) {
  if (o == NULL) {
    return;
  }
  g_hash_table_destroy(o->s);
  g_hash_table_destroy(o->a);
  g_free(o);
}

static const char *jstr(const JObj *o, const char *key) {
  const char *v = o ? g_hash_table_lookup(o->s, key) : NULL;
  return v ? v : "";
}

static gboolean jtrue(const JObj *o, const char *key) {
  return strcmp(jstr(o, key), "true") == 0;
}

static GPtrArray *jarr(const JObj *o, const char *key) {
  return o ? g_hash_table_lookup(o->a, key) : NULL;
}

static void skip_ws(const char **p) {
  while (**p == ' ' || **p == '\t' || **p == '\n' || **p == '\r') {
    (*p)++;
  }
}

static int hex4(const char *p) {
  int v = 0;
  for (int i = 0; i < 4; i++) {
    char c = p[i];
    v <<= 4;
    if (c >= '0' && c <= '9') {
      v |= c - '0';
    } else if (c >= 'a' && c <= 'f') {
      v |= c - 'a' + 10;
    } else if (c >= 'A' && c <= 'F') {
      v |= c - 'A' + 10;
    } else {
      return -1;
    }
  }
  return v;
}

static char *parse_string(const char **pp) {
  const char *p = *pp;
  if (*p != '"') {
    return NULL;
  }
  p++;
  GString *g = g_string_new(NULL);
  while (*p && *p != '"') {
    if ((unsigned char)*p < 0x20) {
      goto fail;
    }
    if (*p != '\\') {
      g_string_append_c(g, *p++);
      continue;
    }
    p++;
    switch (*p) {
    case '"':
      g_string_append_c(g, '"');
      break;
    case '\\':
      g_string_append_c(g, '\\');
      break;
    case '/':
      g_string_append_c(g, '/');
      break;
    case 'b':
    case 'f':
    case 'n':
    case 'r':
    case 't':
      g_string_append_c(g, ' ');
      break;
    case 'u': {
      int c = hex4(p + 1);
      if (c < 0) {
        goto fail;
      }
      p += 4;
      if (c >= 0xD800 && c <= 0xDBFF) {
        int lo = (p[1] == '\\' && p[2] == 'u') ? hex4(p + 3) : -1;
        if (lo >= 0xDC00 && lo <= 0xDFFF) {
          c = 0x10000 + ((c - 0xD800) << 10) + (lo - 0xDC00);
          p += 6;
        } else {
          c = 0xFFFD;
        }
      } else if (c >= 0xDC00 && c <= 0xDFFF) {
        c = 0xFFFD;
      }
      if (c < 0x20) {
        c = (c == 0) ? 0xFFFD : ' ';
      }
      g_string_append_unichar(g, (gunichar)c);
      break;
    }
    default:
      goto fail;
    }
    p++;
  }
  if (*p != '"') {
    goto fail;
  }
  *pp = p + 1;
  return g_string_free(g, FALSE);
fail:
  g_string_free(g, TRUE);
  return NULL;
}

static char *parse_scalar(const char **pp) {
  const char *s = *pp;
  const char *p = s;
  if (*s == '{' || *s == '[' || *s == '"') {
    return NULL;
  }
  while (*p && strchr(",}] \t\r\n", *p) == NULL) {
    p++;
  }
  if (p == s) {
    return NULL;
  }
  *pp = p;
  if ((size_t)(p - s) == 4 && strncmp(s, "null", 4) == 0) {
    return g_strdup("");
  }
  return g_strndup(s, (gsize)(p - s));
}

static JObj *json_parse(const char *text) {
  JObj *o = g_new0(JObj, 1);
  o->s = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
  o->a = g_hash_table_new_full(g_str_hash, g_str_equal, g_free,
                               (GDestroyNotify)g_ptr_array_unref);
  const char *p = text;
  skip_ws(&p);
  if (*p != '{') {
    goto fail;
  }
  p++;
  skip_ws(&p);
  if (*p == '}') {
    return o;
  }
  for (;;) {
    skip_ws(&p);
    char *key = parse_string(&p);
    if (key == NULL) {
      goto fail;
    }
    skip_ws(&p);
    if (*p != ':') {
      g_free(key);
      goto fail;
    }
    p++;
    skip_ws(&p);
    if (*p == '[') {
      p++;
      GPtrArray *arr = g_ptr_array_new_with_free_func(g_free);
      skip_ws(&p);
      if (*p == ']') {
        p++;
      } else {
        for (;;) {
          skip_ws(&p);
          char *v = (*p == '"') ? parse_string(&p) : parse_scalar(&p);
          if (v == NULL) {
            g_ptr_array_unref(arr);
            g_free(key);
            goto fail;
          }
          g_ptr_array_add(arr, v);
          skip_ws(&p);
          if (*p == ',') {
            p++;
            continue;
          }
          if (*p == ']') {
            p++;
            break;
          }
          g_ptr_array_unref(arr);
          g_free(key);
          goto fail;
        }
      }
      g_hash_table_replace(o->a, key, arr);
    } else {
      char *v = (*p == '"') ? parse_string(&p) : parse_scalar(&p);
      if (v == NULL) {
        g_free(key);
        goto fail;
      }
      g_hash_table_replace(o->s, key, v);
    }
    skip_ws(&p);
    if (*p == ',') {
      p++;
      continue;
    }
    if (*p == '}') {
      break;
    }
    goto fail;
  }
  return o;
fail:
  jobj_free(o);
  return NULL;
}

/* ------------------------------------------------------------ coprocess */

static char *sanitize(const char *s) {
  GString *g = g_string_sized_new(strlen(s) + 1);
  for (const unsigned char *p = (const unsigned char *)s; *p; p++) {
    g_string_append_c(g, (*p < 0x20 || *p == 0x7f) ? ' ' : (char)*p);
  }
  return g_string_free(g, FALSE);
}

static void set_engine_error(CalcPriv *pd, const char *msg) {
  g_free(pd->engine_error);
  pd->engine_error = g_strdup(msg);
}

static void coproc_stop(CalcPriv *pd, gboolean graceful) {
  if (pd->in_fd >= 0) {
    close(pd->in_fd);
    pd->in_fd = -1;
  }
  if (pd->out_fd >= 0) {
    close(pd->out_fd);
    pd->out_fd = -1;
  }
  if (pd->pid > 0) {
    pid_t pid = pd->pid;
    gboolean done = FALSE;
    pd->pid = 0;
    if (graceful) {
      for (int i = 0; i < 50 && !done; i++) {
        pid_t r = waitpid(pid, NULL, WNOHANG);
        if (r == pid || (r < 0 && errno != EINTR)) {
          done = TRUE;
        } else {
          g_usleep(10000);
        }
      }
    }
    if (!done) {
      kill(pid, SIGKILL);
      while (waitpid(pid, NULL, 0) < 0 && errno == EINTR) {
      }
    }
    g_spawn_close_pid(pid);
  }
  if (pd->rbuf) {
    g_string_truncate(pd->rbuf, 0);
  }
}

static gboolean coproc_start(CalcPriv *pd) {
  if (pd->pid > 0) {
    return TRUE;
  }
  if (!g_file_test(pd->script, G_FILE_TEST_IS_REGULAR)) {
    char *m = g_strdup_printf("Engine not found: %s", pd->script);
    set_engine_error(pd, m);
    g_free(m);
    return FALSE;
  }
  const char *py = g_getenv("SLEEK_CALC_PYTHON");
  if (py == NULL || *py == '\0') {
    py = "python3";
  }
  char *argv[] = {(char *)py, pd->script, "--serve", NULL};
  GError *err = NULL;
  GPid pid = 0;
  int in_fd = -1, out_fd = -1;
  if (!g_spawn_async_with_pipes(
          NULL, argv, NULL,
          G_SPAWN_SEARCH_PATH | G_SPAWN_DO_NOT_REAP_CHILD |
              G_SPAWN_STDERR_TO_DEV_NULL,
          NULL, NULL, &pid, &in_fd, &out_fd, NULL, &err)) {
    char *m = g_strdup_printf("Cannot start %s: %s", py,
                              err ? err->message : "unknown error");
    set_engine_error(pd, m);
    g_free(m);
    g_clear_error(&err);
    return FALSE;
  }
  pd->pid = pid;
  pd->in_fd = in_fd;
  pd->out_fd = out_fd;
  pd->fresh = TRUE;
  g_string_truncate(pd->rbuf, 0);
  return TRUE;
}

static gboolean write_all(int fd, const char *buf, size_t len) {
  sigset_t set, old;
  gboolean ok = TRUE;
  sigemptyset(&set);
  sigaddset(&set, SIGPIPE);
  pthread_sigmask(SIG_BLOCK, &set, &old);
  while (len > 0) {
    ssize_t w = write(fd, buf, len);
    if (w < 0) {
      if (errno == EINTR) {
        continue;
      }
      if (errno == EPIPE) {
        struct timespec ts = {0, 0};
        while (sigtimedwait(&set, NULL, &ts) < 0 && errno == EINTR) {
        }
      }
      ok = FALSE;
      break;
    }
    buf += w;
    len -= (size_t)w;
  }
  pthread_sigmask(SIG_SETMASK, &old, NULL);
  return ok;
}

static char *read_line(CalcPriv *pd, int timeout_ms, ReadStatus *st) {
  gint64 deadline = g_get_monotonic_time() + (gint64)timeout_ms * 1000;
  for (;;) {
    char *nl = memchr(pd->rbuf->str, '\n', pd->rbuf->len);
    if (nl != NULL) {
      gsize n = (gsize)(nl - pd->rbuf->str);
      char *line = g_strndup(pd->rbuf->str, n);
      g_string_erase(pd->rbuf, 0, (gssize)(n + 1));
      *st = RL_OK;
      return line;
    }
    if (pd->rbuf->len > MAX_REPLY_BYTES) {
      *st = RL_EOF;
      return NULL;
    }
    gint64 now = g_get_monotonic_time();
    if (now >= deadline) {
      *st = RL_TIMEOUT;
      return NULL;
    }
    struct pollfd pfd = {pd->out_fd, POLLIN, 0};
    int r = poll(&pfd, 1, (int)((deadline - now + 999) / 1000));
    if (r < 0) {
      if (errno == EINTR) {
        continue;
      }
      *st = RL_EOF;
      return NULL;
    }
    if (r == 0) {
      continue;
    }
    char buf[4096];
    ssize_t n = read(pd->out_fd, buf, sizeof buf);
    if (n < 0) {
      if (errno == EINTR || errno == EAGAIN) {
        continue;
      }
      *st = RL_EOF;
      return NULL;
    }
    if (n == 0) {
      *st = RL_EOF;
      return NULL;
    }
    g_string_append_len(pd->rbuf, buf, n);
  }
}

static JObj *request(CalcPriv *pd, const char *line) {
  for (int attempt = 0; attempt < 2; attempt++) {
    if (!coproc_start(pd)) {
      return NULL;
    }
    gboolean fresh = pd->fresh;
    ReadStatus st = RL_EOF;
    char *msg = g_strconcat(line, "\n", NULL);
    gboolean wrote = write_all(pd->in_fd, msg, strlen(msg));
    g_free(msg);
    if (wrote) {
      char *reply = read_line(
          pd, fresh ? FIRST_REPLY_TIMEOUT_MS : REPLY_TIMEOUT_MS, &st);
      pd->fresh = FALSE;
      if (reply != NULL) {
        JObj *o = json_parse(reply);
        g_free(reply);
        if (o != NULL) {
          return o;
        }
        set_engine_error(pd, "Engine sent an invalid reply");
        coproc_stop(pd, FALSE);
        return NULL;
      }
    }
    coproc_stop(pd, FALSE);
    if (st == RL_TIMEOUT) {
      set_engine_error(pd, "Calculation timed out");
      return NULL;
    }
    set_engine_error(pd, "Calculator engine exited unexpectedly");
    if (fresh) {
      return NULL;
    }
  }
  return NULL;
}

static JObj *request_cmd(CalcPriv *pd, const char *cmd, const char *a,
                         const char *b) {
  char *ca = a ? sanitize(a) : NULL;
  char *cb = b ? sanitize(b) : NULL;
  char *line;
  if (ca && cb) {
    line = g_strconcat(RS, cmd, " ", ca, US, cb, NULL);
  } else if (ca) {
    line = g_strconcat(RS, cmd, " ", ca, NULL);
  } else {
    line = g_strconcat(RS, cmd, NULL);
  }
  JObj *o = NULL;
  if (strlen(line) <= MAX_SEND_BYTES) {
    o = request(pd, line);
  }
  g_free(line);
  g_free(ca);
  g_free(cb);
  return o;
}

/* ------------------------------------------------------------ state */

static void set_str(char **dst, const char *v) {
  g_free(*dst);
  *dst = g_strdup(v);
}

static void clear_result(CalcPriv *pd) {
  g_clear_pointer(&pd->input, g_free);
  pd->ok = FALSE;
  g_clear_pointer(&pd->result, g_free);
  g_clear_pointer(&pd->value, g_free);
  g_clear_pointer(&pd->error, g_free);
  g_clear_pointer(&pd->kind, g_free);
  g_ptr_array_set_size(pd->alts, 0);
}

static gboolean is_blank(const char *s) {
  if (s == NULL) {
    return TRUE;
  }
  for (; *s; s++) {
    if (!g_ascii_isspace(*s)) {
      return FALSE;
    }
  }
  return TRUE;
}

static void evaluate_input(CalcPriv *pd, const char *input) {
  clear_result(pd);
  if (is_blank(input)) {
    return;
  }
  pd->input = g_strdup(input);
  char *clean = sanitize(input);
  if (strlen(clean) > MAX_SEND_BYTES) {
    pd->error = g_strdup("Input too long");
    g_free(clean);
    return;
  }
  JObj *o = request(pd, clean);
  g_free(clean);
  if (o == NULL) {
    pd->error = g_strdup(pd->engine_error ? pd->engine_error
                                          : "Calculator engine unavailable");
    return;
  }
  pd->ok = jtrue(o, "ok");
  pd->result = g_strdup(jstr(o, "result"));
  pd->value = g_strdup(jstr(o, "value"));
  pd->kind = g_strdup(jstr(o, "kind"));
  if (strcmp(pd->kind, "command") == 0) {
    set_str(&pd->result, jstr(o, "display"));
  }
  pd->error = g_strdup(*jstr(o, "error") ? jstr(o, "error")
                                         : "Invalid expression");
  if (*jstr(o, "mode")) {
    set_str(&pd->angle, jstr(o, "mode"));
  }
  GPtrArray *alts = jarr(o, "alternatives");
  if (pd->ok && alts != NULL) {
    for (guint i = 0; i < alts->len; i++) {
      const char *a = g_ptr_array_index(alts, i);
      if (*a && g_strcmp0(a, pd->result) != 0) {
        g_ptr_array_add(pd->alts, g_strdup(a));
      }
    }
  }
  if (pd->ok && *pd->result == '\0') {
    pd->ok = FALSE;
    set_str(&pd->error, "No result");
  }
  jobj_free(o);
}

static void refresh_history(CalcPriv *pd) {
  JObj *o = request_cmd(pd, "history", NULL, NULL);
  if (o == NULL) {
    return;
  }
  GPtrArray *res = jarr(o, "results");
  GPtrArray *exprs = jarr(o, "exprs");
  g_ptr_array_set_size(pd->hres, 0);
  g_ptr_array_set_size(pd->hexpr, 0);
  if (res != NULL) {
    for (guint i = 0; i < res->len; i++) {
      g_ptr_array_add(pd->hres, g_strdup(g_ptr_array_index(res, i)));
      g_ptr_array_add(pd->hexpr,
                      g_strdup((exprs && i < exprs->len)
                                   ? (const char *)g_ptr_array_index(exprs, i)
                                   : ""));
    }
  }
  if (*jstr(o, "mode")) {
    set_str(&pd->angle, jstr(o, "mode"));
  }
  jobj_free(o);
}

static gboolean live_is_command(const CalcPriv *pd) {
  return pd->input && pd->ok && g_strcmp0(pd->kind, "command") == 0;
}

static unsigned int live_rows(const CalcPriv *pd) {
  if (pd->input == NULL) {
    return 0;
  }
  return 1 + (pd->ok ? pd->alts->len : 0);
}

static unsigned int total_rows(const CalcPriv *pd) {
  return live_rows(pd) + pd->hres->len;
}

static RowKind classify(const CalcPriv *pd, unsigned int line,
                        unsigned int *idx) {
  unsigned int live = live_rows(pd);
  *idx = 0;
  if (line < live) {
    if (line == 0) {
      return ROW_LIVE;
    }
    *idx = line - 1;
    return ROW_ALT;
  }
  if (line - live < pd->hres->len) {
    *idx = line - live;
    return ROW_HIST;
  }
  return ROW_NONE;
}

static char *build_message(const CalcPriv *pd) {
  const char *ang = (pd->angle && *pd->angle) ? pd->angle : "deg";
  char *up = g_ascii_strup(ang, -1);
  char *eup = g_markup_escape_text(up, -1);
  GString *g = g_string_new(NULL);
  g_string_append_printf(g, "<b>%s</b>", eup);
  if (pd->input && !pd->ok) {
    char *e = g_markup_escape_text(pd->error ? pd->error : "", -1);
    g_string_append_printf(g, "  ·  %s", e);
    g_free(e);
  } else if (live_is_command(pd)) {
    g_string_append(g, "  ·  Enter apply");
  } else {
    g_string_append(g, "  ·  Enter copy  ·  Alt+1 reuse  ·  Alt+2 copy "
                       "number  ·  Shift+Del forget");
  }
  g_free(up);
  g_free(eup);
  return g_string_free(g, FALSE);
}

static gboolean view_out_of_date(const CalcPriv *pd) {
  if (total_rows(pd) != pd->shown_rows) {
    return TRUE;
  }
  char *msg = build_message(pd);
  gboolean diff = g_strcmp0(msg, pd->shown_message) != 0;
  g_free(msg);
  return diff;
}

static gboolean sync_input(CalcPriv *pd, const char *input) {
  if (is_blank(input)) {
    if (pd->input != NULL) {
      clear_result(pd);
      return TRUE;
    }
    return FALSE;
  }
  if (pd->input != NULL && strcmp(pd->input, input) == 0) {
    return FALSE;
  }
  evaluate_input(pd, input);
  return TRUE;
}

static gboolean drop_stale(CalcPriv *pd) {
  if (pd->input == NULL) {
    return FALSE;
  }
  RofiViewState *st = rofi_view_get_active();
  if (st == NULL) {
    return FALSE;
  }
  const char *ui = rofi_view_get_user_input(st);
  if (ui == NULL || !is_blank(ui)) {
    return FALSE;
  }
  clear_result(pd);
  return TRUE;
}

/* ------------------------------------------------------------ actions */

static void spawn_quiet(char **argv, gboolean *ok) {
  GError *err = NULL;
  gboolean r = g_spawn_async(
      NULL, argv, NULL,
      G_SPAWN_SEARCH_PATH | G_SPAWN_STDIN_FROM_DEV_NULL |
          G_SPAWN_STDOUT_TO_DEV_NULL | G_SPAWN_STDERR_TO_DEV_NULL,
      NULL, NULL, NULL, &err);
  g_clear_error(&err);
  if (ok) {
    *ok = r;
  }
}

static void copy_text(const char *text) {
  gboolean ok = FALSE;
  char *wl[] = {"wl-copy", "--", (char *)text, NULL};
  spawn_quiet(wl, &ok);
  char *ns[] = {"notify-send", "-a",  "Sleek Shell",  "--",
                ok ? "Copied" : "Copy failed", (char *)text, NULL};
  spawn_quiet(ns, NULL);
}

static char *bare_number(const char *text) {
  const char *sp = strchr(text, ' ');
  return sp ? g_strndup(text, (gsize)(sp - text)) : g_strdup(text);
}

static void replace_input(char **input, const char *text) {
  g_free(*input);
  *input = g_strdup(text);
}

static char *commit_live(CalcPriv *pd, gboolean bare) {
  JObj *o = request_cmd(pd, "commit", pd->input, NULL);
  char *out;
  if (o != NULL && jtrue(o, "ok") && *jstr(o, "result")) {
    out = g_strdup(bare && *jstr(o, "value") ? jstr(o, "value")
                                             : jstr(o, "result"));
  } else {
    out = g_strdup(bare && pd->value && *pd->value ? pd->value : pd->result);
  }
  jobj_free(o);
  return out;
}

static ModeMode apply_command(CalcPriv *pd, char **input) {
  jobj_free(request_cmd(pd, "commit", pd->input, NULL));
  clear_result(pd);
  refresh_history(pd);
  replace_input(input, "");
  return RELOAD_DIALOG;
}

static ModeMode do_copy(CalcPriv *pd, RowKind kind, unsigned int idx,
                        gboolean bare, char **input) {
  char *text = NULL;
  switch (kind) {
  case ROW_LIVE:
    if (pd->input == NULL || !pd->ok) {
      return RELOAD_DIALOG;
    }
    if (live_is_command(pd)) {
      return apply_command(pd, input);
    }
    text = commit_live(pd, bare);
    break;
  case ROW_ALT: {
    const char *alt = g_ptr_array_index(pd->alts, idx);
    jobj_free(request_cmd(pd, "record", pd->input, alt));
    text = bare ? bare_number(alt) : g_strdup(alt);
    break;
  }
  case ROW_HIST: {
    const char *res = g_ptr_array_index(pd->hres, idx);
    jobj_free(request_cmd(pd, "record", g_ptr_array_index(pd->hexpr, idx),
                          res));
    text = bare ? bare_number(res) : g_strdup(res);
    break;
  }
  default:
    return RELOAD_DIALOG;
  }
  if (text == NULL || *text == '\0') {
    g_free(text);
    return RELOAD_DIALOG;
  }
  copy_text(text);
  g_free(text);
  return MODE_EXIT;
}

static ModeMode do_reuse(CalcPriv *pd, RowKind kind, unsigned int idx,
                         char **input) {
  char *text = NULL;
  switch (kind) {
  case ROW_LIVE:
    if (pd->input == NULL || !pd->ok) {
      return RELOAD_DIALOG;
    }
    if (live_is_command(pd)) {
      return apply_command(pd, input);
    }
    text = commit_live(pd, FALSE);
    break;
  case ROW_ALT: {
    const char *alt = g_ptr_array_index(pd->alts, idx);
    jobj_free(request_cmd(pd, "record", pd->input, alt));
    text = g_strdup(alt);
    break;
  }
  case ROW_HIST:
    text = g_strdup(g_ptr_array_index(pd->hres, idx));
    break;
  default:
    return RELOAD_DIALOG;
  }
  replace_input(input, text);
  refresh_history(pd);
  evaluate_input(pd, text);
  g_free(text);
  return RELOAD_DIALOG;
}

/* ------------------------------------------------------------ mode API */

static char *resolve_script(void) {
  const char *env = g_getenv("SLEEK_CALC_SCRIPT");
  if (env != NULL && *env != '\0') {
    return g_strdup(env);
  }
  if (*SLEEK_CALC_SCRIPT != '\0' &&
      g_file_test(SLEEK_CALC_SCRIPT, G_FILE_TEST_IS_REGULAR)) {
    return g_strdup(SLEEK_CALC_SCRIPT);
  }
  return g_build_filename(g_get_home_dir(), ".local", "share", "sleek-shell",
                          "calc", "sleek_calc.py", NULL);
}

static int calc_init(Mode *sw) {
  if (mode_get_private_data(sw) != NULL) {
    return TRUE;
  }
  if (sw->display_name == NULL) {
    sw->display_name = g_strdup("Calc");
  }
  CalcPriv *pd = g_new0(CalcPriv, 1);
  pd->in_fd = -1;
  pd->out_fd = -1;
  pd->rbuf = g_string_new(NULL);
  pd->script = resolve_script();
  pd->alts = g_ptr_array_new_with_free_func(g_free);
  pd->hres = g_ptr_array_new_with_free_func(g_free);
  pd->hexpr = g_ptr_array_new_with_free_func(g_free);
  pd->angle = g_strdup("deg");
  mode_set_private_data(sw, pd);
  refresh_history(pd);
  return TRUE;
}

static void calc_destroy(Mode *sw) {
  CalcPriv *pd = mode_get_private_data(sw);
  if (pd == NULL) {
    return;
  }
  coproc_stop(pd, TRUE);
  clear_result(pd);
  g_string_free(pd->rbuf, TRUE);
  g_free(pd->script);
  g_free(pd->engine_error);
  g_free(pd->angle);
  g_free(pd->shown_message);
  g_ptr_array_unref(pd->alts);
  g_ptr_array_unref(pd->hres);
  g_ptr_array_unref(pd->hexpr);
  g_free(pd);
  mode_set_private_data(sw, NULL);
}

static unsigned int calc_get_num_entries(const Mode *sw) {
  CalcPriv *pd = mode_get_private_data(sw);
  if (pd == NULL) {
    return 0;
  }
  drop_stale(pd);
  pd->shown_rows = total_rows(pd);
  return pd->shown_rows;
}

static char *calc_get_message(const Mode *sw) {
  CalcPriv *pd = mode_get_private_data(sw);
  if (pd == NULL) {
    return NULL;
  }
  drop_stale(pd);
  char *msg = build_message(pd);
  set_str(&pd->shown_message, msg);
  return msg;
}

static char *calc_preprocess_input(Mode *sw, const char *input) {
  CalcPriv *pd = mode_get_private_data(sw);
  if (pd != NULL && sync_input(pd, input ? input : "") &&
      view_out_of_date(pd)) {
    rofi_view_reload();
  }
  return g_strdup("");
}

static int calc_token_match(G_GNUC_UNUSED const Mode *sw,
                            G_GNUC_UNUSED rofi_int_matcher **tokens,
                            G_GNUC_UNUSED unsigned int index) {
  return TRUE;
}

static char *one_line(const char *s) {
  char *r = g_strdup(s ? s : "");
  for (char *p = r; *p; p++) {
    if (*p == '\n' || *p == '\r' || *p == '\t') {
      *p = ' ';
    }
  }
  return r;
}

static char *calc_get_display_value(const Mode *sw, unsigned int line,
                                    int *state,
                                    G_GNUC_UNUSED GList **attribute_list,
                                    int get_entry) {
  CalcPriv *pd = mode_get_private_data(sw);
  if (pd == NULL) {
    return get_entry ? g_strdup("") : NULL;
  }
  if (drop_stale(pd)) {
    rofi_view_reload();
  }
  unsigned int idx;
  RowKind kind = classify(pd, line, &idx);
  if (kind == ROW_LIVE && !pd->ok) {
    *state |= SC_URGENT;
  } else if (kind == ROW_LIVE && live_is_command(pd)) {
    *state |= SC_ACTIVE;
  }
  if (!get_entry) {
    return NULL;
  }
  char *raw;
  switch (kind) {
  case ROW_LIVE:
    if (!pd->ok) {
      raw = g_strconcat("⚠  ", pd->error ? pd->error : "", NULL);
    } else if (live_is_command(pd)) {
      raw = g_strconcat("↵  ", pd->result, NULL);
    } else {
      raw = g_strconcat("=  ", pd->result, NULL);
    }
    break;
  case ROW_ALT:
    raw = g_strconcat("→  ", (const char *)g_ptr_array_index(pd->alts, idx),
                      NULL);
    break;
  case ROW_HIST: {
    const char *e = g_ptr_array_index(pd->hexpr, idx);
    const char *r = g_ptr_array_index(pd->hres, idx);
    raw = (*e && strcmp(e, r) != 0) ? g_strconcat("↺  ", e, "  =  ", r, NULL)
                                    : g_strconcat("↺  ", r, NULL);
    break;
  }
  default:
    raw = g_strdup("");
  }
  char *out = one_line(raw);
  g_free(raw);
  return out;
}

static char *calc_get_completion(const Mode *sw, unsigned int line) {
  CalcPriv *pd = mode_get_private_data(sw);
  if (pd == NULL) {
    return g_strdup("");
  }
  unsigned int idx;
  switch (classify(pd, line, &idx)) {
  case ROW_LIVE:
    if (pd->ok && !live_is_command(pd)) {
      return g_strdup(pd->result);
    }
    return g_strdup(pd->input ? pd->input : "");
  case ROW_ALT:
    return g_strdup(g_ptr_array_index(pd->alts, idx));
  case ROW_HIST:
    return g_strdup(g_ptr_array_index(pd->hres, idx));
  default:
    return g_strdup(pd->input ? pd->input : "");
  }
}

static ModeMode calc_result(Mode *sw, int mretv, char **input,
                            unsigned int selected_line) {
  CalcPriv *pd = mode_get_private_data(sw);
  if (mretv & MENU_NEXT) {
    return NEXT_DIALOG;
  }
  if (mretv & MENU_PREVIOUS) {
    return PREVIOUS_DIALOG;
  }
  if (mretv & MENU_QUICK_SWITCH) {
    return (ModeMode)(mretv & MENU_LOWER_MASK);
  }
  if ((mretv & MENU_CANCEL) || pd == NULL) {
    return MODE_EXIT;
  }
  sync_input(pd, *input ? *input : "");
  unsigned int idx = 0;
  RowKind kind = classify(pd, selected_line, &idx);

  if (mretv & MENU_ENTRY_DELETE) {
    if (kind == ROW_HIST) {
      char *n = g_strdup_printf("%u", idx);
      jobj_free(request_cmd(pd, "delete", n, NULL));
      g_free(n);
      refresh_history(pd);
    }
    return RELOAD_DIALOG;
  }
  if (mretv & MENU_CUSTOM_COMMAND) {
    int n = mretv & MENU_LOWER_MASK;
    if (kind == ROW_NONE) {
      kind = ROW_LIVE;
    }
    if (n == 0) {
      return do_reuse(pd, kind, idx, input);
    }
    if (n == 1) {
      return do_copy(pd, kind, idx, TRUE, input);
    }
    return RELOAD_DIALOG;
  }
  if (mretv & MENU_CUSTOM_INPUT) {
    if (mretv & MENU_CUSTOM_ACTION) {
      return do_reuse(pd, ROW_LIVE, 0, input);
    }
    return do_copy(pd, ROW_LIVE, 0, FALSE, input);
  }
  if (mretv & MENU_OK) {
    if (mretv & MENU_CUSTOM_ACTION) {
      return do_reuse(pd, kind, idx, input);
    }
    return do_copy(pd, kind, idx, FALSE, input);
  }
  return RELOAD_DIALOG;
}

Mode mode = {
    .abi_version = ABI_VERSION,
    .name = "calc",
    .cfg_name_key = "display-calc",
    .display_name = NULL,
    ._init = calc_init,
    ._destroy = calc_destroy,
    ._get_num_entries = calc_get_num_entries,
    ._result = calc_result,
    ._token_match = calc_token_match,
    ._get_display_value = calc_get_display_value,
    ._get_icon = NULL,
    ._get_completion = calc_get_completion,
    ._preprocess_input = calc_preprocess_input,
    ._get_message = calc_get_message,
    .private_data = NULL,
    .free = NULL,
    .type = MODE_TYPE_SWITCHER,
};
