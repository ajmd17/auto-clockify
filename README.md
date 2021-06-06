Auto clock time into Clockify based on Git commits

Add a file called `.env` into the root of the project:
```
CLOCKIFY_API_KEY=[your api key here]
CLOCKIFY_WORKSPACE_ID=[clockify workspace id]
CLOCKIFY_USER_ID=[clockify user id]
```

Additional optional fields may be added to the .env file.

```
...
START_OF_DAY=9
```

Install commit Git hook as `./.git/hooks/post-commit`:

```
#!/usr/bin/env bash

bundle exec ./bin/hook --hook=`basename "$0"`"
```

Mark hook as executable:

`chmod +x ./.git/hooks/post-commit`
