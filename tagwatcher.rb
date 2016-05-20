#!/usr/bin/env ruby

require 'mail'
require 'json'
require 'nationbuilder'

NATION = ENV["NATION"]
API_KEY = ENV["API_KEY"]
FILE = ENV["FILE"] ? ENV["FILE"] : 'cache/' + NATION + '.json'
TO = ENV["TO"]
FROM = ENV["FROM"] ? ENV["FROM"] : ENV["TO"]

def get_old_tags(file)
  Dir.mkdir('cache') unless File.exists?('cache')
  if File.exist?(file)
    return JSON.parse(File.open(file, 'r').read)
  else 
    p file + " does not exist. Creating cache. No report will be sent."
    file = File.new(file, 'w')
    file.puts(Array.new)
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

if __FILE__ == $0

  if NATION.nil? || API_KEY.nil? || TO.nil?
    p "Usage: NATION=nation_slug API_KEY=api_key TO=to_email_address FROM=from_email_address"
    exit 1
  end

  p "Generating report of new tags on the " + NATION + " nation."

  all_tags = get_tag_list(NATION, API_KEY)
  old_tags = get_old_tags(FILE)
  new_tags = get_new_tags(all_tags, old_tags)

  update_cache(all_tags, FILE)

  if new_tags.any? && new_tags != all_tags
    p new_tags.length.to_s + " new tags."
    send_tag_report(NATION, new_tags, FROM, TO)
  else 
    p "No new tags"
  end

end 
