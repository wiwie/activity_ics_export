class ActivityIcsExportController < ApplicationController
  unloadable
  skip_before_filter :check_if_login_required
  skip_before_filter :verify_authenticity_token

# Redmine 1.3 and prior use accept_key_auth to enforce auth 
  # via the key we hand to the applet.
  if Redmine::VERSION::MAJOR == 1 and Redmine::VERSION::MINOR <= 3 then
    accept_key_auth :export
  else
    accept_api_auth :export
  end



  def export
    ical = Vpim::Icalendar.create({ 'METHOD' => 'REQUEST', 'CHARSET' => 'UTF-8' })
    time_start = params['time_start']
    time_end = params['time_end']

    activities = TimeEntry.all
    if time_start and time_end
        activities = activities.where(["time_entries.created_on >= ? AND time_entries.created_on <= ?", time_start, time_end])
    elsif time_start and not time_end
        activities = activities.where(["time_entries.created_on >= ?", time_start])
    elsif not time_start and time_end
        activities = activities.where(["time_entries.created_on <= ?", time_end])
    end

    if params['onlyassigned'] and params['onlyassigned'] == 'true'
        activities = activities.where(:user_id => User.current.id)
    end

    activities.each do |act|
      ical.add_event do |e|
	issue = act.issue
        time_start = act.created_on - act.hours*60*60
        time_end = act.created_on
        e.summary(issue.id.to_s + ' - ' + issue.subject + ' - ' + (issue.assigned_to.blank? ? '' : issue.assigned_to.firstname + " " + issue.assigned_to.lastname))
        e.dtstart(time_start)
        e.dtend(time_end)
       e.dtstamp(act.updated_on)
        e.lastmod(act.updated_on)
        e.created(act.created_on)
        e.uid("RedmineTimeEntryID:"+act.id.to_s)
        e.url(url_for(issue))
        #e.sequence(seq.to_i)
        if (issue.description)
           e.description(issue.description.gsub("\n\n",""))
        end
        #if !issue.assigned_to.blank?
        #  e.organizer do |o|
        #    o.cn = issue.assigned_to.firstname + " " + issue.assigned_to.lastname
        #    o.uri = "mailto:#{issue.assigned_to.email_address.address}" rescue nil
        #  end
        #end
      end
    end
    send_data ical.encode(), filename: 'Redmine_activity_calendar.ics'
  end

end
