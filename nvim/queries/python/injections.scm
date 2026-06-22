;; extends

; Highlight SQL embedded in a Python string that begins with a `--sql` marker:
;
;   query = """--sql
;       SELECT * FROM users
;   """
;
; The `--sql` line is itself a valid SQL comment, so it highlights cleanly.
((string (string_content) @injection.content)
  (#lua-match? @injection.content "^%-%-%s*sql")
  (#set! injection.language "sql"))
