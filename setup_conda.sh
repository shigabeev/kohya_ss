#!/usr/bin/env bash

# Function to display help information
display_help() {
    cat << EOF
Usage: ${0##*/} [-h] [-b branch] [-d dir] [-g git-repo] [-i] [-n] [-p] [-r] [-s] [-u] [-v]
Setup script for kohya_ss repository.

    -h          display this help and exit
    -b branch   specify the git branch to use
    -d dir      specify the installation directory
    -g git-repo specify the git repository to clone
    -i          interactive mode
    -n          skip git update
    -p          public mode
    -r          runpod mode
    -s          skip space check
    -u          skip GUI
    -v          increase verbosity
EOF
}

# Parse command-line options
while getopts ":hb:d:g:inprusv" opt; do
    case $opt in
        h) display_help && exit 0 ;;
        b) BRANCH="$OPTARG" ;;
        d) DIR="$OPTARG" ;;
        g) GIT_REPO="$OPTARG" ;;
        i) INTERACTIVE=true ;;
        n) SKIP_GIT_UPDATE=true ;;
        p) PUBLIC=true ;;
        r) RUNPOD=true ;;
        s) SKIP_SPACE_CHECK=true ;;
        u) SKIP_GUI=true ;;
        v) ((VERBOSITY = VERBOSITY + 1)) ;;
        *) display_help && exit 1 ;;
    esac
done
shift $((OPTIND - 1))

# Ensure DIR is an absolute path
if [[ "$DIR" != /* ]] && [[ "$DIR" != ~* ]]; then
    DIR="$( cd "$(dirname "$DIR")" || exit 1; pwd )/$(basename "$DIR")"
fi

# Create the conda environment
echo "Creating conda environment..."
if ! command -v conda >/dev/null; then
    echo "Conda not found. Please install conda first."
    exit 1
fi

# CONDA_ENV_NAME="kohya"
# conda create -y -n "$CONDA_ENV_NAME" python=3.10
# source "$(conda info --base)/etc/profile.d/conda.sh"
# conda activate "$CONDA_ENV_NAME"

# Install Python dependencies
echo "Installing Python dependencies..."
pip install -r requirements.txt

# Function to update Kohya_SS repo
update_kohya_ss() {
    if [ "$SKIP_GIT_UPDATE" = false ]; then
        if command -v git >/dev/null; then
            if [ "$(git -C "$DIR" status --porcelain=v1 2>/dev/null | wc -l)" -gt 0 ]; then
                echo "There are changes that need to be committed or discarded in the repo in $DIR."
                exit 1
            fi
            if [ ! -d "$DIR/.git" ]; then
                git -C "$PARENT_DIR" clone -b "$BRANCH" "$GIT_REPO" "$(basename "$DIR")"
                git -C "$DIR" switch "$BRANCH"
            else
                git -C "$DIR" pull "$GIT_REPO" "$BRANCH"
                git -C "$DIR" switch "$BRANCH"
            fi
        else
            echo "You need to install git."
            exit 1
        fi
    else
        echo "Skipping git operations."
    fi
}

# Function to configure accelerate
configure_accelerate() {
    echo "Configuring accelerate..."
    if [ "$INTERACTIVE" = true ]; then
        accelerate config
    else
        if env_var_exists HF_HOME; then
            if [ ! -f "$HF_HOME/accelerate/default_config.yaml" ]; then
                mkdir -p "$HF_HOME/accelerate/"
                cp "$DIR/config_files/accelerate/default_config.yaml" "$HF_HOME/accelerate/default_config.yaml"
            fi
        elif env_var_exists XDG_CACHE_HOME; then
            if [ ! -f "$XDG_CACHE_HOME/huggingface/accelerate" ]; then
                mkdir -p "$XDG_CACHE_HOME/huggingface/accelerate"
                cp "$DIR/config_files/accelerate/default_config.yaml" "$XDG_CACHE_HOME/huggingface/accelerate/default_config.yaml"
            fi
        else
            echo "Could not place the accelerate configuration file. Please configure manually."
            sleep 2
            accelerate config
        fi
    fi
}

# Main script execution
update_kohya_ss
configure_accelerate

echo "Setup finished! Run ./gui.sh to start."