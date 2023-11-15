require 'open-uri'
require 'net/http'
require 'json'

class FeedbacksController < ApplicationController
  # Display the feedback form
  def new
    @feedback = Feedback.new
  end

  def about
  end
  def roastery
    # any necessary logic for the Roastery page
  end

  # Handle the form submission
  def create
    @feedback = Feedback.new(feedback_params)

    if @feedback.save
      # Handle successful feedback submission (e.g., redirect to a thank-you page)
      redirect_to thank_you_path
    else
      # Handle validation errors (e.g., re-render the form with error messages)
      render 'new'
    end
  end

  def submit_comment
    @feedback = Feedback.find(params[:id])  # Replace :id with your actual parameter
    if @feedback.update(feedback_params)
      # Handle successful comment submission (e.g., redirect to a thank-you page)
      redirect_to thank_you_path
    else
      # Handle validation errors (e.g., re-render the form with error messages)
      render 'new'
    end
  end

  def dashboard
    @feedbacks = Feedback.all
  end

  # everything below (except final end) is for the integraiton with GPT
  def ask_gpt
    prompt_response = GptService.new.send_prompt(params[:prompt])
    if prompt_response
      # Assuming the response is a string containing the AI's message
      render json: { text: prompt_response }
    else
      render json: { error: 'No response from GPT service' }, status: :bad_request
    end
  end

  private
  # Strong parameters for feedback form
  def feedback_params
    params.require(:feedback).permit(:vote, :comment)
  end
end
