# frozen_string_literal: true

LangchainrbRails.configure do |config|
  api_key = Rails.application.credentials.openai[:access_token]
  config.vectorsearch = Langchain::Vectorsearch::Pgvector.new(
    llm: Langchain::LLM::OpenAI.new(api_key: api_key)
  )
end
