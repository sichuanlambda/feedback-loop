require 'open-uri'
require 'net/http'
require 'json'
require 'aws-sdk-textract'

class FeedbacksController < ApplicationController
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
    # Logic for the screenshot searcher page
  end

  def analyze_screenshot
    uploaded_file = params[:screenshot]

    if uploaded_file.nil?
      # Handle the case where the file is not uploaded
      render json: { error: "No file uploaded" }, status: :bad_request
      return
    end

    # Create an Amazon Textract client
    textract = Aws::Textract::Client.new

    # Call Textract to analyze the document
    response = textract.detect_document_text({
      document: {
        bytes: uploaded_file.read
      }
    })

    # Process Textract response
    extracted_text = response.blocks.map(&:text).join(' ')

    # Create a new ScreenshotAnalysis record
    screenshot_analysis = ScreenshotAnalysis.new(extracted_text: extracted_text)
    screenshot_analysis.screenshot.attach(uploaded_file)
    if screenshot_analysis.save
      # Respond with the extracted text and successful message
      render json: { extracted_text: extracted_text, message: 'Screenshot and text saved successfully' }
    else
      # Handle save error
      render json: { error: screenshot_analysis.errors.full_messages.join(", ") }, status: :unprocessable_entity
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

  private

  def feedback_params
    params.require(:feedback).permit(:vote, :comment, :screenshot)
  end
end
