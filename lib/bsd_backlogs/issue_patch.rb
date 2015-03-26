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

        dont_increment = false

        #Make sure we actually have a backlog to deal with otherwise we may have wiped one out
        if backlog.blank?
           dont_increment = true
        end

        #Get all status ids which consititue an issue being open
        statuses = IssueStatus.where( :is_closed => 0 )
        status_ids = statuses.collect(&:id)

        #Make sure we are not dealing with a closed issue, we don't want to do anything with closed issue backlog numbers
        unless status_ids.include?(self.status_id)
            dont_increment = true
        end

        #Convert back log to int and reload self
        backlog = backlog.to_i
        self.reload

	    issues = Issue.joins(:custom_values).where( :project_id => self.project_id, custom_values: { :custom_field_id => backlog_field.id } ).
	        order("CAST(custom_values.value as UNSIGNED)").
            all( :conditions => ["custom_values.value >= ? AND status_id IN (?) AND issues.id != ?", 1, status_ids, self.id])

        start = 1
	    issues.each do |issue|

            #If we are overriding an existing number push up numbers
            if dont_increment == false and start == backlog
               start = backlog + 1
            end

            #Pointless saving if we are saving back the same number
            if issue.custom_field_value(backlog_field.id).to_i == start
                start += 1
                next
            end

            #Override the value
            cf = CustomValue.where( :custom_field_id => backlog_field.id, :customized_id => issue.id )
            cf.first.value = start
            cf.first.save

            #Inc start for next issue - backlog will auto sort
            start += 1
	    end

	    if dont_increment == false and backlog > start
            cf = CustomValue.where( :custom_field_id => backlog_field.id, :customized_id => self.id )
            cf.first.value = start
            cf.first.save
	    end

        return true

      end

      def remove_backlog_issues

        backlog_field = CustomField.find_by_name('Backlog')

        #Open status definitions
        statuses = IssueStatus.where( :is_closed => 0 )
        status_ids = statuses.collect(&:id)

        #Make sure we are not dealing with a closed issue, we don't want to do anything with closed issue backlog numbers
        unless status_ids.include?(self.status_id)
            return true
        end

        #Our current backlog number is deleted at this point so we have to work from 1 unfortunately
	    issues = Issue.joins(:custom_values).where( :project_id => self.project_id, custom_values: { :custom_field_id => backlog_field.id } ).
	        order("CAST(custom_values.value as UNSIGNED)").
            all( :conditions => ["custom_values.value >= ? AND status_id IN (?) AND issues.id != ?", 1, status_ids, self.id])

        backlog = 1
	    issues.each do |issue|
	        #Could improve this with a join back to issue and lookup via project
            cf = CustomValue.where( :custom_field_id => backlog_field.id, :customized_id => issue.id )
            cf.first.value = backlog
            cf.first.save
            backlog += 1
	    end

      end

    end    
  end
end