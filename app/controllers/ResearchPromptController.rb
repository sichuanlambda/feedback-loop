class ResearchPromptController < ApplicationController
  def index
    # Render the form for the research prompt
  end

  def create
    # Debugging line to check params
    Rails.logger.debug "Params: #{params.inspect}"

    # Store the research prompt input
    research_prompt = params[:research_prompt] # This should be a hash
    Rails.logger.debug "Research Prompt: #{research_prompt.inspect}" # Log the research prompt

    input = research_prompt[:input] # Access the input field

    # Utilize LangChain to process the input
    begin
      langchain_client = LangChain::Client.new(api_key: Rails.application.credentials.langchain_api_key)
      result = langchain_client.process(input) # Adjust method as per LangChain's API

      # Display the result to the user
      render :index, locals: { result: result }
    rescue StandardError => e
      flash[:error] = "An error occurred: #{e.message}"
      render :index
    end
  end
end
