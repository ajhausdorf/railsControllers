class MilestonesController < ApplicationController
    before_action :set_milestone, only: [:update, :destroy]

    # POST /milestones
    # POST /milestones.json
    def create
        @milestone = Milestone.new(milestone_params)
        @milestone.name = "Milestone" if @milestone.name.blank?

        respond_to do |format|
            if @milestone.save
                Activity.create!(user_id: current_user.id, project_id: @milestone.project.id, action: "create", trackable: @milestone)
                format.html { redirect_to @milestone.project, notice: 'Milestone was successfully created.' }
                format.json { render json: @milestone, status: :created }
                format.js
            else
                format.html { redirect_to @milestone.project, alert: @milestone.errors.full_messages.to_sentence }
                format.json { render json: @milestone.errors, status: :unprocessable_entity }
            end
        end
    end

    # PATCH/PUT /milestones/1
    # PATCH/PUT /milestones/1.json
    def update
      project = @milestone.project
      milestone_owner = User.find_by(id: project.user_id)

      #Alerts leader if a milestone is reached.  Needs testing or way to "complete" milestone.
      if !params[:milestone][:success_id].nil?
        milestone_owner.notify("alert", "Milestone #{view_context.link_to @milestone.name, @milestone} was 
        completed in #{view_context.link_to @milestone.project.title, @project}")
      end

      respond_to do |format|
          if @milestone.update_attributes(milestone_params)
              format.html { redirect_to @milestone.project, notice: 'Milestone was successfully created.' }
              format.json { respond_with_bip(@milestone) }
          else
              format.html { redirect_to @milestone.project, alert: @milestone.errors.full_messages.to_sentence }
              format.json {respond_with_bip(@milestone) }
          end
      end
    end

    # DELETE /milestones/1
    # DELETE /milestones/1.json
    def destroy
        @milestone.destroy
        Activity.create!(user_id: current_user.id, project_id: @milestone.project_id, action: "destroy", trackable: @milestone, data: @milestone.name)
        respond_to do |format|
            format.html { redirect_to @milestone.project, notice: 'Milestone was successfully destroyed.' }
            format.json { head :no_content }
            format.js
        end
    end

    # For drag/drop
    def sort
        params[:milestone].each_with_index do |id, index|
            Milestone.find(id).update_attributes(position: (index + 1))
        end
        render nothing: true
    end

    private
    def set_milestone
        @milestone = Milestone.find(params[:id])
    end

    def milestone_params
        params.require(:milestone).permit(:deadline, :name, :project_id)
    end
end
