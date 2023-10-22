class FeedbacksController < ApplicationController
  # Display the feedback form
  def new
    @feedback = Feedback.new  # Initialize a new Feedback object for the form
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

  # Define any other controller actions here if needed

  private

  # Strong parameters for feedback form
  def feedback_params
    params.require(:feedback).permit(:vote)
  end
end


