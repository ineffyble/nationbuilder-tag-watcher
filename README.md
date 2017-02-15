# nationbuilder-tag-watcher
Script that reports on new tags in a NationBuilder nation, via email or slack notification. Can be automated as a cronjob.

## Usage

### Email reports
```
export NATION=nation_slug
export API_KEY=valid_api_token
export MODE=email
export TO=to@emailaddress.com
export FROM=from@emailaddress.com
ruby tagwatcher.rb
```

### Slack alerts

You will need a (Slack webhook URL)[https://api.slack.com/services/new/incoming-webhook].

```
export NATION=nation_slug
export API_KEY=valid_api_token
export MODE=slack
export WEBHOOK_URL=a_slack_webhook_url
export CHANNEL=nationbuilderalerts
export USERNAME=NationBot
ruby tagwatcher.rb
```

### Multiple nations or configurations

If you would like to easily run multiple instances of the tag watcher, you can use a bash script to set the environment variables before each run.

For simplicity, one option is to create .env.nationslug files in your tag watcher folder, and use the bash `source` command.