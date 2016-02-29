class IdeasController < ApplicationController
  before_action :set_idea, only: [:show, :edit, :update, :destroy, :toProject]
  before_action :authenticate_user_access, only: [:edit, :update, :destroy, :toProject]
  before_action :authenticate_team_access, only: [:show]
  autocomplete :user, :full_name, :full => true
  autocomplete :domain, :title, :full => true

  # GET /ideas/1
  # GET /ideas/1.json
  def show
    if !@idea.success_id.nil?
      redirect_to success_path(@idea.success_id)
    elsif !@idea.project_id.nil?
      redirect_to project_path(@idea.project_id)
    end
    @comments = @idea.comments
    @user = @idea.user
    @comment = Comment.new
    @links = @idea.links.where.not(user_id: nil)
    @documents = @idea.documents.where.not(user_id: nil)
    @domains = @idea.domains
    @link = Link.new
    @document = Document.new
    @challenge = Challenge.where(:id => @idea.challenge_id).first if !(@idea.challenge_id.nil?)
    @evaluations = @idea.evaluations
    @user_evaluation = @evaluations.find_by_user_id(current_user.id)
    idea_value = 0
    @evaluations.each do |eval|
      idea_value += eval.value
    end
    @idea_avg_value = interval_calculator(idea_value / @evaluations.count.to_f)
    @idea_benefit = []
    @evaluations.each do |eval|
      @idea_benefit << eval.benefit
    end
    @idea_benefit_count = Hash.new(0)
    @idea_benefit.flatten.each { |idea_benefit| @idea_benefit_count[idea_benefit] += 1 }
    @idea_benefit_count = @idea_benefit_count.to_a
  end

  def interval_calculator(avg_value)
    if avg_value < 10000
      "<$10,000"
    elsif avg_value >= 10000 && avg_value <100000
      "$10,000 - $100,000"
    elsif avg_value >= 100000 && avg_value < 500000
      "$100,000 - $500,000"
    elsif avg_value >= 500000 && avg_value <1000000
      "$500,000 - $1,000,000"
    elsif avg_value >= 1000000
      "$1,000,000+"
    end
  end

  # GET /ideas/new
  def new
    @idea = Idea.new
    @user = current_user
  end

  # GET /ideas/1/edit
  def edit
    @user = current_user
  end

  # POST /ideas
  # POST /ideas.json
  def create
    @challenge = Challenge.find(params[:idea][:challenge_id])
    @idea = Idea.new(idea_params)
    @idea.challenge_id = @challenge.id

    respond_to do |format|
      if @idea.save
        idea_count = @idea.user.ideas_created_count
        #@idea.update_attributes(challenge_id: params[:challenge_id])
        @idea.user.update(:ideas_created_count => idea_count + 1)
        @idea.domains.each do |domain|
          current_user.add_points(1, category: domain.title)
        end
        @ideas = current_user.current_team.ideas.sort_by{|i| i.heat_index}.reverse
        @ideas = @ideas.paginate(:page => params[:ideas_page], :per_page => 10)
        format.html { redirect_to :back, notice: 'Idea was successfully created.' }
        format.json { render :show, status: :created, location: @idea }
        format.js
      else
        format.html { redirect_to :back, notice: "You must attach domains to your Idea." }
        format.json { render json: @idea.errors, status: :unprocessable_entity }
        format.js { render :create_failed }
      end
    end
  end

  # PATCH/PUT /ideas/1
  # PATCH/PUT /ideas/1.json
  def update
    respond_to do |format|
      if @idea.update_attributes(idea_params)
        format.html { redirect_to @idea, notice: 'Idea was successfully updated.' }
        format.json { render :show, status: :ok, location: @idea }
      else
        format.html { render :edit }
        format.json { render json: @idea.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /ideas/1
  # DELETE /ideas/1.json
  def destroy
    user = @idea.user
    # only notifies user if idea was removed by admin rather than by himself/herself
    user.notify('alert',"Your idea, #{@idea.title}, was removed by #{view_context.link_to current_user.full_name, current_user}") if current_user != user
    idea_count = @idea.user.ideas_created_count
    user.update(:ideas_created_count => idea_count - 1)
    @idea.destroy #this should be at the end bcause if it wasn't then @idea would be gone and we cannot call it
    respond_to do |format|
      format.html { redirect_to dashboard_path, notice: 'Idea was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def toProject
    @idea.project.nil? ? @project = @idea.to_project(current_user) : @project = @idea.project
    team_member_ids = @project.team_members.split(",")
    @team_members = User.where(:id => team_member_ids)
    users_suggested_ids = @idea.users_suggested.split(",")
    @users_suggested = User.where(:id => users_suggested_ids)
    @users_suggested -= @team_members
    users_interested_ids = @idea.users_interested.split(",")
    @users_interested = User.where(:id => users_interested_ids)
    @users_interested -= @team_members
    @non_users_suggested = @idea.non_users_suggested
    @milestones = @project.milestones.order('deadline DESC')
    @user_matches = current_user.current_team.users.where.not(:name => nil).sort_by{|user| user.match_index(@project)}
    @user_matches -= @users_interested
    @user_matches -= @users_suggested
    @user_matches.delete(@project.user)
    @user_matches = @user_matches.reverse.first(5)
    @idea.update_attributes(title: nil, ghosted: true, description: nil, resources: nil, users_following: nil, users_suggested: nil,
                            users_interested: nil, non_users_suggested: nil)
    #keep id, project_id, created_at, user_id // non-nil constraint: updated_at // accesibility issue: team_id
  end

  def follow_idea
    @idea = Idea.find(params[:id])
    @message = @idea.toggle_follower(current_user.id)
    @following = current_user.following?(@idea)
    respond_to do |format|
      format.js
    end
  end

  def volunteer_for_team
    @idea = Idea.find(params[:id])
    @message = @idea.toggle_volunteer(current_user.id)
    @volunteered = current_user.volunteered_for?(@idea)
    respond_to do |format|
      format.js
    end
  end

  def recommend_team_member
    idea = Idea.find(params[:id])
    if !(user = current_user.current_team.users.find_by_full_name(params[:user])).nil?
      idea.add_recommended_member(user.id)
    else
      idea.add_recommended_non_user(params[:user], current_user)
    end

    respond_to do |format|
      format.js
    end

  end

  def recommend_non_team_member
    idea = Idea.find(params[:id])
    idea.add_recommended_non_user(params[:name], params[:email])
    recommended_count = current_user.recommended_user_count
    current_user.update(:recommended_user_count => recommended_count + 1)

    respond_to do |format|
      format.js {render :recommend_team_member}
    end
  end

  def get_autocomplete_items(parameters)
    items = super(parameters)
    if items.first.is_a? User
      items = items.where(:current_team_id => current_user.current_team_id) if items.first.is_a? User
    end
    return items
  end

  # For search on the dashboard
  def search
    if params[:search] == ""
      @ideas = current_user.current_team.ideas.order(:created_at).reverse_order
      @projects = current_user.current_team.projects.where(:setup_complete => true).order(:created_at).reverse_order
      @successes = current_user.current_team.successes.where(:setup_complete => true).order(:created_at).reverse_order
    else
      @ideas = (
      current_user.current_team.ideas.where('ideas.title ILIKE ?', "%#{params[:search]}%") +
          current_user.current_team.ideas.where('ideas.description ILIKE ?', "%#{params[:search]}%") +
          current_user.current_team.ideas.includes(:domains).where('domains.title ILIKE ?', "%#{params[:search]}%").references(:domains) +
          current_user.current_team.ideas.includes(:user).where('users.full_name ILIKE ?', "%#{params[:search]}%").references(:user)
      ).uniq.sort_by{|i| i[:created_at]}.reverse!
      @projects = (
      current_user.current_team.projects.where('projects.title ILIKE ?', "%#{params[:search]}%").where(:setup_complete => true) +
          current_user.current_team.projects.where('projects.description ILIKE ?', "%#{params[:search]}%") +
          current_user.current_team.projects.includes(:domains).where('domains.title ILIKE ?', "%#{params[:search]}%").references(:domains) +
          current_user.current_team.projects.includes(:user).where('users.full_name ILIKE ?', "%#{params[:search]}%").references(:user)
      ).uniq.sort_by{|i| i[:created_at]}.reverse!
      @successes = (
      current_user.current_team.successes.where(setup_complete: true).where('successes.title ILIKE ?', "%#{params[:search]}%") +
          current_user.current_team.successes.where(setup_complete: true).where('successes.description ILIKE ?', "%#{params[:search]}%") +
          current_user.current_team.successes.where(setup_complete: true).includes(:domains).where('domains.title ILIKE ?', "%#{params[:search]}%").references(:domains)# +
      #current_user.current_team.successes.where(setup_complete: true).includes(:leader).where('users.full_name ILIKE ?', "%#{params[:search]}%").references(:user)
      ).uniq.sort_by{|i| i[:created_at]}.reverse!
    end
    respond_to do |format|
      format.js
    end
  end

  def similar
    @ideas = (current_user.current_team.ideas.where('ideas.title ILIKE ?', "%#{params[:search]}%") +
        current_user.current_team.ideas.where('ideas.description ILIKE ?', "%#{params[:search]}%")).uniq
    render json: @ideas
  end

  private
  # return the user back if they are not a member of the same team as the project
  def authenticate_team_access
    redirect_to dashboard_path, alert: "You do not belong to the same team as the content you are trying to access." unless @idea.team_id == current_user.current_team_id
  end

  # return the user to the idea show page if they are not the owner or admin
  def authenticate_user_access
    redirect_to @idea, alert: "You are not authorized for this action." unless current_user.is_admin? || current_user == @idea.user
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_idea
    @idea = Idea.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def idea_params
    params.require(:idea).permit(:title, :description, :resources, :users_following, :users_suggested, :users_interested, :domain_tokens, :challenge_id, documents_attributes: [:id, :file, :description, :user_id, :_destroy], links_attributes: [:id, :url,:description, :user_id, :_destroy]).merge(user_id: current_user.id, team_id: current_user.current_team_id)
  end
end
