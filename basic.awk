#!/usr/bin/awk -f
# Tiny BASIC Interpreter in AWK

BEGIN {
    # Initialize numeric variables A-Z to 0, string variables A$-Z$ to ""
    for (i = 65; i <= 90; i++) {
        vars[sprintf("%c", i)]  = 0
        svars[sprintf("%c", i)] = ""
    }

    interactive = 1
    printf "Tiny BASIC Interpreter\n"
    printf "Type HELP for commands.\n\n"
    printf "> "
}

{
    line = $0
    # Strip leading/trailing whitespace
    gsub(/^[ \t]+|[ \t]+$/, "", line)

    if (line == "") {
        printf "> "
        next
    }

    # Check if line starts with a number (program line entry)
    if (match(line, /^[0-9]+/)) {
        linenum = substr(line, RSTART, RLENGTH) + 0
        rest = substr(line, RSTART + RLENGTH)
        gsub(/^[ \t]+/, "", rest)
        if (rest == "") {
            # Delete line
            delete prog[linenum]
        } else {
            prog[linenum] = rest
        }
        printf "> "
        next
    }

    # Direct commands
    cmd = toupper(line)

    if (cmd == "QUIT" || cmd == "EXIT" || cmd == "BYE") {
        exit 0
    } else if (cmd == "NEW") {
        delete prog
        delete vars
        delete svars
        for (i = 65; i <= 90; i++) {
            vars[sprintf("%c", i)]  = 0
            svars[sprintf("%c", i)] = ""
        }
        delete arrays
        delete arr_size
        printf "OK\n> "
    } else if (cmd == "LIST") {
        do_list()
        printf "> "
    } else if (cmd == "RUN") {
        do_run()
        printf "> "
    } else if (cmd == "HELP") {
        printf "Commands: NEW, LIST, RUN, LOAD filename, SAVE filename, QUIT\n"
        printf "Statements: PRINT, LET, INPUT, GOTO, IF..THEN, END, DIM, REM\n"
        printf "Numeric vars: A-Z    String vars: A$-Z$\n"
        printf "Enter lines with a line number to add to program.\n"
        printf "Enter a line number alone to delete that line.\n"
        printf "> "
    } else if (substr(cmd, 1, 4) == "LOAD") {
        fname = substr(line, 5)
        gsub(/^[ \t]+|[ \t]+$/, "", fname)
        do_load(fname)
        printf "> "
    } else if (substr(cmd, 1, 4) == "SAVE") {
        fname = substr(line, 5)
        gsub(/^[ \t]+|[ \t]+$/, "", fname)
        do_save(fname)
        printf "> "
    } else {
        # Try to execute as a direct statement
        err = exec_stmt(line)
        if (err != "") printf "ERROR: %s\n", err
        printf "> "
    }
}

function do_list(    n, i, sorted) {
    n = sort_line_nums(sorted)
    for (i = 1; i <= n; i++)
        printf "%d %s\n", sorted[i], prog[sorted[i]]
}

function do_save(fname,    n, i, sorted) {
    if (fname == "") { printf "ERROR: No filename\n"; return }
    n = sort_line_nums(sorted)
    for (i = 1; i <= n; i++)
        printf "%d %s\n", sorted[i], prog[sorted[i]] > fname
    close(fname)
    printf "OK\n"
}

function do_load(fname,    linetext, linenum, rest) {
    if (fname == "") { printf "ERROR: No filename\n"; return }
    delete prog
    while ((getline linetext < fname) > 0) {
        if (match(linetext, /^[0-9]+/)) {
            linenum = substr(linetext, RSTART, RLENGTH) + 0
            rest = substr(linetext, RSTART + RLENGTH)
            gsub(/^[ \t]+/, "", rest)
            if (rest != "")
                prog[linenum] = rest
        }
    }
    close(fname)
    printf "OK\n"
}

function do_run(    n, i, sorted, pc, stmt, err) {
    # Reset variables
    for (i = 65; i <= 90; i++) {
        vars[sprintf("%c", i)]  = 0
        svars[sprintf("%c", i)] = ""
    }
    delete arrays

    n = sort_line_nums(sorted)
    if (n == 0) return

    # Build index: linenum -> position in sorted array
    for (i = 1; i <= n; i++)
        line_index[sorted[i]] = i

    pc = 1  # index into sorted array
    while (pc >= 1 && pc <= n) {
        current_line = sorted[pc]
        stmt = prog[sorted[pc]]
        next_pc = pc + 1

        err = exec_stmt(stmt)
        if (err == "END") break
        if (err == "GOTO") {
            if (goto_target in line_index) {
                pc = line_index[goto_target]
                continue
            } else {
                printf "ERROR at line %d: Invalid GOTO target %d\n", current_line, goto_target
                break
            }
        }
        if (err != "") {
            printf "ERROR at line %d: %s\n", current_line, err
            break
        }
        pc = next_pc
    }
    delete line_index
}

