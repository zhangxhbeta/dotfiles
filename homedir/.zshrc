# Path to your oh-my-zsh configuration.
export ZSH=$HOME/.dotfiles/oh-my-zsh
# if you want to use this, change your non-ascii font to Droid Sans Mono for Awesome
# export ZSH_THEME="muse"
export ZSH_THEME="powerlevel9k/powerlevel9k"

POWERLEVEL9K_MODE='nerdfont-complete'
POWERLEVEL9K_SHORTEN_DIR_LENGTH=3
POWERLEVEL9K_DISABLE_RPROMPT=true
POWERLEVEL9K_PROMPT_ON_NEWLINE=true
POWERLEVEL9K_VCS_GIT_BITBUCKET_ICON=$'\uE703'
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(custom_proxy dir vcs)
POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR=''
POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR=' '
POWERLEVEL9K_WHITESPACE_BETWEEN_LEFT_SEGMENTS=''

POWERLEVEL9K_DIR_ETC_BACKGROUND='none'
POWERLEVEL9K_DIR_ETC_FOREGROUND='005'
POWERLEVEL9K_DIR_HOME_BACKGROUND='none'
POWERLEVEL9K_DIR_HOME_FOREGROUND='004'
POWERLEVEL9K_DIR_DEFAULT_BACKGROUND='none'
POWERLEVEL9K_DIR_DEFAULT_FOREGROUND='005'
POWERLEVEL9K_DIR_HOME_SUBFOLDER_BACKGROUND='none'
POWERLEVEL9K_DIR_HOME_SUBFOLDER_FOREGROUND='004'
POWERLEVEL9K_HOME_ICON="\uf46d $HOME"

POWERLEVEL9K_SHOW_CHANGESET=true
POWERLEVEL9K_CHANGESET_HASH_LENGTH=6
POWERLEVEL9K_VCS_CLEAN_BACKGROUND='none'
POWERLEVEL9K_VCS_CLEAN_FOREGROUND='076'
POWERLEVEL9K_VCS_UNTRACKED_BACKGROUND='none'
POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND='005'
POWERLEVEL9K_VCS_MODIFIED_BACKGROUND='none'
POWERLEVEL9K_VCS_MODIFIED_FOREGROUND='003'

POWERLEVEL9K_CUSTOM_PROXY="echo \$(if [ -z \${http_proxy+x} ]; then echo ''; else echo \"\uf983\"; fi)"
POWERLEVEL9K_CUSTOM_PROXY_BACKGROUND='none'
POWERLEVEL9K_CUSTOM_PROXY_FOREGROUND="yellow"

# colorcode test
# for code ({000..255}) print -P -- "$code: %F{$code}This is how your text would look like%f"

# Set to this to use case-sensitive completion
# export CASE_SENSITIVE="true"

# disable weekly auto-update checks
# export DISABLE_AUTO_UPDATE="true"

# disable colors in ls
# export DISABLE_LS_COLORS="true"

# disable autosetting terminal title.
export DISABLE_AUTO_TITLE="true"

# Which plugins would you like to load? (plugins can be found in ~/.dotfiles/oh-my-zsh/plugins/*)
# Example format: plugins=(rails git textmate ruby lighthouse)
plugins=(colorize compleat dirpersist history git cp)

source $ZSH/oh-my-zsh.sh

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

#source /usr/local/opt/nvm/nvm.sh

#autoload -U add-zsh-hook
#load-nvmrc() {
#  if [[ -f .nvmrc && -r .nvmrc ]]; then
#    nvm use &> /dev/null
#  elif [[ $(nvm version) != $(nvm version default)  ]]; then
#    nvm use default &> /dev/null
#  fi
#}
#add-zsh-hook chpwd load-nvmrc
#load-nvmrc

# Customize to your needs...
unsetopt correct
DISABLE_UNTRACKED_FILES_DIRTY="true"

# run fortune on new terminal :)
# fortune

# init rbenv
if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi


# init pyenv
if which pyenv-virtualenv-init > /dev/null; then eval "$(pyenv virtualenv-init -)"; fi


bindkey "^P" up-line-or-search
bindkey "^N" down-line-or-search

. $HOME/.asdf/asdf.sh
. $HOME/.asdf/completions/asdf.bash

[ -f /usr/local/etc/profile.d/autojump.sh ] && . /usr/local/etc/profile.d/autojump.sh

