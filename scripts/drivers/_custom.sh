#!/usr/bin/env sh

_sed_i() {
    # MacOS syntax is different for in-place
    if [ "$(uname)" = "Darwin" ]; then
        sed -i "" "$@"
    else
        sed -i "$@"
    fi
}

_regex_escape() {
    # This is a function because dealing with quotes is a pain.
    # http://stackoverflow.com/a/2705678/120999
    sed -e 's/[]\/()$*.^|[]/\\&/g'
}

_custom_driver_is_yaml() {
    false
}

_custom_driver_get_secret() {
    echo "Please override function '_custom_driver_get_secret' in your driver!" >&2
    exit 1
}

driver_is_file_encrypted() {
    input="${1}"

    grep -q -e "${_DRIVER_REGEX}" "${input}"
}

driver_encrypt_file() {
    echo "Encrypting files is not supported!"
    exit 1
}

driver_decrypt_file() {
    type="${1}"
    input="${2}"
    # if omit then output to stdout
    output="${3:-}"

    input_tmp="$(mktemp)"
    output_tmp="$(mktemp)"
    cp "${input}" "${input_tmp}"

    # Grab all patterns, deduplicate and pass it to loop
    # https://github.com/koalaman/shellcheck/wiki/SC2013
    if ! grep -o -e "${_DRIVER_REGEX}" "${input}" | sort | uniq | while IFS= read -r EXPRESSION; do
        # remove prefix
        _SECRET="${EXPRESSION#* }"

        if ! SECRET=$(_custom_driver_get_secret "${type}" "${_SECRET}"); then
            exit 1
        fi

        # generate yaml anchor name
        YAML_ANCHOR=$(printf 'helm-secret-%s' "${_SECRET}" | tr '#$/' '_')

        # Replace vault expression with yaml anchor
        EXPRESSION="$(echo "${EXPRESSION}" | _regex_escape)"
        _sed_i "s/${EXPRESSION}/*${YAML_ANCHOR}/g" "${input_tmp}"

        if _custom_driver_is_yaml "${type}" "${_SECRET}"; then
            {
                printf '.%s: &%s\n' "${YAML_ANCHOR}" "${YAML_ANCHOR}"
                printf '%s\n\n' "${SECRET}" | sed -e 's/^/  /g'
            } >>"${output_tmp}"
        else
            {
                printf '.%s: &%s ' "${YAML_ANCHOR}" "${YAML_ANCHOR}"
                printf '%s\n\n' "${SECRET}"
            } >>"${output_tmp}"
        fi
    done; then
        # pass exit from pipe/sub shell to main shell
        exit 1
    fi

    if [ "${output}" = "" ]; then
        cat "${output_tmp}" "${input_tmp}"
    else
        cat "${output_tmp}" "${input_tmp}" >"${output}"
    fi
}

driver_edit_file() {
    echo "Editing files is not supported!"
    exit 1
}
