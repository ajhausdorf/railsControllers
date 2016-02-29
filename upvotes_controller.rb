class UpvotesController < ApplicationController
  def new
    @upvote=Upvote.new
  end

  def destroy
    user = @upvote.user
    @upvote.destroy
    respond_to do |format|
      format.html { redirect_to dashboard_path }
      format.json { head :no_content }
    end
  end

  def create
    upvote_search = Upvote.where(upvote_params)
    if upvote_search.present?
      @upvote = upvote_search.first
      @upvote.subtract_content_creator_points(1)
      @upvote.destroy
      respond_to do |format|
          format.html { redirect_to :back }
          format.js
      end
    else
      @upvote = Upvote.new(upvote_params)
      respond_to do |format|
        if @upvote.save
          @upvote.add_content_creator_points(1)
          #notify owner of project that it was upvoted
          if !params[:project_id].nil?
            @project = Project.find_by(id: params[:project_id])
            user = User.find(@project.user_id) 
            if user != current_user
              user.notify("alert", "Your project #{view_context.link_to @project.title, @project} was upvoted!")
            end
          end
          #notify owner of idea that it was upvoted
          if !params[:idea_id].nil?
            @idea = Idea.find_by(id: params[:idea_id])
            user = User.find(@idea.user_id) 
            if user != current_user
              user.notify("alert", "Your idea #{view_context.link_to @idea.title, @idea} was upvoted!")
            end
          end
          #need to specify where comment is -- Your comment on #{view_context.link_to @project.title, @project} was upvoted!
          if !params[:comment_id].nil?
            @comment = Comment.find_by(id: params[:comment_id])
            user = User.find(@comment.user_id) 
            if user != current_user
              user.notify("alert", "#{view_context.link_to current_user.full_name, current_user} upvoted your comment!") #need link here & specificity after beta launch
            end
          end
          #notify owner of success that it was upvoted
          if !params[:success_id].nil?
            @success = Success.find_by(id: params[:success_id])
            user = User.find(@success.leader_id) 
            if user != current_user
              user.notify("alert", "Your success #{view_context.link_to @success.title, @success} was upvoted!")
            end
          end
          format.html { redirect_to :back }
          format.js
        else
          format.html {redirect_to :back }
        end
      end
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_upvote
    @upvotes = Upvotes.find(params[:id])
  end

  def upvote_params
    params.permit(:project_id, :idea_id, :success_id, :comment_id).merge(user_id: current_user.id)
  end
end

