require 'open-uri'
require 'net/http'
require 'json'
require 'aws-sdk-textract'

class FeedbacksController < ApplicationController
  before_action :authenticate_user!
  # Display the feedback form
  def new
    @feedback = Feedback.new
  end

  def about
    # Logic for the about page
  end

  def roastery
    # any necessary logic for the Roastery page
  end

  def screenshot_searcher
    if params[:search].present?
      # Search and filter records based on the search term
    @screenshot_analyses = ScreenshotAnalysis.where("extracted_text LIKE ?", "%#{params[:search]}%")
    else
    @screenshot_analyses = ScreenshotAnalysis.all.order(created_at: :desc)
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
      screenshot_analysis = ScreenshotAnalysis.new(extracted_text: extracted_text)

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
    prompt_response = GptService.new.send_prompt(params[:prompt])
    if prompt_response
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

  private

  def feedback_params
    params.require(:feedback).permit(:vote, :comment, :screenshot)
  end
end
