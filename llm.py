from flask import Flask, request, jsonify
import google.generativeai as genai
from flask_cors import CORS

app = Flask(__name__)
CORS(app)  # Enable CORS if needed for cross-origin requests

# Set your Google API key here
GOOGLE_API_KEY = 'AIzaSyAAAA0G38_VkZkYlBRam1M-F8Pmk88hY44'
genai.configure(api_key=GOOGLE_API_KEY)
model = genai.GenerativeModel('gemini-1.5-flash')

@app.route('/generate', methods=['GET'])
def generate_content():
    level = request.args.get('level')  # Get the level from the query string

    if not level:
        return jsonify({'error': 'Level is required'}), 400

    # Construct prompt based on selected difficulty
    if level == 'beginner':
             prompt = ("Generate 20 beginner-level Python multiple choice questions (MCQs) about variables, loops, and basic syntax. "
                  "For each question, provide 4 options. Start the question with 'qstn:', options with 'opt:' with each option separated by comma, and the correct answer with 'ans:'."
                  "do not provide any other message or use any special characters or formatting umless necessary in questions.Separate each question set with a newline.put a question and its options and answer in a single line with only space separating")
    elif level == 'intermediate':
        prompt = ("Generate 20 intermediate-level Python multiple choice questions (MCQs) about functions, classes, and data structures."
                 "For each question, provide 4 options. Start the question with 'qstn:', options with 'opt:' with each option separated by comma, and the correct answer with 'ans:'."
                  "do not provide any other message or use any special characters or formatting umless necessary in questions.Separate each question set with a newline.put a question and its options and answer in a single line with only space separating")
    elif level == 'advanced':
        prompt = ("Generate 20 advanced-level Python multiple choice questions (MCQs) about algorithms, data science, and optimization."
                "For each question, provide 4 options. Start the question with 'qstn:', options with 'opt:' with each option separated by comma, and the correct answer with 'ans:'."
                  "do not provide any other message or use any special characters or formatting umless necessary in questions.Separate each question set with a newline.put a question and its options and answer in a single line with only space separating")
    else:
        return jsonify({'error': 'Invalid level'}), 400

    try:
        # Generate content using the Google Generative AI model
        response = model.generate_content(prompt)
        generated_content = response.text

        # Split the generated content by newline to separate each question
        questions_and_options = generated_content.split('\n')
        mcqs = []

        # Process each question
        for q in questions_and_options:
                try:
                    # Process question, options, and answer based on the provided markers
                    if 'qstn:' in q and 'opt:' in q and 'ans:' in q:
                        question_part = q.split('qstn:', 1)[1].split('opt:', 1)[0].strip()
                        options_part = q.split('opt:', 1)[1].split('ans:', 1)[0].strip()
                        answer_part = q.split('ans:', 1)[1].strip()

                        # Extract options, assuming they're comma-separated
                        options = options_part.split(',')

                        mcqs.append({
                            'question': question_part,
                            'options': options,
                            'correct_answer': answer_part
                        })
                except Exception as e:
                    print(f"Error processing question: {e}")

        if not mcqs:
            return jsonify({'error': 'No valid questions generated'}), 500

        # Return the MCQs as a JSON response
        return jsonify({'mcqs': mcqs})
    
    except Exception as e:
        return jsonify({'error': f'Failed to generate content: {str(e)}'}), 500

if __name__ == '__main__':
    app.run(debug=True)
