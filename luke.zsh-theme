# vim:ft=zsh ts=2 sw=2 sts=2
#
# agnoster's Theme - https://gist.github.com/3712874
# A Powerline-inspired theme for ZSH
#
# Forked by rjorgenson - http://github.com/rjorgenson
#
# # README
#
# In order for this theme to render correctly, you will need a
# [Powerline-patched font](https://github.com/Lokaltog/powerline-fonts).
# Make sure you have a recent version: the code points that Powerline
# uses changed in 2012, and older versions will display incorrectly,
# in confusing ways.
#
# In addition, I recommend the
# [Solarized theme](https://github.com/altercation/solarized/) and, if you're
# using it on Mac OS X, [iTerm 2](http://www.iterm2.com/) over Terminal.app -
# it has significantly better color fidelity.
#
# # Goals
#
# The aim of this theme is to only show you *relevant* information. Like most
# prompts, it will only show git information when in a git working directory.
# However, it goes a step further: everything from the current user and
# hostname to whether the last call exited with an error to whether background
# jobs are running in this shell will all be displayed automatically when
# appropriate.

### Segment drawing
# A few utility functions to make it easy and re-usable to draw segmented prompts
#
## Thanks for these! They helped a lot - rj

CURRENT_BG='NONE'
PRIMARY_FG=black

# Characters
SEGMENT_SEPARATOR="\ue0b0"
RSEGMENT_SEPARATOR="\ue0b2"
PLUSMINUS="\u00b1"
BRANCH="\ue0a0"
DETACHED="\u27a6"
CROSS="\u2718"
LIGHTNING="\u26a1"
GEAR="\u2699"

# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    echo -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
  else
    echo -n "%{$bg%}%{$fg%} "
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && echo -n $3
}

# Begin an RPROMPT segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
rprompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    echo -n " %{%K{$CURRENT_BG}%F{$1}%}$RSEGMENT_SEPARATOR%{$bg%}%{$fg%} "
  else
    echo -n "%F{$1}%{%K{default}%}$RSEGMENT_SEPARATOR%{$bg%}%{$fg%} "
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && echo -n $3
}

# End the prompt, closing any open segments
prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    echo -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
  else
    echo -n "%{%k%}"
  fi
  echo -n "%{%f%}"
  CURRENT_BG=''
}

### Prompt components
# Each component will draw itself, and hide itself if no information needs to be shown

# Context: user@hostname (who am I and where am I)
prompt_context() {
  local user=$(whoami)

  if [[ "$user" != "$DEFAULT_USER" || -n "$SSH_CONNECTION" ]]; then
    prompt_segment $PRIMARY_FG default " %(!.%{%F{yellow}%}.)$user@%m "
  fi
}

# Git: branch/detached head, dirty status
prompt_git() {
  local color ref
  is_dirty() {
    test -n "$(git status --porcelain --ignore-submodules)"
  }
  ref="$vcs_info_msg_0_"
  if [[ -n "$ref" ]]; then
    if is_dirty; then
      color=yellow
      ref="${ref} $PLUSMINUS"
    else
      color=green
      ref="${ref} "
    fi
    if [[ "${ref/.../}" == "$ref" ]]; then
      ref="$BRANCH $ref"
    else
      ref="$DETACHED ${ref/.../}"
    fi
    prompt_segment $color $PRIMARY_FG
    print -Pn " $ref"
  fi
}

prompt_hg() {
  local rev status
  if $(hg id >/dev/null 2>&1); then
    if $(hg prompt >/dev/null 2>&1); then
      if [[ $(hg prompt "{status|unknown}") = "?" ]]; then
        # if files are not added
        prompt_segment red white
        st='±'
      elif [[ -n $(hg prompt "{status|modified}") ]]; then
        # if any modification
        prompt_segment yellow $PRIMARY_FG
        st='±'
      else
        # if working copy is clean
        prompt_segment green $PRIMARY_FG
      fi
      echo -n $(hg prompt "☿ {rev}@{branch}") $st
    else
      st=""
      rev=$(hg id -n 2>/dev/null | sed 's/[^-0-9]//g')
      branch=$(hg id -b 2>/dev/null)
      if $(hg st | grep -q "^\?"); then
        prompt_segment red $PRIMARY_FG
        st='±'
      elif $(hg st | grep -q "^[MA]"); then
        prompt_segment yellow $PRIMARY_FG
        st='±'
      else
        prompt_segment green $PRIMARY_FG
      fi
      echo -n "☿ $rev@$branch" $st
    fi
  fi
}

# Dir: current working directory
prompt_dir() {
  prompt_segment blue $PRIMARY_FG ' %~ '
}

# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
  local symbols
  symbols=()
  [[ $RETVAL -ne 0 ]] && symbols+="%{%F{red}%}$CROSS"
  [[ $UID -eq 0 ]] && symbols+="%{%F{yellow}%}$LIGHTNING"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{cyan}%}$GEAR"

  [[ -n "$symbols" ]] && prompt_segment $PRIMARY_FG default " $symbols "
}

