#!/bin/bash

function_call_only=false

while (( "$#" )); do
  case "$1" in
    -f)
      function_call_only=true
      shift
      ;;
    *)
      query=$1
      if [ "$2" != "-f" ]; then
        function_call_only=false
      fi
      shift
      ;;
  esac
done

function call_openai_api {
    query=$( echo "$query" | sed 's/"/\\\"/g')
    
    function_call=$(if $function_call_only; then echo '{"name":"run_bash_command"}'; else echo '"auto"'; fi)
    local json='{
        "model": "gpt-3.5-turbo-0613",
        "messages": [{"role": "user", "content": "'"$query"'"}],
        "functions": [
            {
            "name": "run_bash_command",
            "description": "run bash command",
            "parameters": {
                "type": "object",
                "properties": {
                    "command": {
                        "type": "string",
                        "description": "bash command to run"
                    }
                },
                "required": ["command"]
                }
            }
        ],
        "function_call": '"$function_call"',
        "temperature": 0.1
    }'
    curl -s https://api.openai.com/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "$json"
}

if [ -z "$OPENAI_API_KEY" ]; then
    echo "Error: OPENAI_API_KEY is not set. Please set the variable before running this script."
    exit 1
fi

json_data=$(call_openai_api "$@")

error_message=$(echo $json_data | jq -r '.error.message')
if [ "$error_message" != 'null' ]; then
  echo "$error_message"
    exit 1
fi

if [[ $(echo "$json_data" | jq -r '.choices[0].message.function_call.name') == "run_bash_command" ]]; then
  arguments=$(echo "$json_data" | jq -r '.choices[0].message.function_call.arguments' | jq -r '.command')
  echo $arguments
elif [[ $(echo "$json_data" | jq -r '.choices[0].message.function_call.name') == "python" ]]; then
  python_script=$(echo "$json_data" | jq -r '.choices[0].message.function_call.arguments')
  echo "$python_script"
else
  content=$(echo "$json_data" | jq -r '.choices[0].message.content')
  echo $content
fi