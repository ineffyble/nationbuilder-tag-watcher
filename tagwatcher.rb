#!/usr/bin/env ruby

require 'mail'
require 'json'
require 'nationbuilder'
require 'slack-notifier'

def get_old_tags(file)
  Dir.mkdir('cache') unless File.exists?('cache')
  Dir.mkdir('cache/email') unless File.exists?('cache/email')
  Dir.mkdir('cache/slack') unless File.exists?('cache/slack')
  if File.exist?(file)
    return JSON.parse(File.open(file, 'r').read)
  else 
    p file + " does not exist. Creating cache. No report will be sent."
    file = File.new(file, 'w')
    file.puts(Array.new.to_json)
    return Array.new
  end
end

def update_cache(all_tags, file)
  file = File.open(file, 'w')
  file.write(all_tags.to_json)
end

def get_new_tags(all_tags, old_tags)
  return all_tags - old_tags
end

def get_tag_list(nation, api_key)
  client = NationBuilder::Client.new(nation, api_key)
  people_tags = client.call(:people_tags, :index, limit: 500)
  page = NationBuilder::Paginator.new(client, people_tags)

  tags = Array.new

  while !page.nil?
    page.body["results"].each do |tag|
      tags.push(tag["name"])
    end
    page = page.next
  end

  return tags
end

def get_tagged_people(nation, api_key, tag)
  client = NationBuilder::Client.new(nation, api_key)
  people_tagged = client.call(:people_tags, :people, tag: URI.encode(tag), limit: 11)

  people = Array.new

  people_tagged["results"].each do |person|
    people.push({
      first_name: person["first_name"],
      last_name: person["last_name"],
      id: person["id"]
    })
  end

  return people
end

def send_tag_report(nation, new_tags, from, to)
  text = ''
  html = '<ul>'
  new_tags.each do |tag|
    text << '* ' + tag + '\n'
    html << '<li>' + tag + '</li>'
  end
  html << '</ul>'

  Mail.defaults do
    delivery_method :sendmail
  end

  Mail.deliver do
    to to
    from from
    subject 'New tags in the ' + nation + ' nation'

    text_part do
      body text
    end

    html_part do
      content_type 'text/html; charset=UTF-8'
      body html
    end

  end

  p "Tag report sent."
end

def send_tag_alert(nation, api_key, new_tags, webhook_url, channel, username)
  notifier = Slack::Notifier.new webhook_url do
    defaults channel: channel,
             username: username
  end

  tags = Array.new


  new_tags.each do |tag|
    tagged_people = get_tagged_people(nation, api_key, tag)
    people = Array.new
    tagged_people.each do |person|
      people.push("<https://" + nation + ".nationbuilder.com/admin/signups/" + person[:id].to_s + "|" + person[:first_name] + " " + person[:last_name] + ">")
    end
    tags.push({
      fallback: '• ' + tag,
      title: 'Tag',
      text: tag,
      color: "%06x" % (rand * 0xffffff),
      fields: [
        {
          title: 'Tagged people',
          value: people.join(", ")
        },
        {
          title: 'More than 10 people tagged?',
          value: (tagged_people.length > 10 ? 'Yes' : 'No')
        }
      ]
    })

    notifier.post text: "New tag(s)", attachments: tags
  end


  p "Tag alert sent."

end

if __FILE__ == $0

  NATION = ENV["NATION"]
  API_KEY = ENV["API_KEY"]

  if NATION.nil? || API_KEY.nil?
    p "Invalid nation credentials. Usage: NATION=nation_slug API_KEY=api_key"
    exit 1
  end

  MODE = ENV["MODE"]

  if MODE.nil?
    p "No mode specified. Usage: MODE=email|slack"
    exit 1
  elsif MODE != 'email' && MODE != 'slack'
    p "Invalid mode specified. Valid options: email, slack"
    exit 1
  end

  if MODE == 'email'
    TO = ENV["TO"]
    FROM = ENV["FROM"] ? ENV["FROM"] : ENV["TO"]
    if TO.nil?
      p "Invalid email configuration. Usage: TO=to_email_address (FROM=from_email_address)"
      exit 1
    end
  elsif MODE == 'slack'
    WEBHOOK_URL = ENV["WEBHOOK_URL"]
    CHANNEL = ENV["CHANNEL"]
    USERNAME = ENV["USERNAME"] || "NationBuilder Tag Alerts"
    if WEBHOOK_URL.nil? || CHANNEL.nil?
      p "Invalid Slack configuration. Usage: WEBHOOK_URL=slack_webhook_url CHANNEL=channel_name (USERNAME=bot_username)"
      exit 1
    end
  end

  FILE = ENV["FILE"] ? ENV["FILE"] : 'cache/' + MODE + '/' + NATION + '.json'

  p "Generating report of new tags on the " + NATION + " nation."

  all_tags = get_tag_list(NATION, API_KEY)
  old_tags = get_old_tags(FILE)
  new_tags = get_new_tags(all_tags, old_tags)

  update_cache(all_tags, FILE)

  if new_tags.any? && new_tags != all_tags
    p new_tags.length.to_s + " new tags."
    if MODE == 'email'
      send_tag_report(NATION, new_tags, FROM, TO)
    elsif MODE == 'slack'
      send_tag_alert(NATION, API_KEY, new_tags, WEBHOOK_URL, CHANNEL, USERNAME)
    end
  else 
    p "No new tags"
  end

end 
