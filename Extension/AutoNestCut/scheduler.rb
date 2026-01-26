require 'json'

module AutoNestCut
  class Scheduler
    SCHEDULER_FILE = File.join(File.dirname(__FILE__), 'scheduler_data.json')
    
    def self.add_task(name, cron_expression, filter_rules, output_format, email)
      tasks = load_tasks
      tasks << {
        id: Time.now.to_i.to_s,
        name: name,
        cron: cron_expression,
        filters: filter_rules,
        format: output_format,
        email: email,
        next_run: calculate_next_run(cron_expression),
        active: true
      }
      save_tasks(tasks)
    end
    
    def self.check_due_tasks
      tasks = load_tasks
      due_tasks = tasks.select { |task| task[:active] && Time.now.to_i >= task[:next_run] }
      
      due_tasks.each do |task|
        execute_task(task)
        task[:next_run] = calculate_next_run(task[:cron])
      end
      
      save_tasks(tasks) if due_tasks.any?
    end
    
    private
    
    def self.execute_task(task)
      begin
        # Generate report
        report_data = AutoNestCut::ReportGenerator.generate_scheduled_report(task[:filters], task[:format])
        
        # Send to Supabase
        AutoNestCut::SupabaseClient.upload_report(task, report_data)
      rescue => e
        puts "Scheduler error: #{e.message}"
      end
    end
    
    def self.calculate_next_run(cron_expression)
      # Simple daily scheduler - runs at specified hour
      hour = cron_expression.to_i
      next_run = Time.now
      next_run = Time.new(next_run.year, next_run.month, next_run.day, hour, 0, 0)
      next_run += 24 * 60 * 60 if next_run <= Time.now
      next_run.to_i
    end
    
    def self.load_tasks
      return [] unless File.exist?(SCHEDULER_FILE)
      JSON.parse(File.read(SCHEDULER_FILE), symbolize_names: true)
    rescue
      []
    end
    
    def self.save_tasks(tasks)
      File.write(SCHEDULER_FILE, JSON.pretty_generate(tasks))
    end
  end
end