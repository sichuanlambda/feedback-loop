class AddVectorColumnToProducts < ActiveRecord::Migration[7.1]
  def change
    add_column :products, :embedding, :vector,
      limit: Langchain::LLM::OpenAI.new(api_key: Rails.application.credentials.openai[:api_key]).default_dimension
  end
end
