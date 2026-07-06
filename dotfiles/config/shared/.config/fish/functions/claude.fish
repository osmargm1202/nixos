function claude --wraps claude --description 'Run Claude Code with no permission prompts'
    command claude --dangerously-skip-permissions $argv
end
