require 'open-uri'
require 'net/http'
require 'json'
require 'aws-sdk-textract'
require 'aws-sdk-s3'

class FeedbacksController < ApplicationController
  before_action :authenticate_user!, only: [:screenshot_searcher, :analyze_screenshot]
  # Display the feedback form
  def new
    @feedback = Feedback.new
    @gpt_interactions_count = GptInteraction.count
    @users = User.count
    @screenshots = Screenshot.count
  end

  def about
    # Logic for the about page
  end

  def roastery
    # any necessary logic for the Roastery page
  end

  def screenshot_searcher
    if params[:search].present?
      # Search and filter records based on the search term for the current user
      @screenshot_analyses = current_user.screenshot_analyses.where("extracted_text LIKE ?", "%#{params[:search]}%")
                                                              .order(created_at: :desc)
                                                              .page(params[:page])
                                                              .per(12)
    else
      # Fetch only the current user's screenshot analyses
      @screenshot_analyses = current_user.screenshot_analyses.order(created_at: :desc)
                                                              .page(params[:page])
                                                              .per(12)
    end
  end

  def analyze_screenshot
    uploaded_files = params[:screenshots]

    if uploaded_files.blank?
      render json: { error: "No file uploaded" }, status: :bad_request
      return
    end

    textract = Aws::Textract::Client.new
    successes = 0
    errors = []

    uploaded_files.each do |uploaded_file|
      next if uploaded_file.blank? # Skip any blank file inputs

      response = textract.detect_document_text({
        document: { bytes: uploaded_file.read }
      })

      extracted_text = response.blocks.map(&:text).join(' ')
      # Create a new ScreenshotAnalysis associated with the current user
      screenshot_analysis = current_user.screenshot_analyses.new(extracted_text: extracted_text)

      screenshot_analysis.screenshots.attach(uploaded_file)

      if screenshot_analysis.save
        successes += 1
      else
        errors << screenshot_analysis.errors.full_messages.join(", ")
      end
    end

    if errors.empty?
      render json: { message: "#{successes} screenshots processed and saved successfully" }
    else
      render json: { message: "#{successes} screenshots saved, but errors occurred: #{errors.join("; ")}" }, status: :unprocessable_entity
    end
  end

  def create
    @feedback = Feedback.new(feedback_params)

    if @feedback.save
      # Handle successful feedback submission
      redirect_to thank_you_path
    else
      # Handle validation errors
      render 'new'
    end
  end

  def submit_comment
    # Create a new Feedback record linked to the GPT interaction
    @feedback = Feedback.new(feedback_params.merge(gpt_interaction_id: params[:gpt_interaction_id]))

    if @feedback.save
      # Handle successful feedback submission
      redirect_to thank_you_path
    else
      # Handle validation errors
      redirect_back(fallback_location: root_path)
    end
  end

  def dashboard
    @feedbacks = Feedback.all
  end

  def ask_gpt
    start_time = Time.current  # Capture the start time

    prompt_response = GptService.new.send_prompt(params[:prompt])

    if prompt_response
      end_time = Time.current  # Capture the end time
      response_time = ((end_time - start_time) * 1000).to_i  # Calculate response time in milliseconds

      # Create a new GptInteraction record
      GptInteraction.create(
        submitted_at: start_time,
        response_time: response_time,
        user_input: params[:prompt],
        gpt_response: prompt_response
      )

      render json: { text: prompt_response }
    else
      render json: { error: 'No response from GPT service' }, status: :bad_request
    end
  end

  def sign_out_confirmation
    # Any additional logic (if needed)
  end
  def custom_sign_out
    sign_out current_user
    redirect_to sign_out_confirmation_path
  end

  def rate_my_dog
    # Display the "Rate My Dog" form
  end

  def process_dog_image
    uploaded_image = params[:dog_image]

    if uploaded_image.blank?
      render json: { error: "No image uploaded" }, status: :bad_request
      return
    end

    begin
      image_url = upload_image_to_s3(uploaded_image)
      return render json: { error: 'S3 upload failed' }, status: :unprocessable_entity if image_url.nil?

      gpt_response = GptService.new.send_image_url(image_url)

      if gpt_response
        render json: { response: gpt_response }, status: :ok
      else
        render json: { error: 'No response from GPT service' }, status: :service_unavailable
      end
    rescue => e
      render json: { error: e.message }, status: :internal_server_error
    end
  end

  private
  def upload_image_to_s3(uploaded_file)
    return nil if uploaded_file.blank?

    s3 = Aws::S3::Resource.new(region: 'us-east-2')
    obj = s3.bucket('rating-dogs').object("uploads/#{uploaded_file.original_filename}")
    obj.upload_file(uploaded_file.tempfile.path)
    obj.public_url
  rescue => e
    Rails.logger.error "S3 Upload Failed: #{e.message}"
    nil
  end

  def feedback_params
    params.require(:feedback).permit(:vote, :comment, :screenshot)
  end
end
