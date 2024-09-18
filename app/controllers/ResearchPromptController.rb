class ResearchPromptController < ApplicationController
  def index
    # Render the form for the research prompt
  end

  def create
    # Debugging line to check params
    Rails.logger.debug "Params: #{params.inspect}"

    # Store the research prompt input
    input = params[:research_prompt] # This should now be a string

    # Utilize LangChain to process the input
    begin
      langchain_client = LangChain::Client.new(api_key: Rails.application.credentials.langchain_api_key)
      result = langchain_client.process(input) # Adjust method as per LangChain's API

      # Debugging line to check the result
      Rails.logger.debug "LangChain Result: #{result.inspect}"

      # Display the result to the user
      render :index, locals: { result: result }
    rescue StandardError => e
      flash[:error] = "An error occurred: #{e.message}"
      render :index
    end
  end
end
