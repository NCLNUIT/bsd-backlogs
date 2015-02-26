module BSDBacklogs
  #AG: Borrowed from https://github.com/edavis10/redmine_kanban/blob/000cf175795c18033caa43082c4e4d0a9f989623/lib/redmine_kanban/issue_patch.rb#L13

  module IssuePatch
    def self.included(base)

      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development

        after_save :update_backlog_from_issue
        after_destroy :remove_backlog_issues

        #Add visible to Redmine 0.8.x
        unless respond_to?(:visible)
          named_scope :visible, lambda {|*args| { :include => :project, :conditions => Project.allowed_to_condition(args.first || User.current, :view_issues) } }
        end
      end

    end
    
    module ClassMethods
    end
    
    module InstanceMethods

      def update_backlog_from_issue

        backlog_field = CustomField.find_by_name('Backlog')
        backlog = self.custom_field_value(backlog_field.id)

        #Make sure we actually have a backlog to deal with - should also check was_value!!!
        if backlog.blank?
           return true
        end

        #Convert back log to int and reload self
        backlog = backlog.to_i
        self.reload

	    issues = Issue.joins(:custom_values).where( :project_id => self.project_id, custom_values: { :custom_field_id => backlog_field.id } ).
	        order("CAST(custom_values.value as UNSIGNED)").
            all( :conditions => ["custom_values.value >= ?", 1]) #backlog

        start = 1
	    issues.each do |issue|
            if issue.id == self.id
                next
            end

            #If we are overriding an existing number push up numbers
            if issue.custom_field_value(backlog_field.id).to_i == backlog
               start += 1
            end

            #Override the value
            cf = CustomValue.where( :custom_field_id => backlog_field.id, :customized_id => issue.id )
            cf.first.value = start
            cf.first.save

            #Inc start for next issue - backlog will auto sort
            start += 1
	    end

	    if backlog > start
            cf = CustomValue.where( :custom_field_id => backlog_field.id, :customized_id => self.id )
            cf.first.value = start
            cf.first.save
	    end

        return true
      end

      def remove_backlog_issues

        backlog_field = CustomField.find_by_name('Backlog')

	    issues = Issue.joins(:custom_values).where( :project_id => self.project_id, custom_values: { :custom_field_id => backlog_field.id } ).
	        order("CAST(custom_values.value as UNSIGNED)").
            all( :conditions => ["custom_values.value >= ?", 1])

        start = 1
	    issues.each do |issue|
            #Reindex the value
            cf = CustomValue.where( :custom_field_id => backlog_field.id, :customized_id => issue.id )
            cf.first.value = start
            cf.first.save
            start += 1
	    end

      end

    end    
  end
end