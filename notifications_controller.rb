class NotificationsController < ApplicationController

  def index
    @user = current_user
    @notifications = current_user.notifications.where(:notification_type => 'alert').reverse
  end

  def mark_viewed_alerts
    current_user.notifications.where(:notification_type => "alert").each do |a| 
      a.mark_viewed
    end
    
    respond_to do |format|
      format.js
    end
  end


  def dismiss_action_item
    @id = params[:id]
    Notification.find(@id).mark_viewed

    respond_to do |format|
      format.js
    end
  end


  def add_action_item
    @id = params[:id]
    #this is not correct because current_user is the project owner
    # project_id = Notification.find(@id).description.split(/\s/).delete_if(&blank?).delete_if(!is_a? Integer)
    # puts "#{project_id} is the project's id"
    # Project.find(project_id).toggle_team_member(user)
    projects_joined = current_user.projects_joined_count
    current_user.update(:projects_joined_count => projects_joined + 1)



    Notification.find(@id).mark_viewed
    respond_to do |format|
      format.js
    end
  end

  def remove_me_action_item
    #if they click 'Remove Me' button then they should be taken off the team
    @id = params[:id]
    user=Notification.find(@id).user_id
    #I need the project id but have no ways to obtain it
    #assuming that I will be extracting certain word from notification.description
    #<a href=\"/users/6\">Dan Champio</a> has asked you to join the team for\n      <a href=\"/projects/11\">Project Cortana</a>. <a href=\"#\">OK</a> | <a href=\"#\">Remove Me</a>    project_id = Notification.find(@id).description.split(/\s/).delete_if(&blank?).delete_if(!is_a? Integer)
    # puts "#{project_id} is the project's id"
    # Project.find(project_id).toggle_team_member(user)



    Notification.find(@id).mark_viewed

    respond_to do |format|
      # format.html { redirect_to ???, notice: '' }
      format.html { redirect_to User.find(user), notice: 'You have been taken off the project.' }
      # which one?
      # format.html { redirect_to dashboard_path, alert:'You have been taken off the project.' }
      format.js
    end

    def evaluate_action_item
      #I need to redirect them to a new website
      Notification.find(@id).mark_viewed
      respond_to do |format|
        format.js
      end
    end
  end



end 
