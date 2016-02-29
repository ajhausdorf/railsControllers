class TasksController < ApplicationController
  before_action :set_task, only: [:show, :edit, :update, :destroy]


  # GET /tasks/1
  # GET /tasks/1.json
  def show
  end

  # GET /tasks/new
  def new
    @task = Task.new
  end

  # GET /tasks/1/edit
  def edit
  end

  # POST /tasks
  # POST /tasks.json
  def create
    @task = Task.new(task_params)
    @task.description = 'Task' if @task.description.blank?
    respond_to do |format|
      if @task.save
        Activity.create!(user_id: current_user.id, project_id: @task.milestone.project.id, action: "create", trackable: @task)
        format.html { redirect_to @task.milestone.project, notice: 'Task was successfully created.' }
        format.json { render json: @task, status: :created}
        format.js
      else
        format.html { redirect_to @task.milestone.project, alert: @task.errors.full_messages.to_sentence }
        format.json { render json: @task.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /tasks/1
  # PATCH/PUT /tasks/1.json
  def update
    previous_completed = @task.completed
    previous_deadline = @task.deadline
    previous_owner = @task.user
    new_owner = User.find_by(id: params[:task][:user_id])
    task_owner = @task.user
    project = @task.milestone.project
    success = @task.milestone.success

    #you can STILL edit tasks when the project becomes a success
    if project.present?
      project_owner = @task.milestone.project.user
    else
      success_owner = @task.milestone.success.leader
    end

    if !params[:task][:deadline].nil?
      new_deadline = params[:task][:deadline]
      if new_deadline != previous_deadline && current_user != task_owner
        task_owner.notify("alert", "#{view_context.link_to current_user.full_name, current_user} changed the due date of
          #{view_context.link_to @task.description, @task.milestone.project} to #{new_deadline}")
      end
    end

    #Notify a task was completed
    if params[:task][:completed] == "true" && current_user != task_owner
      task_owner.notify("alert", "Your task '#{@task.description}' in #{view_context.link_to project.title, project} was completed by #{view_context.link_to current_user.full_name, current_user}")
    end

    #notifies user they have a new task
    if !new_owner.nil? && new_owner !=  current_user && new_owner != task_owner
      if @task.milestone.project.present?
        new_owner.notify("alert", "You were assigned to a task in the project #{view_context.link_to @task.milestone.project.title, project}")
      else
        new_owner.notify("alert", "You were assigned to a task in the success #{view_context.link_to @task.milestone.success.title, success}")
      end
    end

    modified_params = task_params.clone
    if modified_params[:completed] == "true"
      modified_params.merge!({completed_at: DateTime.now})
      next_task = Task.find_by_position_and_milestone_id((@task.position - 1), @task.milestone_id)
      if next_task.present?
        next_task.ball_is_in_your_court(@task) if next_task.user.present? && next_task.crucial == true
      end
    elsif modified_params[:completed] == "false"
      modified_params.merge!({completed_at: nil})
    end

    respond_to do |format|
      if @task.update_attributes(modified_params)
        @task.create_activities(previous_completed, previous_deadline, previous_owner, current_user)

        # during update, if there is 1 last task remaining already and someone is updating client's remaining incomplete task the project owner will be notified every time
        # user!=project_owner ensures that if the changes are made by the project_owner, client is not notified (since client can see it)
        if @task.milestone.tasks.where(completed: false).size==1 && (task_owner!=project_owner || task_owner!=project_owner) && params[:task][:completed]

          # if never_alerted (which should be a boolean that shows if there already was a notification from this task)
          if project.present?
            project_owner.notify("alert", "One task left until #{view_context.link_to @task.milestone.name, project} is completed!")
          else
            success_owner.notify("alert", "One task left until #{view_context.link_to @task.milestone.name, success} is completed!")
          end
        end

        # user id gets saved as 0 sometimes when being set as nil. this changes it back
        if @task.user_id == 0
          @task.update_attributes(user_id: nil)
        end

        format.html { redirect_to @task, notice: 'Task was successfully updated.' }
        if project.present?
          format.html { redirect_to project, notice: 'Task was successfully updated.' }
        else
          format.html { redirect_to success, notice: 'Task was successfully updated.' }
        end
        format.json { respond_with_bip(@task) }
      else
        if project.present?
          format.html { redirect_to project, alert: @task.errors.full_messages.to_sentence }
        else
          format.html { redirect_to success, alert: @task.errors.full_messages.to_sentence }
        end
        format.json { respond_with_bip(@task) }
      end
    end
  end

  # DELETE /tasks/1
  # DELETE /tasks/1.json
  def destroy
    user = @task.user
    if @task.milestone.project.present?
      project_owner = @task.milestone.project.user
      project = @task.milestone.project
    else
      success_owner = @task.milestone.success.leader
      success = @task.milestone.success
    end

    if !user.nil? && current_user != user
      unless project.nil?
        user.notify("alert", "Your task '#{@task.description}' in #{view_context.link_to project.title, project} was removed by #{view_context.link_to current_user.full_name, current_user}")
      else
        user.notify("alert", "Your task '#{@task.description}' in #{view_context.link_to success.title, success} was removed by #{view_context.link_to current_user.full_name, current_user}")
      end
    end

    if @task.milestone.tasks.where(completed: false).size==1 && user!=project_owner
      unless project.nil?
        project_owner.notify("alert", "One task left until #{view_context.link_to @task.milestone.name, project} is completed!")
      else
        success_owner.notify("alert", "One task left until #{view_context.link_to @task.milestone.name, success} is completed!")
      end
    end

    @task.destroy
    respond_to do |format|
      unless @task.milestone.project.nil?
        Activity.create!(user_id: current_user.id, project_id: @task.milestone.project_id, action: "destroy", trackable: @task, data: @task.description)
        format.html { redirect_to @task.milestone.project, notice: 'Task was successfully destroyed.' }
      else
        Activity.create!(user_id: current_user.id, success_id: @task.milestone.success_id, action: "destroy", trackable: @task, data: @task.description)
        format.html { redirect_to @task.milestone.success, notice: 'Task was successfully destroyed.' }
      end
      format.json { head :no_content }
      format.js
    end
  end

  # For drag/drop
  def sort
    params[:task].each_with_index do |id, index|
      Task.find(id).update_attributes(position: (index + 1))
    end
    render nothing: true
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_task
    @task = Task.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def task_params
    params.require(:task).permit(:description, :deadline, :completed, :milestone_id, :user_id, :crucial)
  end
end
