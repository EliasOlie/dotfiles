# eliasolie.zsh-theme — prompt minimalista na paleta do eliasolie-site
#   void #050505 · line #2A2A27 · static #8A8A84 · bone #EDEDE8 · signal #C8F031 · alert #FF5A4E
#
#   ● ~/work/projeto  main ✱                      2.3s · 17:42
#   ❯
#
# - ● fica lima quando o último comando deu certo e coral quando falhou
# - ✱ = alterações não commitadas no git
# - duração aparece só se o comando levou mais de 2 s
# - (ssh) aparece quando você está numa sessão remota

setopt PROMPT_SUBST
autoload -Uz add-zsh-hook

typeset -g ELI_SIGNAL='#C8F031' ELI_ALERT='#FF5A4E' ELI_BONE='#EDEDE8' ELI_STATIC='#8A8A84' ELI_LINE='#2A2A27'

# Git: branch + marcador de sujo (usa as funções do oh-my-zsh)
ZSH_THEME_GIT_PROMPT_PREFIX=" %F{$ELI_STATIC}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%f"
ZSH_THEME_GIT_PROMPT_DIRTY=" %F{$ELI_SIGNAL}✱%f"
ZSH_THEME_GIT_PROMPT_CLEAN=""

# Duração do último comando
_eli_preexec() { typeset -g _eli_start=$EPOCHREALTIME }
_eli_precmd() {
  typeset -g _eli_took=""
  if [[ -n $_eli_start ]]; then
    local d=$(( EPOCHREALTIME - _eli_start ))
    (( d >= 2 )) && _eli_took=$(printf '%.1fs · ' $d)
    unset _eli_start
  fi
  print ""   # respiro entre um comando e outro
}
zmodload zsh/datetime 2>/dev/null
add-zsh-hook preexec _eli_preexec
add-zsh-hook precmd  _eli_precmd

_eli_host() { [[ -n $SSH_CONNECTION ]] && print -n "%F{$ELI_ALERT}(ssh) %m%f " }

PROMPT='%(?.%F{$ELI_SIGNAL}.%F{$ELI_ALERT})●%f $(_eli_host)%F{$ELI_BONE}%~%f$(git_prompt_info)
%F{$ELI_SIGNAL}❯%f '
RPROMPT='%F{$ELI_LINE}${_eli_took}%F{$ELI_STATIC}%D{%H:%M}%f'
PROMPT2='%F{$ELI_LINE}·%f '
