# frozen_string_literal: true

require 'time'
require 'erb'
require 'csv'
require 'google/apis/civicinfo_v2'

PHONE_NUMBER_PATH = 'output/phone_numbers.html'
REGTIME_PATH = 'output/regtimes.html'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  number = phone_number.to_s.delete '^0123456789'
  if number.to_s.count('0123456789') < 10
    '000-000-0000'
  elsif number.to_s.count('0123456789') == 11 && number[0] == '1'
    number[1..-1].insert(3, '-').insert(7, '-')
  elsif number.to_s.count('0123456789') > 10
    '000-000-0000'
  else
    number.insert(3, '-').insert(7, '-')
  end
end

def save_phone_number(name, number)
  Dir.mkdir('output') unless Dir.exist?('output')

  File.open(PHONE_NUMBER_PATH, 'a') do |file|
    file.puts "#{name}: #{number}"
  end
end

def save_reghours(hour, tally)
  Dir.mkdir('output') unless Dir.exist?('output')

  File.open(REGTIME_PATH, 'a') do |file|
    file.puts "Hour #{hour}: #{tally} Registrations"
  end
end

def peak_reghours(times)
  hours = times.map { |datetime| datetime.hour }
  hours.tally.sort_by { |_hour, count| count }.reverse![0..1].each do |hour, tally|
    save_reghours(hour, tally)
  end
end

def save_regdays(day, tally)
  Dir.mkdir('output') unless Dir.exist?('output')

  File.open(REGTIME_PATH, 'a') do |file|
    file.puts "#{day}: #{tally} Registrations"
  end
end

def peak_regdays(times)
  wdays = times.map { |datetime| Date::DAYNAMES[datetime.wday] }
  wdays.tally.sort_by { |_day, count| count }.reverse![0..1].each do |day, tally|
    save_regdays(day, tally)
  end
end

def regtimes(users)
  arr = []
  users.each do |row|
    arr.push(DateTime.strptime(row[:regdate], '%y/%e/%m %k:%M'))
  end
  peak_reghours(arr)
  peak_regdays(arr)
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def process_attendees(attendees)
  template_letter = File.read('form_letter.erb')
  erb_template = ERB.new template_letter

  File.open(PHONE_NUMBER_PATH, 'w') {}

  attendees.each do |row|
    id = row[0]
    name = row[:first_name].capitalize

    zipcode = clean_zipcode(row[:zipcode])

    legislators = legislators_by_zipcode(zipcode)

    form_letter = erb_template.result(binding)

    save_thank_you_letter(id, form_letter)

    save_phone_number(name, clean_phone_number(row[:homephone]))
  end
end

puts 'Event manager intialized!'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

process_attendees(contents)

contents.rewind

File.open(REGTIME_PATH, 'w') {}

regtimes(contents)
