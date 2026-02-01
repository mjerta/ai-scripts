#!/usr/bin/env bash

if [ -z "$OPENAI_API_KEY" ]; then
  echo "Error: OPENAI_API_KEY is not set."
  exit 1
fi

if [ ! -t 0 ]; then
  STDIN_DATA=$(cat -)
fi

PROMPT="$*"

spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}
(
  curl -s https://api.openai.com/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "$(jq -n --arg p "$PROMPT" --arg i "$STDIN_DATA" '{
          model: "gpt-4o-mini",
        messages: [
            {role: "system", content: "You are a CLI tool. Provide concise, raw text output. No markdown backticks."},
            {role: "user", content: ($p + "\n\nDATA:\n" + $i)}
        ]
    }')" >/tmp/ai_response.json
) &

CUR_PID=$!
spinner $CUR_PID

RESULT=$(cat /tmp/ai_response.json | jq -r '.choices[0].message.content // .error.message')
echo -e "\n$RESULT"

rm /tmp/ai_response.json