# Execute a single statement. Returns "" on success, error message on failure.
# Returns "END" for END statement, "GOTO" for GOTO (sets goto_target).
function exec_stmt(stmt,    cmd, rest) {
    gsub(/^[ \t]+/, "", stmt)

    # Extract first keyword
    if (match(stmt, /^[A-Za-z]+/)) {
        cmd = toupper(substr(stmt, RSTART, RLENGTH))
        rest = substr(stmt, RSTART + RLENGTH)
        gsub(/^[ \t]+/, "", rest)
    } else {
        return "Syntax error"
    }

    if (cmd == "PRINT") return do_print(rest)
    if (cmd == "LET")   return do_let(rest)
    if (cmd == "INPUT") return do_input(rest)
    if (cmd == "GOTO")  return do_goto(rest)
    if (cmd == "IF")    return do_if(rest)
    if (cmd == "END")   return "END"
    if (cmd == "DIM")   return do_dim(rest)
    if (cmd == "REM")   return ""

    return "Unknown command: " cmd
}

# ---------------------------------------------------------------------------
# PRINT  –  handles string literals, string variables (A$), numeric exprs,
#           comma (separator) and semicolon (suppress newline).
# ---------------------------------------------------------------------------
function do_print(rest,    val, ch, str_val, vname, need_newline) {
    need_newline = 1
    while (rest != "") {
        gsub(/^[ \t]+/, "", rest)
        if (rest == "") break

        ch = substr(rest, 1, 1)

        if (ch == "\"") {
            # ---- string literal ----
            rest = substr(rest, 2)
            str_val = ""
            while (rest != "") {
                ch = substr(rest, 1, 1)
                rest = substr(rest, 2)
                if (ch == "\"") break
                str_val = str_val ch
            }
            printf "%s", str_val

        } else if (ch == ",") {
            rest = substr(rest, 2)
            continue

        } else if (ch == ";") {
            rest = substr(rest, 2)
            need_newline = 0
            continue

        } else if ((ch >= "A" && ch <= "Z" || ch >= "a" && ch <= "z") &&
                   substr(rest, 2, 1) == "$") {
            # ---- string variable (e.g. A$) ----
            vname = toupper(ch)
            rest  = substr(rest, 3)
            printf "%s", svars[vname]

        } else {
            # ---- numeric expression ----
            val  = parse_expr(rest)
            rest = _rest
            printf "%d", val
        }
        need_newline = 1
    }
    if (need_newline) printf "\n"
    return ""
}

# ---------------------------------------------------------------------------
# LET  –  numeric:  LET A  = <expr>
#          array:   LET A(i) = <expr>
#          string:  LET A$ = "<literal>" | B$
# ---------------------------------------------------------------------------
function do_let(rest,    vname, idx, val, sval) {
    gsub(/^[ \t]+/, "", rest)
    vname = toupper(substr(rest, 1, 1))

    if (vname < "A" || vname > "Z") return "Invalid variable"

    rest = substr(rest, 2)
    gsub(/^[ \t]+/, "", rest)

    # ---- string variable ----
    if (substr(rest, 1, 1) == "$") {
        rest = substr(rest, 2)
        gsub(/^[ \t]+/, "", rest)
        if (substr(rest, 1, 1) != "=") return "Missing ="
        rest = substr(rest, 2)
        gsub(/^[ \t]+/, "", rest)
        sval = parse_string_expr(rest)
        svars[vname] = sval
        return ""
    }

    # ---- array element ----
    if (substr(rest, 1, 1) == "(") {
        rest = substr(rest, 2)
        idx  = parse_expr(rest)
        rest = _rest
        gsub(/^[ \t]+/, "", rest)
        if (substr(rest, 1, 1) != ")") return "Missing )"
        rest = substr(rest, 2)
        gsub(/^[ \t]+/, "", rest)
        if (substr(rest, 1, 1) != "=") return "Missing ="
        rest = substr(rest, 2)
        val  = parse_expr(rest)
        arrays[vname, idx] = val
        return ""
    }

    # ---- numeric variable ----
    if (substr(rest, 1, 1) != "=") return "Missing ="
    rest = substr(rest, 2)
    val  = parse_expr(rest)
    vars[vname] = int(val)
    return ""
}

