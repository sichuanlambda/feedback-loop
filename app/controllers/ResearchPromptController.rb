class ResearchPromptController < ApplicationController
  require 'langchain' # Require the langchainrb gem

  def index
    # Render the form for the research prompt
  end

  def create
    # Store the research prompt input
    input = params[:input]

    # Initialize the language model
    api_key = Rails.application.credentials.openai[:api_key]
    llm = Langchain::LLM::OpenAI.new(api_key: api_key)
    llm.chat(messages: [{role: "user", content: "What is the meaning of life?"}]).completion

    # Generate a response
    response = llm.chat(messages: [{ role: "user", content: input }])
    Rails.logger.info("OpenAI Response: #{response}")

    # Render the result
    render :index, locals: { result: response.completion }
  rescue StandardError => e
    flash[:error] = "An error occurred: #{e.message}"
    render :index
  end
end
