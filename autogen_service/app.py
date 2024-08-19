from flask import Flask, request, jsonify
from autogen.agentchat import ConversableAgent
from autogen.oai import OpenAIWrapper
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

app = Flask(__name__)

# Configure the agent
agent = ConversableAgent(
    name="Assistant",
    system_message="You are a helpful AI assistant.",
    llm_config={
        "model": "gpt-3.5-turbo",  # Use the appropriate model for your needs
        "api_key": os.getenv("OPENAI_API_KEY")  # Use the OpenAI API key from environment variable
    }
)

@app.route('/ask', methods=['POST'])
def ask():
    user_input = request.json.get('input')
    response = agent.generate_reply([{"role": "user", "content": user_input}])
    return jsonify(response)

if __name__ == '__main__':
    app.run(port=5000)
