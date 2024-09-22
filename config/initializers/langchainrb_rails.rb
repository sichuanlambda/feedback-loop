# frozen_string_literal: true

LangchainrbRails.configure do |config|
  api_key = ENV['OPENAI_API_KEY']
  Rails.logger.info "OpenAI API Key: #{api_key}"
  config.vectorsearch = Langchain::Vectorsearch::Pgvector.new(
    llm: Langchain::LLM::OpenAI.new(api_key: api_key)
  )
end
