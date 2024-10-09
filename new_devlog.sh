filename="content/devlog/$(date -u +"%FT%H%MZ").md"

touch $filename

echo '+++
title = "Devlog '$(date -Ru)'"
date = "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
+++' > $filename


