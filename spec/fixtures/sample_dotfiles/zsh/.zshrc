# Sample .zshrc file for testing
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

plugins=(git brew macos)

source $ZSH/oh-my-zsh.sh

# Test aliases
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'

# Test environment variables
export EDITOR=vim
export BROWSER=firefox

# This is a test zsh configuration