# Virtualenv: current working virtualenv
prompt_virtualenv() {
  local virtualenv_path="$VIRTUAL_ENV"
  if [[ -n $virtualenv_path && -n $VIRTUAL_ENV_DISABLE_PROMPT ]]; then
    prompt_segment blue $PRIMARY_FG "($(basename $virtualenv_path))"
  fi
}

# todo.sh: output current number of tasks
prompt_todo() {
  if $(hash todo.sh 2>&-); then # is todo.sh installed
    count=$(todo.sh ls | egrep "TODO: [0-9]+ of ([0-9]+) tasks shown" | awk '{ print $4 }')
    if [[ "$count" = <-> ]]; then
      prompt_segment blue $PRIMARY_FG "T:$count"
    fi
  fi
}

# RVM: output current ruby version if RVM present
prompt_rvm() {
  local gemset=$(echo $GEM_HOME | awk -F'@' '{print $2}')
  [ "$gemset" != "" ] && gemset="@$gemset"
  local version=$(echo $MY_RUBY_HOME | awk -F'-' '{print $2}')
  local full="$version$gemset"
  [[ $full != '' ]] && rprompt_segment red $PRIMARY_FG "💎  $full"
}

# NVM: output current node version if NVM present
prompt_nvm() {
  if [[ $(type nvm) =~ 'nvm is a shell function' ]]; then
    local v=$(nvm current)
  fi
  [[ $v != '' ]] && rprompt_segment green $PRIMARY_FG "⬢ $v"
}

# NODE: output current node version if node present
prompt_node() {
  if [[ $(type node) =~ 'node is /usr/local/bin/node' ]]; then
    local v=$(node --version)
  fi
  [[ $v != '' ]] && rprompt_segment green $PRIMARY_FG "⬢ $v"
}

# NPM: output current npm version if node present
prompt_npm() {
  if [[ $(type npm) =~ 'npm is /usr/local/bin/npm' ]]; then
    local v=$(npm --version)
  fi
  [[ $v != '' ]] && rprompt_segment yellow $PRIMARY_FG "\u2651 $v"
}

# SDK: output current grails version if SDK present
prompt_grails() {
  if [[ $(type sdk) =~ 'sdk is a shell function' ]]; then
    grails=$(sdk current | awk -F'grails:' '{print $2}')
  fi
  [[ $grails != '' ]] && rprompt_segment red $PRIMARY_FG "\u03C8$grails"
}

# BREW: output current brew version if BREW present
prompt_brew() {
  if [[ $(type brew) =~ 'brew is /usr/local/bin/brew' ]]; then
    local brew=$(brew --version | awk -F' ' '{print $2}')
  fi
  [[ $brew != '' ]] && rprompt_segment red $PRIMARY_FG "\u262C $brew"
}

# SDK: output current groovy version if SDK present
prompt_groovy() {
  if [[ $(type sdk) =~ 'sdk is a shell function' ]]; then
    local groovy=$(sdk current | awk -F'groovy:' '{print $2}')
  fi
  [[ $groovy != '' ]] && rprompt_segment yellow $PRIMARY_FG "\u2606$groovy"
}

# Timestamp: add a timestamp to prompt - real time clock, stops when command is executed
prompt_timestamp() {
  if [[ $ZSH_TIME = "24" ]]; then
    local time_string="%H:%M:%S"
  else
    local time_string="%L:%M:%S %p"
  fi
  rprompt_segment blue $PRIMARY_FG "%D{$time_string}"
}

## Main prompt
prompt_agnoster_rj_main() {
  RETVAL=$?
  prompt_status
  prompt_virtualenv
  prompt_context
  prompt_dir
  prompt_todo
  prompt_git
  prompt_hg
  prompt_end
}

## Right prompt
rprompt_agnoster_rj() {
  prompt_brew
  #prompt_nvm
  prompt_npm
  prompt_node
  #prompt_rvm
  #prompt_groovy
  #prompt_grails
  prompt_timestamp
  echo -n " " # rprompt looks awful without a space at the end
}

prompt_agnoster_rj_precmd() {
  vcs_info
  PROMPT='%{%f%b%k%}$(prompt_agnoster_rj_main) '
  RPROMPT='%{%f%b%k%}$(rprompt_agnoster_rj)'
}

prompt_agnoster_setup() {
  autoload -Uz add-zsh-hook
  autoload -Uz vcs_info

  prompt_opts=(cr subst percent)

  add-zsh-hook precmd prompt_agnoster_rj_precmd

  zstyle ':vcs_info:*' enable git
  zstyle ':vcs_info:*' check-for-changes false
  zstyle ':vcs_info:git*' formats '%b'
  zstyle ':vcs_info:git*' actionformats '%b (%a)'
}

prompt_agnoster_setup "$@"

# Needed for clock in prompt
TMOUT=15
TRAPALRM() {
    #zle reset-prompt
}