# ---------------------------------------------------------------------------
# INPUT  –  reads a value from the user.
#   Syntax:  INPUT [<"prompt">,] varname[$]
#   Examples:
#     INPUT A
#     INPUT A$
#     INPUT "Enter name: ", N$
#     INPUT "Enter age: ", A
# ---------------------------------------------------------------------------
function do_input(rest,    prompt, ch, vname, sval, val) {
    gsub(/^[ \t]+/, "", rest)

    # Default prompt
    prompt = "? "

    # Optional quoted prompt string
    if (substr(rest, 1, 1) == "\"") {
        rest   = substr(rest, 2)
        prompt = ""
        while (rest != "") {
            ch   = substr(rest, 1, 1)
            rest = substr(rest, 2)
            if (ch == "\"") break
            prompt = prompt ch
        }
        gsub(/^[ \t]+/, "", rest)
        # Skip optional comma or semicolon between prompt and variable
        if (substr(rest, 1, 1) == "," || substr(rest, 1, 1) == ";") {
            rest = substr(rest, 2)
        }
        gsub(/^[ \t]+/, "", rest)
    }

    # Variable name (single letter)
    if (rest == "") return "Missing variable"
    vname = toupper(substr(rest, 1, 1))
    if (vname < "A" || vname > "Z") return "Invalid variable name"
    rest = substr(rest, 2)
    gsub(/^[ \t]+/, "", rest)

    # ---- string variable ----
    if (substr(rest, 1, 1) == "$") {
        printf "%s", prompt
        if ((getline sval) <= 0) sval = ""
        svars[vname] = sval
        return ""
    }

    # ---- numeric variable ----
    printf "%s", prompt
    if ((getline val) <= 0) val = 0
    vars[vname] = int(val + 0)
    return ""
}

# ---------------------------------------------------------------------------
# parse_string_expr  –  parses the RHS of a string assignment.
#   Handles:  "literal"   or   B$
#   Sets _rest to whatever follows the parsed token.
# ---------------------------------------------------------------------------
function parse_string_expr(s,    ch, sval, vname) {
    gsub(/^[ \t]+/, "", s)
    ch = substr(s, 1, 1)

    # String literal
    if (ch == "\"") {
        s    = substr(s, 2)
        sval = ""
        while (s != "") {
            ch = substr(s, 1, 1)
            s  = substr(s, 2)
            if (ch == "\"") break
            sval = sval ch
        }
        _rest = s
        return sval
    }

    # String variable reference (e.g. B$)
    if ((ch >= "A" && ch <= "Z") || (ch >= "a" && ch <= "z")) {
        vname = toupper(ch)
        s = substr(s, 2)
        if (substr(s, 1, 1) == "$") {
            s = substr(s, 2)
            _rest = s
            return svars[vname]
        }
        # Treat as bare letter – put it back and return empty
        _rest = ch s
        return ""
    }

    _rest = s
    return ""
}

function do_goto(rest,    val) {
    val = parse_expr(rest)
    goto_target = int(val)
    return "GOTO"
}

function do_if(rest,    val, pos, cond_part, then_part) {
    pos = find_then(rest)
    if (pos == 0) return "Missing THEN"

    cond_part = substr(rest, 1, pos - 1)
    then_part = substr(rest, pos + 4)
    gsub(/^[ \t]+/, "", then_part)

    val = parse_expr(cond_part)

    if (val != 0) {
        # THEN followed by a bare line number -> implicit GOTO
        if (match(then_part, /^[0-9]+$/)) {
            goto_target = int(then_part)
            return "GOTO"
        }
        return exec_stmt(then_part)
    }
    return ""
}

function find_then(s,    i, upr) {
    upr = toupper(s)
    i   = index(upr, "THEN")
    return (i > 0) ? i : 0
}

function do_dim(rest,    vname, size, i) {
    gsub(/^[ \t]+/, "", rest)
    vname = toupper(substr(rest, 1, 1))
    if (vname < "A" || vname > "Z") return "Invalid array name"
    rest = substr(rest, 2)
    gsub(/^[ \t]+/, "", rest)
    if (substr(rest, 1, 1) != "(") return "Missing ("
    rest = substr(rest, 2)
    size = parse_expr(rest)
    rest = _rest
    gsub(/^[ \t]+/, "", rest)
    if (substr(rest, 1, 1) != ")") return "Missing )"
    arr_size[vname] = int(size)
    for (i = 0; i < size; i++)
        arrays[vname, i] = 0
    return ""
}

# ---- Expression Parser (recursive descent) ----
# Uses global _rest to return remaining input after parsing.

