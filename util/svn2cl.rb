#!/usr/bin/env ruby

require 'time'

def wrap( text, column, indent="" )
  wrapped = ""
  while text.length > column
    break_at = text.rindex( /[-\s]/, column ) || column
    line = text[0,break_at+1].strip
    text = text[break_at+1..-1].strip
    wrapped << indent << line << "\n"
  end
  wrapped << indent << text
end

output = `svn log`.split( /^-----*\n/ )

output[1..-2].each do |change|
  lines = change.split(/\n/)
  revision, user, stamp, size = lines.shift.split( /\|/ )
  lines.shift
  msg = lines.join(' ')
  date, time = stamp.match( /(\d\d\d\d-\d\d-\d\d) (\d\d:\d\d):\d\d/ )[1,2]

  puts "#{date} #{time}  #{user.strip}"
  puts
  puts "\t* #{wrap(msg,60,"\t  ").strip}"
  puts
end
