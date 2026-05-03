require 'net/http'
require 'json'

module AutoNestCut
  class SupabaseClient
    SUPABASE_URL = 'https://hbslewdkkgwsaohjyzak.supabase.co'
    SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhic2xld2Rra2d3c2FvaGp5emFrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0MzM5NDE2MSwiZXhwIjoyMDU4OTcwMTYxfQ.xbpxYHH5UCdszrAQc39GBgkwBNjzCzOo79M1vonSoyM'
    
    def self.upload_report(task, report_data)
      # Upload file to Supabase Storage
      file_name = "report_#{task[:id]}_#{Time.now.to_i}.#{get_file_extension(task[:format])}"
      storage_url = upload_to_storage(file_name, report_data)
      
      # Insert job record to trigger Edge Function
      insert_report_job({
        task_id: task[:id],
        task_name: task[:name],
        file_url: storage_url,
        email: task[:email],
        format: task[:format],
        created_at: Time.now.iso8601
      })
    end
    
    private
    
    def self.upload_to_storage(file_name, data)
      uri = URI("#{SUPABASE_URL}/storage/v1/object/reports/#{file_name}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{SUPABASE_KEY}"
      request['Content-Type'] = 'application/octet-stream'
      request.body = data
      
      response = http.request(request)
      "#{SUPABASE_URL}/storage/v1/object/public/reports/#{file_name}"
    end
    
    def self.insert_report_job(job_data)
      uri = URI("#{SUPABASE_URL}/rest/v1/report_jobs")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{SUPABASE_KEY}"
      request['Content-Type'] = 'application/json'
      request['apikey'] = SUPABASE_KEY
      request.body = job_data.to_json
      
      http.request(request)
    end
    
    def self.get_file_extension(format)
      case format.downcase
      when 'csv' then 'csv'
      when 'json' then 'json'
      when 'pdf' then 'pdf'
      else 'txt'
      end
    end
  end
end