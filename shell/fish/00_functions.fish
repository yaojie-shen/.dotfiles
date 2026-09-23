# Fish counterpart of shell/common/00_functions.sh; keep the two in sync.

function proxy_on
    if test -z "$argv[1]"
        echo "Error: No proxy address provided."
        echo "Usage: proxy_on <proxy_address> [no_proxy_list]"
        return
    end

    set -gx HTTP_PROXY $argv[1]
    set -gx http_proxy $HTTP_PROXY
    set -gx HTTPS_PROXY $HTTP_PROXY
    set -gx https_proxy $HTTPS_PROXY
    set -gx FTP_PROXY $HTTP_PROXY
    set -gx ftp_proxy $FTP_PROXY
    set -gx SOCKS_PROXY $HTTP_PROXY
    set -gx socks_proxy $SOCKS_PROXY

    if test -n "$argv[2]"
        set -gx NO_PROXY $argv[2]
    else
        set -gx NO_PROXY localhost,127.0.0.1
    end

    env | grep -e _PROXY | sort
    echo -e "\nProxy-related environment variables set."
end

function proxy_off
    for v in HTTP_PROXY HTTPS_PROXY FTP_PROXY SOCKS_PROXY NO_PROXY \
            http_proxy https_proxy ftp_proxy socks_proxy no_proxy
        set -e $v
    end

    env | grep -e _PROXY | sort
    echo -e "\nProxy-related environment variables removed."
end

function source_env
    # Fish has no caller-local scope a function could write into, so --local
    # sets unexported shell variables instead.
    set -l scope -gx
    set -l help "Usage: source_env [OPTION]... FILE
Load environment variables from FILE.

Options:
  --local            Set variables without exporting them.
  --global           Export variables to the global environment (default).
  --export           Use 'export' to set variables globally.
  --help             Display this help and exit.

FILE must contain key=value pairs, one per line."

    while set -q argv[1]
        switch $argv[1]
            case --local
                set scope -g
            case --global --export
                set scope -gx
            case --help
                echo $help
                return 0
            case '-*'
                echo "Error: Unknown option: $argv[1]" >&2
                echo $help
                return 1
            case '*'
                break
        end
        set -e argv[1]
    end

    set -l file $argv[1]
    if test -z "$file"; or not test -f "$file"
        echo "Error: File not found or not specified: $file" >&2
        echo $help
        return 1
    end

    echo "Environment variables loaded from '$file':"
    while read -l line
        if test -z "$line"; or string match -q '#*' -- $line
            continue
        end

        set -l kv (string split -m1 = -- $line)
        if test -n "$kv[1]"; and test -n "$kv[2]"
            set $scope $kv[1] $kv[2]
            echo "$kv[1]=$kv[2]"
        else
            echo "Warning: Skipped invalid line: $line" >&2
        end
    end <$file
end

# Run python script from url
# Usage:
#   python_from_url <url> <param-1> <param-2>...
function python_from_url
    if test -z "$argv[1]"
        echo "Error: No url provided."
        echo "Usage: python_from_url <url> <param-1> <param-2> ..."
        return
    end
    wget -qO- $argv[1] | python - $argv[2..-1]
end

function lsl
    ls $argv | less
end

function lsc
    command ls $argv | wc -l | tr -d ' '
end

function catc
    command cat $argv | wc -l | tr -d ' '
end

function append_pythonpath
    if test -z "$argv[1]"
        set -l p (pwd)
        set -gx PYTHONPATH $p $PYTHONPATH
        echo "Append $p to PYTHONPATH"
    else
        set -gx PYTHONPATH $PYTHONPATH $argv[1]
        echo "Append $argv[1] to PYTHONPATH"
    end
end

# Append a directory to PATH if not already present.
# Usage: append_path [DIR]
# If DIR is omitted, uses the current working directory.
function append_path
    set -l dir $argv[1]
    test -z "$dir"; and set dir (pwd)

    # Expand leading ~ to $HOME and remove trailing slash
    set dir (string replace -r '^~' -- $HOME $dir)
    set dir (string replace -r '/$' '' -- $dir)

    if test -z "$dir"
        echo "Error: empty directory specified" >&2
        return 1
    end

    if not test -d "$dir"
        echo "Warning: directory does not exist: $dir" >&2
        # continue — user may want to add non-existing path
    end

    if contains -- $dir $PATH
        echo "PATH already contains $dir"
        return 0
    end

    set -gx PATH $PATH $dir
    echo "Appended $dir to PATH"
end

# Set IPython as the default debugger
# Note: Only valid since python 3.7
function set_ipython
    if not python3 -c "import IPython" &>/dev/null
        echo -e "\033[31mIPython not found, installing...\033[0m"
        pip3 install ipython
    end
    set -gx PYTHONBREAKPOINT IPython.embed
end

function unset_ipython
    set -e PYTHONBREAKPOINT
end

function set_gpu
    set -l input $argv[1]
    set -l output ""

    if test -z "$input"
        # empty, disable all gpu (cpu-only)
        set output ""
    else if string match -qr '^[0-9]+-[0-9]+$' -- $input
        # range
        set -l bounds (string split -- - $input)
        if test $bounds[1] -gt $bounds[2]
            echo "Invalid range: start must be <= end"
            return 1
        end
        set output (string join , (seq $bounds[1] $bounds[2]))
    else if string match -qr '^[0-9]+(,[0-9]+)*$' -- $input
        # integer or comma-separated integers
        set output $input
    else
        echo "Invalid input: \"$input\" (must be integer, range or comma-separated integers)"
        return 1
    end

    set -gx CUDA_VISIBLE_DEVICES "$output"
    echo "Set CUDA_VISIBLE_DEVICES=\"$output\""
end

function unset_gpu
    set -e CUDA_VISIBLE_DEVICES
    echo "Unset CUDA_VISIBLE_DEVICES"
end

function get_gpu
    echo "$CUDA_VISIBLE_DEVICES"
end

# Show GPU usage.
function g
    if command -q nvitop
        nvitop
        return
    end
    echo "nvitop not found"

    # Fallback to use nvtop
    if command -q nvtop
        nvtop
        return
    end
    echo "nvtop not found"

    # Fallback to use nvidia-smi
    if command -q nvidia-smi
        watch -n 1 nvidia-smi
        return
    end
    echo "nvidia-smi not found"

    return 1
end