function parse_expr(s,    left, op, right) {
    gsub(/^[ \t]+/, "", s)
    left = parse_add(s)
    s    = _rest
    gsub(/^[ \t]+/, "", s)

    while (1) {
        if (substr(s, 1, 2) == "<>") {
            op    = "<>"
            s     = substr(s, 3)
            right = parse_add(s); s = _rest
            left  = (left != right) ? 1 : 0
        } else if (substr(s, 1, 2) == "<=") {
            s     = substr(s, 3)
            right = parse_add(s); s = _rest
            left  = (left <= right) ? 1 : 0
        } else if (substr(s, 1, 2) == ">=") {
            s     = substr(s, 3)
            right = parse_add(s); s = _rest
            left  = (left >= right) ? 1 : 0
        } else if (substr(s, 1, 1) == "=") {
            s     = substr(s, 2)
            right = parse_add(s); s = _rest
            left  = (left == right) ? 1 : 0
        } else if (substr(s, 1, 1) == "<") {
            s     = substr(s, 2)
            right = parse_add(s); s = _rest
            left  = (left < right) ? 1 : 0
        } else if (substr(s, 1, 1) == ">") {
            s     = substr(s, 2)
            right = parse_add(s); s = _rest
            left  = (left > right) ? 1 : 0
        } else {
            break
        }
        gsub(/^[ \t]+/, "", s)
    }
    _rest = s
    return int(left)
}

function parse_add(s,    left, op, right) {
    gsub(/^[ \t]+/, "", s)
    left = parse_mul(s)
    s    = _rest
    gsub(/^[ \t]+/, "", s)

    while (substr(s, 1, 1) == "+" || substr(s, 1, 1) == "-") {
        op    = substr(s, 1, 1)
        s     = substr(s, 2)
        right = parse_mul(s); s = _rest
        left  = (op == "+") ? left + right : left - right
        gsub(/^[ \t]+/, "", s)
    }
    _rest = s
    return left
}

function parse_mul(s,    left, op, right) {
    gsub(/^[ \t]+/, "", s)
    left = parse_unary(s)
    s    = _rest
    gsub(/^[ \t]+/, "", s)

    while (substr(s, 1, 1) == "*" || substr(s, 1, 1) == "/" || substr(s, 1, 1) == "%") {
        op    = substr(s, 1, 1)
        s     = substr(s, 2)
        right = parse_unary(s); s = _rest
        if (op == "*") {
            left = left * right
        } else if (op == "/") {
            if (right == 0) { printf "Division by zero\n"; left = 0 }
            else left = int(left / right)
        } else {
            if (right == 0) { printf "Modulo by zero\n"; left = 0 }
            else left = left % right
        }
        gsub(/^[ \t]+/, "", s)
    }
    _rest = s
    return left
}

function parse_unary(s,    ch, val) {
    gsub(/^[ \t]+/, "", s)
    ch = substr(s, 1, 1)
    if (ch == "-") {
        s   = substr(s, 2)
        val = parse_atom(s)
        return -val
    }
    if (ch == "+") s = substr(s, 2)
    return parse_atom(s)
}

function parse_atom(s,    ch, num, vname, idx) {
    gsub(/^[ \t]+/, "", s)
    ch = substr(s, 1, 1)

    # Number
    if (ch >= "0" && ch <= "9") {
        num = 0
        while (ch >= "0" && ch <= "9") {
            num = num * 10 + (ch + 0)
            s   = substr(s, 2)
            ch  = substr(s, 1, 1)
        }
        _rest = s
        return int(num)
    }

    # Parenthesized expression
    if (ch == "(") {
        s   = substr(s, 2)
        val = parse_expr(s)
        s   = _rest
        gsub(/^[ \t]+/, "", s)
        if (substr(s, 1, 1) == ")") s = substr(s, 2)
        _rest = s
        return val
    }

    # Variable or array access
    if ((ch >= "A" && ch <= "Z") || (ch >= "a" && ch <= "z")) {
        vname = toupper(ch)
        s     = substr(s, 2)
        gsub(/^[ \t]+/, "", s)
        # Array element
        if (substr(s, 1, 1) == "(") {
            s   = substr(s, 2)
            idx = parse_expr(s)
            s   = _rest
            gsub(/^[ \t]+/, "", s)
            if (substr(s, 1, 1) == ")") s = substr(s, 2)
            _rest = s
            return int(arrays[vname, int(idx)])
        }
        _rest = s
        return int(vars[vname])
    }

    # Unknown token – return 0
    _rest = s
    return 0
}

# Sort program line numbers into an array, return count
function sort_line_nums(sorted,    n, i, j, tmp, k) {
    n = 0
    for (k in prog) {
        n++
        sorted[n] = k + 0
    }
    # Insertion sort
    for (i = 2; i <= n; i++) {
        tmp = sorted[i]
        j   = i - 1
        while (j >= 1 && sorted[j] > tmp) {
            sorted[j + 1] = sorted[j]
            j--
        }
        sorted[j + 1] = tmp
    }
    return n
}
